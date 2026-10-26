-- Approval/adjustment slice. Existing drafts and attendance are preserved.
begin;
alter table public.payroll_drafts drop constraint payroll_drafts_status_check;
alter table public.payroll_drafts add constraint payroll_drafts_status_check check(status in ('Draft','Approved'));
alter table public.payroll_drafts add column approved_by uuid references auth.users(id);
alter table public.payroll_drafts add column approved_at timestamptz;
alter table public.payroll_drafts add constraint payroll_approval_identity check(
 (status='Draft' and approved_by is null and approved_at is null) or
 (status='Approved' and approved_by is not null and approved_at is not null));
alter table public.payroll_draft_events add column reason text not null default '';
create table public.payroll_adjustments (
 id uuid primary key default gen_random_uuid(),school_id uuid not null,draft_id uuid not null,teacher_id uuid not null,
 amount_mmk bigint not null check(amount_mmk<>0),reason text not null check(length(trim(reason)) between 1 and 1000),
 reference text not null default '' check(length(reference)<=200),active boolean not null default true,
 created_by uuid not null references auth.users(id),created_at timestamptz not null default clock_timestamp(),
 withdrawn_by uuid references auth.users(id),withdrawn_at timestamptz,withdraw_reason text not null default '',
 foreign key(school_id,draft_id) references public.payroll_drafts(school_id,id),
 foreign key(school_id,teacher_id) references public.teachers(school_id,id)
);
create index adjustments_run_idx on public.payroll_adjustments(school_id,draft_id);
create table public.payroll_allocations (
 session_id uuid primary key,school_id uuid not null,draft_id uuid not null,session_version integer not null,
 rate_id uuid not null references public.teacher_rates(id),created_at timestamptz not null default clock_timestamp(),
 foreign key(school_id,session_id) references public.teaching_sessions(school_id,id),
 foreign key(school_id,draft_id) references public.payroll_drafts(school_id,id)
);
create index allocations_draft_idx on public.payroll_allocations(school_id,draft_id);
create table sayasync_private.payroll_financial_requests (
 school_id uuid not null references public.schools(id),actor_id uuid not null references auth.users(id),request_id uuid not null,
 command text not null,payload jsonb not null,result jsonb not null,primary key(school_id,actor_id,request_id)
);
revoke all on sayasync_private.payroll_financial_requests from public,anon,authenticated;
alter table public.payroll_adjustments enable row level security;
alter table public.payroll_allocations enable row level security;
revoke all on public.payroll_adjustments,public.payroll_allocations from anon,authenticated;
grant select on public.payroll_adjustments,public.payroll_allocations to authenticated;
grant all on public.payroll_adjustments,public.payroll_allocations to service_role;
create policy adjustments_admin_read on public.payroll_adjustments for select to authenticated using(sayasync_private.is_admin(school_id));
create policy allocations_read on public.payroll_allocations for select to authenticated using(sayasync_private.is_admin(school_id) or exists(
 select 1 from public.teaching_sessions s where s.id=session_id and sayasync_private.owns_teacher(s.teacher_id)));
create or replace function sayasync_private.payroll_draft_source(p_school uuid,p_from date,p_to date)
returns jsonb language sql stable security definer set search_path='' as $$
 select jsonb_build_object('policy','mmk-minute-v1','timezone','Asia/Yangon','period_start',p_from,'period_end',p_to,
 'records',coalesce((select jsonb_agg(jsonb_build_object('session',to_jsonb(s),'teacher_name',t.name,'teacher_code',t.code,
  'class_name',c.name,'subject',c.subject,'allocated_run',(select pa.draft_id from public.payroll_allocations pa where pa.session_id=s.id),'assignment',to_jsonb(a),'rate',to_jsonb(r),
  'corrections',coalesce((select jsonb_agg(jsonb_build_object('id',cr.id,'version',cr.version,'status',cr.status) order by cr.id)
    from public.correction_requests cr where cr.session_id=s.id),'[]'::jsonb)) order by s.start_at,s.id)
  from public.teaching_sessions s join public.teachers t on t.id=s.teacher_id join public.classes c on c.id=s.class_id
  join public.teacher_assignments a on a.id=s.assignment_id
  left join lateral(select tr.* from public.teacher_rates tr where tr.teacher_id=s.teacher_id
   and tr.effective_from<=(s.start_at at time zone 'Asia/Yangon')::date order by tr.effective_from desc limit 1) r on true
  where s.school_id=p_school and s.start_at>=(p_from::timestamp at time zone 'Asia/Yangon')
   and s.start_at<((p_to+1)::timestamp at time zone 'Asia/Yangon')),'[]'::jsonb));
$$;
revoke all on function sayasync_private.payroll_draft_source(uuid,date,date) from public,anon,authenticated;

create or replace function sayasync_private.build_payroll_draft_snapshot(source jsonb)
returns jsonb language plpgsql immutable set search_path='' as $$
declare row_data jsonb;s jsonb;a jsonb;r jsonb;reasons text[];lines jsonb:='[]';summaries jsonb;included boolean;
 amount numeric;rate numeric;duration bigint;total_minutes bigint:=0;gross numeric:=0;included_count integer:=0;
begin
 for row_data in select value from jsonb_array_elements(source->'records') loop
  s:=row_data->'session';a:=row_data->'assignment';r:=row_data->'rate';reasons:=array[]::text[];
  duration:=(s->>'minutes')::bigint;rate:=(r->>'hourly_mmk')::numeric;
  if s->>'end_at' is null then reasons:=array_append(reasons,'Missing checkout');end if;
  if s->>'verification'<>'Verified' then reasons:=array_append(reasons,'Verification '||(s->>'verification'));end if;
  if duration is not null and duration<1 then reasons:=array_append(reasons,'Less than one completed minute');end if;
  if exists(select 1 from jsonb_array_elements(row_data->'corrections') x where x->>'status'='Pending') then reasons:=array_append(reasons,'Pending correction');end if;
  if (s->>'overlap_flag')::boolean and coalesce(s->>'overlap_resolution','')='' then reasons:=array_append(reasons,'Unresolved overlap');end if;
  if (a->>'effective_from')::timestamptz>(s->>'start_at')::timestamptz or
   ((a->>'effective_to') is not null and (a->>'effective_to')::timestamptz<=(s->>'start_at')::timestamptz) then reasons:=array_append(reasons,'Assignment does not cover teaching start');end if;
  if row_data->>'allocated_run' is not null then reasons:=array_append(reasons,'Already allocated to approved payroll');end if;
  if rate is null then reasons:=array_append(reasons,'No applicable hourly rate');end if;
  included:=cardinality(reasons)=0;
  amount:=case when included then round(duration::numeric*rate/60,0) else 0 end;
  if included then gross:=gross+amount;total_minutes:=total_minutes+duration;included_count:=included_count+1;end if;
  lines:=lines||jsonb_build_array(jsonb_build_object('session_id',s->>'id','code',s->'code','teacher_id',s->>'teacher_id',
   'teacher_name',row_data->>'teacher_name','teacher_code',row_data->'teacher_code','class_name',row_data->>'class_name','subject',row_data->>'subject',
   'start_at',s->>'start_at','end_at',s->>'end_at','minutes',duration,'session_version',s->'version','verification',s->>'verification',
   'rate_id',r->>'id','rate_effective_from',r->>'effective_from','hourly_mmk',rate::text,'amount_mmk',amount::text,'included',included,'reasons',to_jsonb(reasons),
   'source',row_data));
 end loop;
 select coalesce(jsonb_agg(item order by item->>'teacher_name',item->>'teacher_id'),'[]'::jsonb) into summaries from (
  select jsonb_build_object('teacher_id',x->>'teacher_id','teacher_name',x->>'teacher_name','teacher_code',max((x->>'teacher_code')::bigint),
   'minutes',coalesce(sum((x->>'minutes')::bigint) filter(where (x->>'included')::boolean),0),
   'gross_mmk',sum((x->>'amount_mmk')::numeric)::text,'included_count',count(*) filter(where (x->>'included')::boolean),
   'held_count',count(*) filter(where not (x->>'included')::boolean)) as item
  from jsonb_array_elements(lines) x group by x->>'teacher_id',x->>'teacher_name'
 ) q;
 return jsonb_build_object('policy','mmk-minute-v1','timezone','Asia/Yangon','lines',lines,'teachers',summaries,
  'minutes',total_minutes,'gross_mmk',gross::text,'included_count',included_count,'held_count',jsonb_array_length(lines)-included_count);
end $$;
revoke all on function sayasync_private.build_payroll_draft_snapshot(jsonb) from public,anon,authenticated;
create function sayasync_private.apply_payroll_adjustments(p_school uuid,p_draft uuid,p_snapshot jsonb)
returns jsonb language sql stable security definer set search_path='' as $$
 with lines as(select value as x from jsonb_array_elements(p_snapshot->'lines')),
 adjustment_rows as(select a.*,t.name,t.code from public.payroll_adjustments a join public.teachers t on t.id=a.teacher_id
  where a.school_id=p_school and a.draft_id=p_draft and a.active),
 ids as(select (x->>'teacher_id')::uuid as id from lines union select teacher_id from adjustment_rows),
 summary as(select jsonb_build_object('teacher_id',t.id,'teacher_name',t.name,'teacher_code',t.code,
  'minutes',coalesce((select sum((x->>'minutes')::bigint) from lines where x->>'teacher_id'=t.id::text and (x->>'included')::boolean),0),
  'included_count',(select count(*) from lines where x->>'teacher_id'=t.id::text and (x->>'included')::boolean),
  'held_count',(select count(*) from lines where x->>'teacher_id'=t.id::text and not (x->>'included')::boolean),
  'gross_mmk',coalesce((select sum((x->>'amount_mmk')::numeric) from lines where x->>'teacher_id'=t.id::text),0)::text,
  'adjustments_mmk',coalesce((select sum(amount_mmk::numeric) from adjustment_rows where teacher_id=t.id),0)::text,
  'net_mmk',(coalesce((select sum((x->>'amount_mmk')::numeric) from lines where x->>'teacher_id'=t.id::text),0)+
   coalesce((select sum(amount_mmk::numeric) from adjustment_rows where teacher_id=t.id),0))::text) as item
  from ids join public.teachers t on t.id=ids.id and t.school_id=p_school)
 select p_snapshot||jsonb_build_object(
  'teachers',coalesce((select jsonb_agg(item order by item->>'teacher_name',item->>'teacher_id') from summary),'[]'::jsonb),
  'adjustments',coalesce((select jsonb_agg(jsonb_build_object('id',id,'teacher_id',teacher_id,'teacher_name',name,'teacher_code',code,
    'amount_mmk',amount_mmk::text,'reason',reason,'reference',reference,'created_at',created_at,'created_by',created_by) order by created_at,id) from adjustment_rows),'[]'::jsonb),
  'adjustments_mmk',coalesce((select sum(amount_mmk::numeric) from adjustment_rows),0)::text,
  'net_mmk',((p_snapshot->>'gross_mmk')::numeric+coalesce((select sum(amount_mmk::numeric) from adjustment_rows),0))::text);
$$;
revoke all on function sayasync_private.apply_payroll_adjustments(uuid,uuid,jsonb) from public,anon,authenticated;

create function sayasync_private.protect_payroll_run()
returns trigger language plpgsql security definer set search_path='' as $$
begin
 if tg_op='DELETE' then raise exception 'Payroll history cannot be deleted';end if;
 if tg_op='UPDATE' and old.status='Approved' then raise exception 'Approved payroll is immutable';end if;
 if new.status='Draft' then new.snapshot:=sayasync_private.apply_payroll_adjustments(new.school_id,new.id,new.snapshot);end if;
 return new;
end $$;
revoke all on function sayasync_private.protect_payroll_run() from public,anon,authenticated;
create trigger payroll_run_guard before insert or update or delete on public.payroll_drafts for each row execute function sayasync_private.protect_payroll_run();

create function sayasync_private.guard_payroll_session()
returns trigger language plpgsql security definer set search_path='' as $$
declare sid uuid;school uuid;
begin
 if tg_table_name='teaching_sessions' then sid:=old.id;school:=old.school_id;
 elsif tg_op='INSERT' then sid:=new.session_id;school:=new.school_id;
 else sid:=old.session_id;school:=old.school_id;end if;
 perform pg_advisory_xact_lock(hashtextextended(school::text,0));
 if exists(select 1 from public.payroll_allocations where session_id=sid) then raise exception 'This class record is locked by approved payroll';end if;
 if tg_op='DELETE' then return old;else return new;end if;
end $$;
revoke all on function sayasync_private.guard_payroll_session() from public,anon,authenticated;
create trigger session_payroll_lock before update or delete on public.teaching_sessions for each row execute function sayasync_private.guard_payroll_session();
create trigger correction_payroll_lock before insert or update or delete on public.correction_requests for each row execute function sayasync_private.guard_payroll_session();

create function sayasync_private.guard_allocated_assignment()
returns trigger language plpgsql security definer set search_path='' as $$
begin
 perform pg_advisory_xact_lock(hashtextextended(old.school_id::text,0));
 if exists(select 1 from public.teaching_sessions s join public.payroll_allocations a on a.session_id=s.id where s.assignment_id=old.id
  and (tg_op='DELETE' or new.school_id is distinct from old.school_id or new.id is distinct from old.id or
   new.teacher_id is distinct from old.teacher_id or new.class_id is distinct from old.class_id or
   new.effective_from>s.start_at or (new.effective_to is not null and new.effective_to<=s.start_at))) then
  raise exception 'Assignment change would invalidate approved payroll history';end if;
 if tg_op='DELETE' then return old;else return new;end if;
end $$;
revoke all on function sayasync_private.guard_allocated_assignment() from public,anon,authenticated;
create trigger assignment_payroll_guard before update or delete on public.teacher_assignments for each row execute function sayasync_private.guard_allocated_assignment();

create function sayasync_private.protect_payroll_allocation()
returns trigger language plpgsql security definer set search_path='' as $$
begin
 if tg_op<>'INSERT' then raise exception 'Approved allocation history is immutable';end if;
 if not exists(select 1 from public.payroll_drafts d join public.teaching_sessions s on s.id=new.session_id
  join public.teacher_rates r on r.id=new.rate_id and r.teacher_id=s.teacher_id and r.school_id=s.school_id
  where d.id=new.draft_id and d.school_id=new.school_id and d.status='Approved' and s.school_id=new.school_id and s.version=new.session_version
  and exists(select 1 from jsonb_array_elements(d.snapshot->'lines') x where x->>'session_id'=s.id::text and (x->>'included')::boolean
   and (x->>'session_version')::integer=new.session_version and x->>'rate_id'=new.rate_id::text)) then raise exception 'Approved allocation must match its frozen payroll snapshot';end if;
 return new;
end $$;
revoke all on function sayasync_private.protect_payroll_allocation() from public,anon,authenticated;
create trigger allocation_guard before insert or update or delete on public.payroll_allocations for each row execute function sayasync_private.protect_payroll_allocation();

create function sayasync_private.protect_payroll_adjustment()
returns trigger language plpgsql security definer set search_path='' as $$
declare school uuid;run uuid;
begin
 if tg_op='INSERT' then school:=new.school_id;run:=new.draft_id;else school:=old.school_id;run:=old.draft_id;end if;
 perform pg_advisory_xact_lock(hashtextextended(school::text,0));
 if exists(select 1 from public.payroll_drafts where id=run and status='Approved') then raise exception 'Approved payroll is immutable';end if;
 if tg_op='DELETE' then raise exception 'Withdraw adjustments instead of deleting history';end if;
 if tg_op='UPDATE' and (not old.active or new.active or new.id is distinct from old.id or new.school_id is distinct from old.school_id or
  new.draft_id is distinct from old.draft_id or new.teacher_id is distinct from old.teacher_id or new.amount_mmk is distinct from old.amount_mmk or
  new.reason is distinct from old.reason or new.reference is distinct from old.reference or new.created_by is distinct from old.created_by or
  new.created_at is distinct from old.created_at or new.withdrawn_by is null or new.withdrawn_at is null or length(trim(new.withdraw_reason)) not between 1 and 1000)
 then raise exception 'Withdraw an active adjustment with a reason; add a replacement to change its values';end if;
 return new;
end $$;
revoke all on function sayasync_private.protect_payroll_adjustment() from public,anon,authenticated;
create trigger adjustment_guard before insert or update or delete on public.payroll_adjustments for each row execute function sayasync_private.protect_payroll_adjustment();
create function sayasync_private.protect_payroll_audit()
returns trigger language plpgsql set search_path='' as $$ begin raise exception 'Payroll audit history is append-only';end $$;
revoke all on function sayasync_private.protect_payroll_audit() from public,anon,authenticated;
create trigger payroll_audit_guard before update or delete on public.payroll_draft_events for each row execute function sayasync_private.protect_payroll_audit();

create function public.manage_payroll_approval(p_school uuid,p_request uuid,p_command text,p_payload jsonb)
returns jsonb language plpgsql security definer set search_path='' as $$
declare actor uuid:=auth.uid();d public.payroll_drafts%rowtype;prior public.payroll_drafts%rowtype;
 previous sayasync_private.payroll_financial_requests%rowtype;source jsonb;fresh jsonb;result jsonb;v_reason text;v_amount bigint;v_teacher uuid;adj public.payroll_adjustments%rowtype;line jsonb;
begin
 if actor is null or not sayasync_private.is_admin(p_school) then raise exception 'Administrator access required' using errcode='42501';end if;
 if p_request is null or p_payload is null or jsonb_typeof(p_payload)<>'object' or p_command is null or p_command not in ('add_adjustment','withdraw_adjustment','approve') then raise exception 'Invalid payroll action';end if;
 perform pg_advisory_xact_lock(hashtextextended(p_school::text,0));
 if not sayasync_private.is_admin(p_school) then raise exception 'Administrator access required' using errcode='42501';end if;
 select * into previous from sayasync_private.payroll_financial_requests where school_id=p_school and actor_id=actor and request_id=p_request;
 if found then if previous.command<>p_command or previous.payload<>p_payload then raise exception 'Request key conflict';end if;return previous.result;end if;
 select * into prior from public.payroll_drafts where school_id=p_school and id=(p_payload->>'id')::uuid for update;
 if not found then raise exception 'Payroll run not found' using errcode='42501';end if;
 if prior.status<>'Draft' then raise exception 'Approved payroll is immutable';end if;
 if (p_payload->>'version')::integer is null or prior.version<>(p_payload->>'version')::integer then raise exception 'Payroll changed. Refresh before continuing.' using errcode='40001';end if;
 v_reason:=trim(coalesce(p_payload->>'reason',''));
 if length(v_reason)>1000 then raise exception 'Reason must be at most 1000 characters';end if;
 if p_command='add_adjustment' then
  v_teacher:=(p_payload->>'teacher_id')::uuid;
  if not exists(select 1 from public.teachers where school_id=p_school and id=v_teacher) then raise exception 'Select a teacher in this school';end if;
  if coalesce(p_payload->>'amount','') !~ '^[+-]?[0-9]+$' then raise exception 'Enter a non-zero whole MMK adjustment';end if;
  v_amount:=(p_payload->>'amount')::bigint;
  if v_amount=0 or v_reason='' or length(coalesce(p_payload->>'reference',''))>200 then raise exception 'Enter a non-zero whole MMK adjustment and reason';end if;
  insert into public.payroll_adjustments(school_id,draft_id,teacher_id,amount_mmk,reason,reference,created_by)
   values(p_school,prior.id,v_teacher,v_amount,v_reason,coalesce(p_payload->>'reference',''),actor);
  update public.payroll_drafts set version=version+1 where id=prior.id returning * into d;
 elsif p_command='withdraw_adjustment' then
  if v_reason='' then raise exception 'Enter a withdrawal reason';end if;
  select * into adj from public.payroll_adjustments where school_id=p_school and draft_id=prior.id and id=(p_payload->>'adjustment_id')::uuid and active for update;
  if not found then raise exception 'Active adjustment not found';end if;
  update public.payroll_adjustments set active=false,withdrawn_by=actor,withdrawn_at=clock_timestamp(),withdraw_reason=v_reason where id=adj.id;
  update public.payroll_drafts set version=version+1 where id=prior.id returning * into d;
 else
  source:=sayasync_private.payroll_draft_source(p_school,prior.period_start,prior.period_end);
  fresh:=sayasync_private.apply_payroll_adjustments(p_school,prior.id,sayasync_private.build_payroll_draft_snapshot(source));
  if prior.source_fingerprint<>md5(source::text) or prior.snapshot<>fresh then raise exception 'Draft is stale. Recalculate before approval.' using errcode='40001';end if;
  if (fresh->>'included_count')::integer=0 and jsonb_array_length(fresh->'adjustments')=0 then raise exception 'There are no eligible sessions or adjustments to approve';end if;
  if (fresh->>'net_mmk')::numeric<0 or exists(select 1 from jsonb_array_elements(fresh->'teachers') x where (x->>'net_mmk')::numeric<0) then raise exception 'A teacher net amount is negative. Review adjustments before approval';end if;
  update public.payroll_drafts set status='Approved',approved_by=actor,approved_at=clock_timestamp(),version=version+1 where id=prior.id returning * into d;
  for line in select value from jsonb_array_elements(d.snapshot->'lines') where (value->>'included')::boolean loop
   insert into public.payroll_allocations(session_id,school_id,draft_id,session_version,rate_id)
    values((line->>'session_id')::uuid,p_school,d.id,(line->>'session_version')::integer,(line->>'rate_id')::uuid);
  end loop;
 end if;
 result:=to_jsonb(d);
 insert into public.payroll_draft_events(school_id,draft_id,actor_id,action,prior_version,new_version,before_snapshot,after_snapshot,reason)
  values(p_school,d.id,actor,p_command,prior.version,d.version,prior.snapshot,d.snapshot,v_reason);
 insert into sayasync_private.payroll_financial_requests values(p_school,actor,p_request,p_command,p_payload,result);
 return result;
end $$;
revoke all on function public.manage_payroll_approval(uuid,uuid,text,jsonb) from public,anon;
grant execute on function public.manage_payroll_approval(uuid,uuid,text,jsonb) to authenticated;

create or replace function public.payroll_draft_state(p_school uuid,p_id uuid)
returns jsonb language plpgsql security definer set search_path='' as $$
declare d public.payroll_drafts%rowtype;source jsonb;fresh jsonb;
begin
 if not sayasync_private.is_admin(p_school) then raise exception 'Administrator access required' using errcode='42501';end if;
 perform pg_advisory_xact_lock(hashtextextended(p_school::text,0));
 if not sayasync_private.is_admin(p_school) then raise exception 'Administrator access required' using errcode='42501';end if;
 select * into d from public.payroll_drafts where school_id=p_school and id=p_id;
 if not found then raise exception 'Payroll draft not found' using errcode='42501';end if;
 if d.status='Approved' then return jsonb_build_object('draft',to_jsonb(d),'stale',false);end if;
 source:=sayasync_private.payroll_draft_source(p_school,d.period_start,d.period_end);
 fresh:=sayasync_private.apply_payroll_adjustments(p_school,d.id,sayasync_private.build_payroll_draft_snapshot(source));
 return jsonb_build_object('draft',to_jsonb(d),'stale',md5(source::text)<>d.source_fingerprint or fresh<>d.snapshot);
end $$;
create or replace view public.session_records with(security_invoker=true) as
 select s.id,s.code,s.school_id,s.teacher_id,s.class_id,s.assignment_id,s.start_at,s.end_at,s.original_start_at,s.original_end_at,
 s.verification,s.source,s.reason,s.overlap_flag,s.version,s.created_by,s.created_at,s.minutes,
 t.name as teacher_name,t.code as teacher_code,c.name as class_name,c.subject,c.code as class_code,
 concat_ws(' ',t.name,c.name,c.subject,'S'||lpad(s.code::text,4,'0'),'T'||lpad(t.code::text,3,'0')) as search_text,
 case when s.end_at is null then case when (s.start_at at time zone 'Asia/Yangon')::date<(clock_timestamp() at time zone 'Asia/Yangon')::date
 then 'Missing checkout' else 'In progress' end else s.verification end as record_status,
 s.overlap_resolution,s.review_comment,s.reviewed_by,s.reviewed_at,
 exists(select 1 from public.correction_requests cr where cr.session_id=s.id and cr.status='Pending') as pending_correction,
 exists(select 1 from public.payroll_allocations pa where pa.session_id=s.id) as payroll_locked
 from public.teaching_sessions s join public.teachers t on t.id=s.teacher_id join public.classes c on c.id=s.class_id;
commit;
