-- Manual full-payment records only; no transfer, reversal or Void operation.
begin;
create table public.teacher_payments (
 id uuid primary key default gen_random_uuid(),code bigint generated always as identity,
 school_id uuid not null,run_id uuid not null,teacher_id uuid not null,amount_mmk numeric not null check(amount_mmk>=0 and amount_mmk=trunc(amount_mmk)),
 paid_date date not null check(isfinite(paid_date)),method text not null check(method in ('Cash','Bank transfer','Mobile wallet','Other')),
 reference text not null check(length(trim(reference)) between 1 and 1000),recorded_by uuid not null references auth.users(id),recorded_at timestamptz not null default clock_timestamp(),
 unique(run_id,teacher_id),foreign key(school_id,run_id) references public.payroll_drafts(school_id,id),foreign key(school_id,teacher_id) references public.teachers(school_id,id)
);
create index payments_school_date_idx on public.teacher_payments(school_id,paid_date desc,id);
create table sayasync_private.payment_requests (
 school_id uuid not null references public.schools(id),actor_id uuid not null references auth.users(id),request_id uuid not null,
 payload jsonb not null,result jsonb not null,primary key(school_id,actor_id,request_id)
);
revoke all on sayasync_private.payment_requests from public,anon,authenticated;
alter table public.teacher_payments enable row level security;
revoke all on public.teacher_payments from anon,authenticated;
grant select on public.teacher_payments to authenticated;
grant all on public.teacher_payments to service_role;
revoke all on sequence public.teacher_payments_code_seq from anon,authenticated;
grant usage,select on sequence public.teacher_payments_code_seq to service_role;
create policy payments_read on public.teacher_payments for select to authenticated using(sayasync_private.is_admin(school_id) or sayasync_private.owns_teacher(teacher_id));

create function sayasync_private.approved_payee(p_run jsonb,p_teacher uuid)
returns boolean language sql immutable set search_path='' as $$
 select exists(select 1 from jsonb_array_elements(p_run->'teachers') t where t->>'teacher_id'=p_teacher::text
  and ((t->>'included_count')::integer>0 or exists(select 1 from jsonb_array_elements(coalesce(p_run->'adjustments','[]'::jsonb)) a where a->>'teacher_id'=p_teacher::text)));
$$;
revoke all on function sayasync_private.approved_payee(jsonb,uuid) from public,anon,authenticated;
create function sayasync_private.protect_teacher_payment()
returns trigger language plpgsql security definer set search_path='' as $$
declare d public.payroll_drafts%rowtype;t jsonb;
begin
 if tg_op<>'INSERT' then raise exception 'Payment history is immutable; reversal workflow is not available yet';end if;
 perform pg_advisory_xact_lock(hashtextextended(new.school_id::text,0));
 select * into d from public.payroll_drafts where school_id=new.school_id and id=new.run_id and status='Approved';
 if not found or not sayasync_private.approved_payee(d.snapshot,new.teacher_id) then raise exception 'An approved teacher payroll is required';end if;
 select value into t from jsonb_array_elements(d.snapshot->'teachers') where value->>'teacher_id'=new.teacher_id::text;
 if new.amount_mmk is distinct from (t->>'net_mmk')::numeric then raise exception 'Payment must equal the full frozen teacher net amount';end if;
 if new.paid_date>(clock_timestamp() at time zone 'Asia/Yangon')::date then raise exception 'Paid date cannot be in the future';end if;
 return new;
end $$;
revoke all on function sayasync_private.protect_teacher_payment() from public,anon,authenticated;
create trigger teacher_payment_guard before insert or update or delete on public.teacher_payments for each row execute function sayasync_private.protect_teacher_payment();

create function public.record_teacher_payment(p_school uuid,p_request uuid,p_payload jsonb)
returns jsonb language plpgsql security definer set search_path='' as $$
declare actor uuid:=auth.uid();d public.payroll_drafts%rowtype;t jsonb;pay public.teacher_payments%rowtype;
 previous sayasync_private.payment_requests%rowtype;v_teacher uuid;v_date date;v_method text;v_reference text;result jsonb;
begin
 if actor is null or not sayasync_private.is_admin(p_school) then raise exception 'Administrator access required' using errcode='42501';end if;
 if p_request is null or p_payload is null or jsonb_typeof(p_payload)<>'object' then raise exception 'Invalid payment request';end if;
 perform pg_advisory_xact_lock(hashtextextended(p_school::text,0));
 if not sayasync_private.is_admin(p_school) then raise exception 'Administrator access required' using errcode='42501';end if;
 select * into previous from sayasync_private.payment_requests where school_id=p_school and actor_id=actor and request_id=p_request;
 if found then if previous.payload<>p_payload then raise exception 'Request key conflict';end if;return previous.result;end if;
 select * into d from public.payroll_drafts where school_id=p_school and id=(p_payload->>'run_id')::uuid for update;
 if not found or d.status<>'Approved' then raise exception 'An approved payroll is required';end if;
 if (p_payload->>'version')::integer is null or d.version<>(p_payload->>'version')::integer then raise exception 'Payroll changed. Refresh before recording payment.' using errcode='40001';end if;
 v_teacher:=(p_payload->>'teacher_id')::uuid;
 if v_teacher is null or not sayasync_private.approved_payee(d.snapshot,v_teacher) then raise exception 'Teacher has no included sessions or adjustments in this approved payroll';end if;
 select value into t from jsonb_array_elements(d.snapshot->'teachers') where value->>'teacher_id'=v_teacher::text;
 if exists(select 1 from public.teacher_payments where run_id=d.id and teacher_id=v_teacher) then raise exception 'Payment is already recorded. Refresh the payment list.';end if;
 v_date:=(p_payload->>'paid_date')::date;v_method:=p_payload->>'method';v_reference:=trim(coalesce(p_payload->>'reference',''));
 if v_date is null or not isfinite(v_date) or v_method is null or v_method not in ('Cash','Bank transfer','Mobile wallet','Other') or length(v_reference) not between 1 and 1000 then raise exception 'Enter a valid paid date, method and reference or receipt note';end if;
 if v_date>(clock_timestamp() at time zone 'Asia/Yangon')::date then raise exception 'Paid date cannot be in the future';end if;
 insert into public.teacher_payments(school_id,run_id,teacher_id,amount_mmk,paid_date,method,reference,recorded_by)
  values(p_school,d.id,v_teacher,(t->>'net_mmk')::numeric,v_date,v_method,v_reference,actor) returning * into pay;
 result:=to_jsonb(pay)||jsonb_build_object('amount_mmk',pay.amount_mmk::text);
 insert into public.payroll_draft_events(school_id,draft_id,actor_id,action,prior_version,new_version,before_snapshot,after_snapshot,reason)
  values(p_school,d.id,actor,'record_payment',d.version,d.version,null,result,v_reference);
 insert into sayasync_private.payment_requests values(p_school,actor,p_request,p_payload,result);
 return result;
end $$;
revoke all on function public.record_teacher_payment(uuid,uuid,jsonb) from public,anon;
grant execute on function public.record_teacher_payment(uuid,uuid,jsonb) to authenticated;

-- This private helper contains school-wide rows. It is never granted to clients.
create function sayasync_private.approved_payment_rows(p_school uuid)
returns setof jsonb language sql stable security definer set search_path='' as $$
 select jsonb_build_object('run_id',d.id,'run_code',d.code,'period_start',d.period_start,'period_end',d.period_end,'approved_at',d.approved_at,'run_version',d.version,
  'teacher_id',t->>'teacher_id','teacher_name',t->>'teacher_name','teacher_code',t->'teacher_code','minutes',t->'minutes',
  'gross_mmk',t->>'gross_mmk','adjustments_mmk',t->>'adjustments_mmk','net_mmk',t->>'net_mmk',
  'payment_status',case when p.id is null then 'Not paid' else 'Paid' end,'payment_id',p.id,'payment_code',p.code,
  'paid_date',p.paid_date,'method',p.method,'reference',p.reference,'recorded_at',p.recorded_at,
  'paid_count',(select count(*) from public.teacher_payments where run_id=d.id),
  'teacher_count',(select count(*) from jsonb_array_elements(d.snapshot->'teachers') x where sayasync_private.approved_payee(d.snapshot,(x->>'teacher_id')::uuid)))
 from public.payroll_drafts d cross join lateral jsonb_array_elements(d.snapshot->'teachers') t
 left join public.teacher_payments p on p.run_id=d.id and p.teacher_id=(t->>'teacher_id')::uuid
 where d.school_id=p_school and d.status='Approved' and sayasync_private.approved_payee(d.snapshot,(t->>'teacher_id')::uuid);
$$;
revoke all on function sayasync_private.approved_payment_rows(uuid) from public,anon,authenticated;

create function public.read_teacher_payments(p_school uuid,p_page integer default 1,p_status text default '',p_teacher uuid default null)
returns jsonb language plpgsql stable security definer set search_path='' as $$
declare admin boolean;own_teacher uuid;result jsonb;
begin
 if not sayasync_private.is_member(p_school) then raise exception 'Active school access required' using errcode='42501';end if;
 admin:=sayasync_private.is_admin(p_school);
 if not admin then
  select id into own_teacher from public.teachers where school_id=p_school and sayasync_private.owns_teacher(id);
  if own_teacher is null or (p_teacher is not null and p_teacher<>own_teacher) then raise exception 'Your approved payroll only' using errcode='42501';end if;
 end if;
 if p_page is null or p_page<1 or p_page>100000 or p_status is null or p_status not in ('','Paid','Not paid') then raise exception 'Invalid payment filters';end if;
 with filtered as(select x as item from sayasync_private.approved_payment_rows(p_school) x
  where (admin or x->>'teacher_id'=own_teacher::text) and (p_teacher is null or x->>'teacher_id'=p_teacher::text) and (p_status='' or x->>'payment_status'=p_status)),
 page_rows as(select case when admin then item else item-'paid_count'-'teacher_count' end as item from filtered
  order by item->>'period_start' desc,(item->>'run_code')::bigint desc,item->>'teacher_id' limit 25 offset (p_page-1)*25)
 select jsonb_build_object('total',(select count(*) from filtered),'records',coalesce((select jsonb_agg(item) from page_rows),'[]'::jsonb)) into result;
 return result;
end $$;
revoke all on function public.read_teacher_payments(uuid,integer,text,uuid) from public,anon;
grant execute on function public.read_teacher_payments(uuid,integer,text,uuid) to authenticated;

create function public.teacher_payment_detail(p_school uuid,p_run uuid,p_teacher uuid)
returns jsonb language plpgsql stable security definer set search_path='' as $$
declare d public.payroll_drafts%rowtype;row_data jsonb;
begin
 if p_teacher is null or not (sayasync_private.is_admin(p_school) or exists(select 1 from public.teachers where school_id=p_school and id=p_teacher and sayasync_private.owns_teacher(id))) then raise exception 'Your approved payroll only' using errcode='42501';end if;
 select * into d from public.payroll_drafts where school_id=p_school and id=p_run and status='Approved';
 if not found or not sayasync_private.approved_payee(d.snapshot,p_teacher) then raise exception 'Approved teacher payroll not found' using errcode='42501';end if;
 select x into row_data from sayasync_private.approved_payment_rows(p_school) x where x->>'run_id'=p_run::text and x->>'teacher_id'=p_teacher::text;
 if not sayasync_private.is_admin(p_school) then row_data:=row_data-'paid_count'-'teacher_count';end if;
 return jsonb_build_object('summary',row_data,
  'lines',coalesce((select jsonb_agg(jsonb_build_object('code',x->'code','class_name',x->>'class_name','subject',x->>'subject',
    'start_at',x->>'start_at','end_at',x->>'end_at','minutes',x->'minutes','hourly_mmk',x->>'hourly_mmk',
    'rate_effective_from',x->>'rate_effective_from','amount_mmk',x->>'amount_mmk')) from jsonb_array_elements(d.snapshot->'lines') x
    where x->>'teacher_id'=p_teacher::text and (x->>'included')::boolean),'[]'::jsonb),
  'adjustments',coalesce((select jsonb_agg(jsonb_build_object('amount_mmk',a->>'amount_mmk','reason',a->>'reason','reference',a->>'reference'))
    from jsonb_array_elements(coalesce(d.snapshot->'adjustments','[]'::jsonb)) a where a->>'teacher_id'=p_teacher::text),'[]'::jsonb));
end $$;
revoke all on function public.teacher_payment_detail(uuid,uuid,uuid) from public,anon;
grant execute on function public.teacher_payment_detail(uuid,uuid,uuid) to authenticated;
commit;
