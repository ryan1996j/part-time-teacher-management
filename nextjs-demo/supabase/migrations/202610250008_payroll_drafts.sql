-- Draft calculation only. No approvals, allocations, payments or attendance edits.
begin;
create table public.payroll_drafts (
 id uuid primary key default gen_random_uuid(),code bigint generated always as identity,
 school_id uuid not null references public.schools(id),period_start date not null,period_end date not null,
 status text not null default 'Draft' check(status='Draft'),version integer not null default 1 check(version>0),
 policy_version text not null default 'mmk-minute-v1' check(policy_version='mmk-minute-v1'),
 source_fingerprint text not null,snapshot jsonb not null,created_by uuid not null references auth.users(id),
 calculated_by uuid not null references auth.users(id),created_at timestamptz not null default clock_timestamp(),calculated_at timestamptz not null default clock_timestamp(),
 check(isfinite(period_start) and isfinite(period_end) and period_start<=period_end),unique(school_id,id)
);
create index payroll_drafts_school_created on public.payroll_drafts(school_id,created_at desc,id);
create table public.payroll_draft_events (
 id uuid primary key default gen_random_uuid(),school_id uuid not null, draft_id uuid not null,
 actor_id uuid not null references auth.users(id),action text not null,prior_version integer,new_version integer not null,
 before_snapshot jsonb,after_snapshot jsonb not null,created_at timestamptz not null default clock_timestamp(),
 foreign key(school_id,draft_id) references public.payroll_drafts(school_id,id)
);
create table sayasync_private.payroll_draft_requests (
 school_id uuid not null references public.schools(id),actor_id uuid not null references auth.users(id),request_id uuid not null,
 payload jsonb not null,result jsonb not null,primary key(school_id,actor_id,request_id)
);
revoke all on sayasync_private.payroll_draft_requests from public,anon,authenticated;
alter table public.payroll_drafts enable row level security;
alter table public.payroll_draft_events enable row level security;
revoke all on public.payroll_drafts,public.payroll_draft_events from anon,authenticated;
grant select on public.payroll_drafts,public.payroll_draft_events to authenticated;
grant all on public.payroll_drafts,public.payroll_draft_events to service_role;
revoke all on sequence public.payroll_drafts_code_seq from anon,authenticated;
grant usage,select on sequence public.payroll_drafts_code_seq to service_role;
create policy drafts_admin_read on public.payroll_drafts for select to authenticated using(sayasync_private.is_admin(school_id));
create policy draft_events_admin_read on public.payroll_draft_events for select to authenticated using(sayasync_private.is_admin(school_id));

-- The fingerprint covers period membership, effective/original data, correction
-- history, applicable rate version, assignment history, labels and policy.
create function sayasync_private.payroll_draft_source(p_school uuid,p_from date,p_to date)
returns jsonb language sql stable security definer set search_path='' as $$
 select jsonb_build_object('policy','mmk-minute-v1','timezone','Asia/Yangon','period_start',p_from,'period_end',p_to,
 'records',coalesce((select jsonb_agg(jsonb_build_object('session',to_jsonb(s),'teacher_name',t.name,'teacher_code',t.code,
  'class_name',c.name,'subject',c.subject,'assignment',to_jsonb(a),'rate',to_jsonb(r),
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

create function sayasync_private.build_payroll_draft_snapshot(source jsonb)
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

create function public.calculate_payroll_draft(p_school uuid,p_request uuid,p_payload jsonb)
returns jsonb language plpgsql security definer set search_path='' as $$
declare actor uuid:=auth.uid();prior_request sayasync_private.payroll_draft_requests%rowtype;
 draft public.payroll_drafts%rowtype;prior public.payroll_drafts%rowtype;v_from date;v_to date;source jsonb;v_snapshot jsonb;result jsonb;
begin
 if actor is null or not sayasync_private.is_admin(p_school) then raise exception 'Administrator access required' using errcode='42501';end if;
 if p_request is null or p_payload is null or jsonb_typeof(p_payload)<>'object' then raise exception 'Invalid payroll draft request';end if;
 perform pg_advisory_xact_lock(hashtextextended(p_school::text,0));
 if not sayasync_private.is_admin(p_school) then raise exception 'Administrator access required' using errcode='42501';end if;
 select * into prior_request from sayasync_private.payroll_draft_requests where school_id=p_school and actor_id=actor and request_id=p_request;
 if found then if prior_request.payload<>p_payload then raise exception 'Request key conflict';end if;return prior_request.result;end if;
 v_from:=(p_payload->>'period_start')::date;v_to:=(p_payload->>'period_end')::date;
 if v_from is null or v_to is null or not isfinite(v_from) or not isfinite(v_to) or v_from>v_to then raise exception 'Choose a valid payroll period';end if;
 if p_payload->>'id' is not null then
  select * into prior from public.payroll_drafts where school_id=p_school and id=(p_payload->>'id')::uuid for update;
  if not found then raise exception 'Payroll draft not found' using errcode='42501';end if;
  if (p_payload->>'version')::integer is null or prior.version<>(p_payload->>'version')::integer then raise exception 'Draft changed. Refresh before recalculating.' using errcode='40001';end if;
  if prior.period_start<>v_from or prior.period_end<>v_to then raise exception 'Choose New draft to calculate another period';end if;
 end if;
 source:=sayasync_private.payroll_draft_source(p_school,v_from,v_to);
 v_snapshot:=sayasync_private.build_payroll_draft_snapshot(source);
 if prior.id is null then
  insert into public.payroll_drafts(school_id,period_start,period_end,source_fingerprint,snapshot,created_by,calculated_by)
   values(p_school,v_from,v_to,md5(source::text),v_snapshot,actor,actor) returning * into draft;
 else
  update public.payroll_drafts set snapshot=v_snapshot,source_fingerprint=md5(source::text),calculated_at=clock_timestamp(),calculated_by=actor,version=version+1
   where id=prior.id returning * into draft;
 end if;
 result:=to_jsonb(draft);
 insert into public.payroll_draft_events(school_id,draft_id,actor_id,action,prior_version,new_version,before_snapshot,after_snapshot)
  values(p_school,draft.id,actor,case when prior.id is null then 'calculate' else 'recalculate' end,prior.version,draft.version,prior.snapshot,draft.snapshot);
 insert into sayasync_private.payroll_draft_requests values(p_school,actor,p_request,p_payload,result);
 return result;
end $$;
revoke all on function public.calculate_payroll_draft(uuid,uuid,jsonb) from public,anon;
grant execute on function public.calculate_payroll_draft(uuid,uuid,jsonb) to authenticated;

create function public.payroll_draft_state(p_school uuid,p_id uuid)
returns jsonb language plpgsql security definer set search_path='' as $$
declare draft public.payroll_drafts%rowtype;fingerprint text;
begin
 if not sayasync_private.is_admin(p_school) then raise exception 'Administrator access required' using errcode='42501';end if;
 perform pg_advisory_xact_lock(hashtextextended(p_school::text,0));
 if not sayasync_private.is_admin(p_school) then raise exception 'Administrator access required' using errcode='42501';end if;
 select * into draft from public.payroll_drafts where school_id=p_school and id=p_id;
 if not found then raise exception 'Payroll draft not found' using errcode='42501';end if;
 fingerprint:=md5(sayasync_private.payroll_draft_source(p_school,draft.period_start,draft.period_end)::text);
 return jsonb_build_object('draft',to_jsonb(draft),'stale',fingerprint<>draft.source_fingerprint);
end $$;
revoke all on function public.payroll_draft_state(uuid,uuid) from public,anon;
grant execute on function public.payroll_draft_state(uuid,uuid) to authenticated;
commit;
