-- Additive development migration. No existing attendance is rewritten.
begin;
alter table public.teaching_sessions add column overlap_resolution text not null default '' check(length(overlap_resolution)<=1000);
alter table public.teaching_sessions add column review_comment text not null default '' check(length(review_comment)<=1000);
alter table public.teaching_sessions add column reviewed_by uuid references auth.users(id);
alter table public.teaching_sessions add column reviewed_at timestamptz;
-- Financial allocation/locking will be implemented with the payroll slice.
create table public.correction_requests (
 id uuid primary key default gen_random_uuid(),code bigint generated always as identity,
 school_id uuid not null references public.schools(id),session_id uuid not null,
 base_version integer not null check(base_version>0),prior_snapshot jsonb not null,
 proposed_start timestamptz not null,proposed_end timestamptz not null,
 reason text not null check(length(trim(reason)) between 1 and 1000),
 status text not null default 'Pending' check(status in ('Pending','Approved','Rejected','Withdrawn')),
 requested_by uuid not null references auth.users(id),created_at timestamptz not null default clock_timestamp(),
 reviewer_id uuid references auth.users(id),reviewed_at timestamptz,review_comment text not null default '' check(length(review_comment)<=1000),
 version integer not null default 1 check(version>0),
 check(isfinite(proposed_start) and isfinite(proposed_end) and proposed_end-proposed_start>=interval '1 minute'),
 foreign key(school_id,session_id) references public.teaching_sessions(school_id,id)
);
create unique index one_pending_correction on public.correction_requests(session_id) where status='Pending';
create index corrections_school_time on public.correction_requests(school_id,created_at desc,id);
alter table public.correction_requests enable row level security;
revoke all on public.correction_requests from anon,authenticated;
grant select on public.correction_requests to authenticated;
grant all on public.correction_requests to service_role;
revoke all on sequence public.correction_requests_code_seq from anon,authenticated;
grant usage,select on sequence public.correction_requests_code_seq to service_role;
create policy corrections_read on public.correction_requests for select to authenticated using(
 sayasync_private.is_admin(school_id) or exists(select 1 from public.teaching_sessions s where s.id=session_id and sayasync_private.owns_teacher(s.teacher_id)));

-- Recalculate overlap after capture/correction; new timing evidence invalidates prior
-- overlap decisions conservatively, including the other affected teacher records.
create or replace function sayasync_private.flag_session_overlaps(target_session uuid,actor uuid)
returns void language plpgsql security definer set search_path='' as $$
declare target public.teaching_sessions%rowtype;rec public.teaching_sessions%rowtype;v_overlap boolean;prior jsonb;
begin
 select * into target from public.teaching_sessions where id=target_session;
 for rec in select * from public.teaching_sessions where teacher_id=target.teacher_id order by id for update loop
  v_overlap:=exists(select 1 from public.teaching_sessions x where x.teacher_id=rec.teacher_id and x.id<>rec.id
   and x.start_at<coalesce(rec.end_at,'infinity'::timestamptz) and coalesce(x.end_at,'infinity'::timestamptz)>rec.start_at);
  if rec.overlap_flag is distinct from v_overlap or (v_overlap and (rec.overlap_resolution<>'' or rec.verification='Verified')) then
   prior:=to_jsonb(rec);
   update public.teaching_sessions set overlap_flag=v_overlap,overlap_resolution='',verification='Pending',
    reviewed_by=null,reviewed_at=null,review_comment='',version=version+1 where id=rec.id returning * into rec;
   insert into public.session_events(school_id,session_id,actor_id,action,before_state,after_state,reason)
    values(rec.school_id,rec.id,actor,'overlap_rechecked',prior,to_jsonb(rec),'Teaching times changed; overlap and previous review rechecked');
  end if;
 end loop;
end $$;

create or replace function public.review_teaching_session(p_school uuid,p_request uuid,p_command text,p_payload jsonb)
returns jsonb language plpgsql security definer set search_path='' as $$
declare actor uuid:=auth.uid();admin boolean;rec public.teaching_sessions%rowtype;cr public.correction_requests%rowtype;
 previous sayasync_private.session_requests%rowtype;prior jsonb;result jsonb;v_reason text;v_start timestamptz;v_end timestamptz;decision text;assignment uuid;
begin
 if actor is null or not sayasync_private.is_member(p_school) then raise exception 'Active school access required' using errcode='42501';end if;
 if p_request is null or p_payload is null or jsonb_typeof(p_payload)<>'object' then raise exception 'Invalid review request';end if;
 perform pg_advisory_xact_lock(hashtextextended(p_school::text,0));
 if not sayasync_private.is_member(p_school) then raise exception 'Active school access required' using errcode='42501';end if;
 admin:=sayasync_private.is_admin(p_school);
 if not admin and not exists(select 1 from public.teachers t where t.school_id=p_school and t.user_id=actor and sayasync_private.owns_teacher(t.id)) then
  raise exception 'Active linked Teacher account required' using errcode='42501';end if;
 if p_command not in ('request_correction','withdraw_correction','review_correction','verify_session') then raise exception 'Unsupported review command';end if;
 if p_command in ('review_correction','verify_session') and not admin then raise exception 'Administrator access required' using errcode='42501';end if;
 select * into previous from sayasync_private.session_requests where school_id=p_school and actor_id=actor and request_id=p_request;
 if found then
  if previous.command<>p_command or previous.payload<>p_payload then raise exception 'Request key conflict';end if;return previous.result;
 end if;
 if p_command in ('withdraw_correction','review_correction') then
  select * into cr from public.correction_requests where school_id=p_school and id=(p_payload->>'id')::uuid for update;
  if not found then raise exception 'Correction request not found' using errcode='42501';end if;
  select * into rec from public.teaching_sessions where id=cr.session_id for update;
 else
  select * into rec from public.teaching_sessions where school_id=p_school and id=(p_payload->>'id')::uuid for update;
 end if;
 if rec.id is null or (not admin and not sayasync_private.owns_teacher(rec.teacher_id)) then raise exception 'Your class record was not found' using errcode='42501';end if;
 v_reason:=trim(coalesce(p_payload->>'reason',''));
 if length(v_reason)>1000 then raise exception 'Reason must be at most 1000 characters';end if;
 prior:=to_jsonb(rec);
 if p_command='request_correction' then
  if (p_payload->>'version')::integer is null or rec.version<>(p_payload->>'version')::integer then raise exception 'Record changed. Refresh before continuing.' using errcode='40001';end if;
  if exists(select 1 from public.correction_requests where session_id=rec.id and status='Pending') then raise exception 'A correction is already pending for this class record';end if;
  v_start:=(p_payload->>'start_at')::timestamptz;v_end:=(p_payload->>'end_at')::timestamptz;
  if v_start is null or v_end is null or not isfinite(v_start) or not isfinite(v_end) or v_end>clock_timestamp() or v_end-v_start<interval '1 minute' or v_reason='' then raise exception 'Enter completed times (at least one minute) and a reason';end if;
  if v_start=rec.start_at and v_end is not distinct from rec.end_at then raise exception 'Proposed times must differ from the current record';end if;
  insert into public.correction_requests(school_id,session_id,base_version,prior_snapshot,proposed_start,proposed_end,reason,requested_by)
   values(p_school,rec.id,rec.version,prior,v_start,v_end,v_reason,actor) returning * into cr;
  result:=to_jsonb(cr);
 elsif p_command in ('withdraw_correction','review_correction') then
  if cr.status<>'Pending' or (p_payload->>'version')::integer is null or cr.version<>(p_payload->>'version')::integer then raise exception 'Request changed. Refresh before continuing.' using errcode='40001';end if;
  if p_command='withdraw_correction' then
   if cr.requested_by<>actor then raise exception 'Only the requester can withdraw this correction' using errcode='42501';end if;
   decision:='Withdrawn';
  else
   decision:=p_payload->>'decision';
   if decision is null or decision not in ('Approved','Rejected') then raise exception 'Choose Approve or Reject';end if;
   if decision='Rejected' and v_reason='' then raise exception 'Enter a rejection reason';end if;
   if decision='Approved' then
    if cr.base_version<>rec.version or (p_payload->>'session_version')::integer is null or (p_payload->>'session_version')::integer<>rec.version then raise exception 'Record changed. Reject or withdraw the stale request and submit a new correction.' using errcode='40001';end if;
    if cr.proposed_end>clock_timestamp() then raise exception 'Correction end time cannot be in the future';end if;
    select id into assignment from public.teacher_assignments where school_id=p_school and teacher_id=rec.teacher_id and class_id=rec.class_id
     and effective_from<=cr.proposed_start and (effective_to is null or effective_to>cr.proposed_start);
    if assignment is null then raise exception 'An assignment must cover the corrected start time';end if;
    update public.teaching_sessions set start_at=cr.proposed_start,end_at=cr.proposed_end,assignment_id=assignment,
     verification='Pending',reviewed_at=null,reviewed_by=null,review_comment='',overlap_resolution='',version=version+1 where id=rec.id;
    perform sayasync_private.flag_session_overlaps(rec.id,actor);
   end if;
  end if;
  update public.correction_requests set status=decision,reviewer_id=actor,reviewed_at=clock_timestamp(),review_comment=v_reason,version=version+1 where id=cr.id returning * into cr;
  result:=to_jsonb(cr);
 else
  if (p_payload->>'version')::integer is null or rec.version<>(p_payload->>'version')::integer then raise exception 'Record changed. Refresh before continuing.' using errcode='40001';end if;
  decision:=p_payload->>'decision';
  if decision is null or decision not in ('Verified','Rejected') then raise exception 'Choose Verify or Reject';end if;
  if exists(select 1 from public.correction_requests where session_id=rec.id and status='Pending') then raise exception 'Resolve the pending correction before reviewing this class record';end if;
  if decision='Verified' then
   if rec.end_at is null or rec.minutes<1 or rec.end_at>clock_timestamp() then raise exception 'Only completed records with at least one minute can be verified';end if;
   if not exists(select 1 from public.teacher_assignments where id=rec.assignment_id and effective_from<=rec.start_at and (effective_to is null or effective_to>rec.start_at)) then raise exception 'Resolve the class assignment before verification';end if;
   if rec.overlap_flag and v_reason='' then raise exception 'Explain how the overlapping time was reviewed before verifying';end if;
  elsif v_reason='' then raise exception 'Enter a rejection reason';end if;
  update public.teaching_sessions set verification=decision,review_comment=v_reason,reviewed_by=actor,reviewed_at=clock_timestamp(),
   overlap_resolution=case when decision='Verified' and overlap_flag then v_reason else '' end,version=version+1 where id=rec.id returning * into rec;
  result:=to_jsonb(rec);
 end if;
 select * into rec from public.teaching_sessions where id=rec.id;
 insert into public.session_events(school_id,session_id,actor_id,action,before_state,after_state,reason)
  values(p_school,rec.id,actor,p_command,prior,jsonb_build_object('session',to_jsonb(rec),'correction',case when cr.id is not null then to_jsonb(cr) else null end),v_reason);
 insert into sayasync_private.session_requests values(p_school,actor,p_request,p_command,p_payload,result);
 return result;
end $$;
revoke all on function public.review_teaching_session(uuid,uuid,text,jsonb) from public,anon;
grant execute on function public.review_teaching_session(uuid,uuid,text,jsonb) to authenticated;
-- Preserve existing view column order; append review fields at the end.
create or replace view public.session_records with(security_invoker=true) as
 select s.id,s.code,s.school_id,s.teacher_id,s.class_id,s.assignment_id,s.start_at,s.end_at,s.original_start_at,s.original_end_at,
 s.verification,s.source,s.reason,s.overlap_flag,s.version,s.created_by,s.created_at,s.minutes,
 t.name as teacher_name,t.code as teacher_code,c.name as class_name,c.subject,c.code as class_code,
 concat_ws(' ',t.name,c.name,c.subject,'S'||lpad(s.code::text,4,'0'),'T'||lpad(t.code::text,3,'0')) as search_text,
 case when s.end_at is null then case when (s.start_at at time zone 'Asia/Yangon')::date<(clock_timestamp() at time zone 'Asia/Yangon')::date
 then 'Missing checkout' else 'In progress' end else s.verification end as record_status,
 s.overlap_resolution,s.review_comment,s.reviewed_by,s.reviewed_at,
 exists(select 1 from public.correction_requests cr where cr.session_id=s.id and cr.status='Pending') as pending_correction
 from public.teaching_sessions s join public.teachers t on t.id=s.teacher_id join public.classes c on c.id=s.class_id;
create view public.correction_records with(security_invoker=true) as
 select cr.*,s.teacher_id,s.teacher_name,s.teacher_code,s.class_name,s.subject,s.code as session_code,s.start_at,s.end_at,
 s.original_start_at,s.original_end_at,s.version as session_version,s.verification,s.overlap_flag
 from public.correction_requests cr join public.session_records s on s.id=cr.session_id;
revoke all on public.correction_records from anon,authenticated;
grant select on public.correction_records to authenticated,service_role;
commit;
