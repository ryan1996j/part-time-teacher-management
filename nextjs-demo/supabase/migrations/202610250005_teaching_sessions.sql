-- Server-authoritative capture. Financial and review mutations are later slices.
begin;
alter table public.teacher_assignments add constraint assignments_session_reference unique(school_id,id,teacher_id,class_id);
create table public.teaching_sessions (
 id uuid primary key default gen_random_uuid(), code bigint generated always as identity,
 school_id uuid not null references public.schools(id),teacher_id uuid not null,class_id uuid not null,assignment_id uuid not null,
 start_at timestamptz not null,end_at timestamptz,original_start_at timestamptz not null,original_end_at timestamptz,
 verification text not null default 'Pending' check(verification in ('Pending','Verified','Rejected')),
 source text not null check(source in ('Teacher check-in','Admin entry')),reason text not null default '',
 overlap_flag boolean not null default false,version integer not null default 1 check(version>0),
 created_by uuid not null references auth.users(id),created_at timestamptz not null default clock_timestamp(),
 minutes bigint generated always as (floor(extract(epoch from(end_at-start_at))/60)::bigint) stored,
 check(end_at is null or end_at>start_at),check(original_end_at is null or original_end_at>original_start_at),
 check(isfinite(start_at) and isfinite(original_start_at) and (end_at is null or isfinite(end_at)) and (original_end_at is null or isfinite(original_end_at))),
 check(length(reason)<=1000),unique(school_id,id),unique(teacher_id,start_at,end_at),
 constraint teaching_sessions_teacher_fk foreign key(school_id,teacher_id) references public.teachers(school_id,id),
 constraint teaching_sessions_class_fk foreign key(school_id,class_id) references public.classes(school_id,id),
 foreign key(school_id,assignment_id,teacher_id,class_id) references public.teacher_assignments(school_id,id,teacher_id,class_id)
);
create unique index one_open_teaching_session on public.teaching_sessions(teacher_id) where end_at is null;
create index sessions_school_time_idx on public.teaching_sessions(school_id,start_at desc,id);
create index sessions_teacher_time_idx on public.teaching_sessions(teacher_id,start_at desc,id);
create table public.session_events (
 id uuid primary key default gen_random_uuid(),school_id uuid not null references public.schools(id),
 session_id uuid not null,actor_id uuid not null references auth.users(id),action text not null,
 before_state jsonb,after_state jsonb not null,reason text not null,created_at timestamptz not null default clock_timestamp(),
 foreign key(school_id,session_id) references public.teaching_sessions(school_id,id)
);
create index session_events_school_session_idx on public.session_events(school_id,session_id,created_at);
create table sayasync_private.session_requests (
 school_id uuid not null references public.schools(id),actor_id uuid not null references auth.users(id),request_id uuid not null,
 command text not null,payload jsonb not null,result jsonb not null,primary key(school_id,actor_id,request_id)
);
revoke all on sayasync_private.session_requests from public,anon,authenticated;
alter table public.teaching_sessions enable row level security;
alter table public.session_events enable row level security;
revoke all on public.teaching_sessions,public.session_events from anon,authenticated;
revoke all on sequence public.teaching_sessions_code_seq from anon,authenticated;
grant select on public.teaching_sessions,public.session_events to authenticated;
grant all on public.teaching_sessions,public.session_events to service_role;
grant usage,select on sequence public.teaching_sessions_code_seq to service_role;
create policy sessions_read on public.teaching_sessions for select to authenticated
 using(sayasync_private.is_admin(school_id) or sayasync_private.owns_teacher(teacher_id));
create policy session_events_read on public.session_events for select to authenticated using(
 sayasync_private.is_admin(school_id) or exists(select 1 from public.teaching_sessions s where s.id=session_id and sayasync_private.owns_teacher(s.teacher_id)));

-- Historical class labels must remain readable after an assignment ends.
alter policy classes_read on public.classes using(sayasync_private.is_admin(school_id) or exists(
 select 1 from public.teacher_assignments a where a.class_id=classes.id and a.effective_from<=clock_timestamp()
 and (a.effective_to is null or a.effective_to>clock_timestamp()) and sayasync_private.owns_teacher(a.teacher_id)
) or exists(select 1 from public.teaching_sessions s where s.class_id=classes.id and sayasync_private.owns_teacher(s.teacher_id)));

create function sayasync_private.protect_session_originals()
returns trigger language plpgsql set search_path='' as $$
begin
 if new.original_start_at is distinct from old.original_start_at or
 (old.original_end_at is not null and new.original_end_at is distinct from old.original_end_at) or
 (old.original_end_at is null and new.original_end_at is not null and
   (old.end_at is not null or new.original_end_at is distinct from new.end_at)) then
  raise exception 'Original capture times are immutable';
 end if;
 return new;
end;
$$;
revoke all on function sayasync_private.protect_session_originals() from public,anon,authenticated;
create trigger preserve_session_originals before update on public.teaching_sessions for each row execute function sayasync_private.protect_session_originals();

-- The existing master-data RPC uses the same school lock as capture operations.
-- Backstop deactivation even if it is attempted through another trusted writer.
create function sayasync_private.prevent_open_session_deactivation()
returns trigger language plpgsql security definer set search_path='' as $$
begin
 if old.active and not new.active then
  perform pg_advisory_xact_lock(hashtextextended(new.school_id::text,0));
  if (tg_table_name='teachers' and exists(select 1 from public.teaching_sessions where teacher_id=new.id and end_at is null))
   or (tg_table_name='classes' and exists(select 1 from public.teaching_sessions where class_id=new.id and end_at is null)) then
   raise exception 'Resolve open teaching records before deactivating this record';
  end if;
 end if;return new;
end;
$$;
revoke all on function sayasync_private.prevent_open_session_deactivation() from public,anon,authenticated;
create trigger teacher_open_session_guard before update on public.teachers for each row execute function sayasync_private.prevent_open_session_deactivation();
create trigger class_open_session_guard before update on public.classes for each row execute function sayasync_private.prevent_open_session_deactivation();

create function sayasync_private.flag_session_overlaps(target_session uuid,actor uuid)
returns void language plpgsql security definer set search_path='' as $$
declare s public.teaching_sessions%rowtype;other public.teaching_sessions%rowtype;prior jsonb;
begin
 select * into s from public.teaching_sessions where id=target_session;
 for other in select * from public.teaching_sessions x where x.teacher_id=s.teacher_id
  and (x.id=s.id or (x.start_at<coalesce(s.end_at,'infinity'::timestamptz) and coalesce(x.end_at,'infinity'::timestamptz)>s.start_at))
  and not x.overlap_flag and exists(select 1 from public.teaching_sessions y where y.teacher_id=x.teacher_id and y.id<>x.id
    and y.start_at<coalesce(x.end_at,'infinity'::timestamptz) and coalesce(y.end_at,'infinity'::timestamptz)>x.start_at)
 loop
  prior:=to_jsonb(other);
  update public.teaching_sessions set overlap_flag=true,verification='Pending',version=version+1 where id=other.id returning * into other;
  insert into public.session_events(school_id,session_id,actor_id,action,before_state,after_state,reason)
   values(other.school_id,other.id,actor,'overlap_flagged',prior,to_jsonb(other),'Overlapping teaching time requires administrator review');
 end loop;
end;
$$;
revoke all on function sayasync_private.flag_session_overlaps(uuid,uuid) from public,anon,authenticated;

create function public.capture_teaching_session(p_school uuid,p_request uuid,p_command text,p_payload jsonb)
returns jsonb language plpgsql security definer set search_path='' as $$
declare actor uuid:=auth.uid();teacher public.teachers%rowtype;s public.teaching_sessions%rowtype;
 previous_request sayasync_private.session_requests%rowtype;stamp timestamptz;assignment uuid;class_uuid uuid;
 start_time timestamptz;end_time timestamptz;prior jsonb;result jsonb;reason text;
begin
 if actor is null or not sayasync_private.is_member(p_school) then raise exception 'Active school access required' using errcode='42501';end if;
 if p_request is null or p_payload is null or jsonb_typeof(p_payload)<>'object' then raise exception 'Invalid capture request';end if;
 perform pg_advisory_xact_lock(hashtextextended(p_school::text,0));
 -- Recheck after waiting on the shared school lock.
 if not sayasync_private.is_member(p_school) then raise exception 'Active school access required' using errcode='42501';end if;
 if p_command in ('check_in','check_out') then
  select t.* into teacher from public.teachers t join public.memberships m on m.school_id=t.school_id and m.user_id=t.user_id
   where t.school_id=p_school and t.user_id=actor and t.active and m.active and m.role='teacher' for update of t;
  if not found then raise exception 'Active linked Teacher account required' using errcode='42501';end if;
 elsif p_command='admin_entry' then
  if not sayasync_private.is_admin(p_school) then raise exception 'Administrator access required' using errcode='42501';end if;
 else raise exception 'Unsupported capture command';end if;
 select * into previous_request from sayasync_private.session_requests where school_id=p_school and actor_id=actor and request_id=p_request;
 if found then
  if previous_request.command<>p_command or previous_request.payload<>p_payload then raise exception 'Request key conflict';end if;
  return previous_request.result;
 end if;
 stamp:=clock_timestamp();
 if p_command='check_in' then
  if exists(select 1 from public.teaching_sessions where teacher_id=teacher.id and end_at is null) then raise exception 'You already have an open teaching record';end if;
  class_uuid:=(p_payload->>'class_id')::uuid;
  select a.id into assignment from public.teacher_assignments a join public.classes c on c.id=a.class_id
   where a.school_id=p_school and a.teacher_id=teacher.id and a.class_id=class_uuid and c.active
    and a.effective_from<=stamp and (a.effective_to is null or a.effective_to>stamp);
  if assignment is null then raise exception 'Select an active class assigned to your account';end if;
  insert into public.teaching_sessions(school_id,teacher_id,class_id,assignment_id,start_at,original_start_at,source,created_by)
   values(p_school,teacher.id,class_uuid,assignment,stamp,stamp,'Teacher check-in',actor) returning * into s;
 elsif p_command='check_out' then
  select * into s from public.teaching_sessions where school_id=p_school and id=(p_payload->>'id')::uuid and teacher_id=teacher.id for update;
  if not found then raise exception 'Your teaching record was not found' using errcode='42501';end if;
  prior:=to_jsonb(s);
  if s.end_at is not null then
   result:=to_jsonb(s);
   insert into sayasync_private.session_requests values(p_school,actor,p_request,p_command,p_payload,result);return result;
  end if;
  if (p_payload->>'version')::integer is null or s.version<>(p_payload->>'version')::integer then raise exception 'Teaching record changed. Refresh before checking out.' using errcode='40001';end if;
  if stamp<=s.start_at then raise exception 'Checkout must be after check-in';end if;
  update public.teaching_sessions set end_at=stamp,original_end_at=stamp,version=version+1 where id=s.id returning * into s;
 else
  select * into teacher from public.teachers where school_id=p_school and id=(p_payload->>'teacher_id')::uuid and active for update;
  if not found then raise exception 'Select an active teacher in your school';end if;
  class_uuid:=(p_payload->>'class_id')::uuid;start_time:=(p_payload->>'start_at')::timestamptz;end_time:=(p_payload->>'end_at')::timestamptz;
  reason:=trim(coalesce(p_payload->>'reason',''));
  if start_time is null or end_time is null or end_time>stamp or end_time-start_time<interval '1 minute' or length(reason) not between 1 and 1000 then
   raise exception 'Enter completed teaching times (at least one minute) and a reason';end if;
  select a.id into assignment from public.teacher_assignments a join public.classes c on c.id=a.class_id
   where a.school_id=p_school and a.teacher_id=teacher.id and a.class_id=class_uuid and c.active
    and a.effective_from<=start_time and (a.effective_to is null or a.effective_to>start_time);
  if assignment is null then raise exception 'Teacher must have an active assignment at the teaching start time';end if;
  insert into public.teaching_sessions(school_id,teacher_id,class_id,assignment_id,start_at,end_at,original_start_at,original_end_at,source,reason,created_by)
   values(p_school,teacher.id,class_uuid,assignment,start_time,end_time,start_time,end_time,'Admin entry',reason,actor) returning * into s;
 end if;
 perform sayasync_private.flag_session_overlaps(s.id,actor);
 select * into s from public.teaching_sessions where id=s.id;
 result:=to_jsonb(s);
 insert into public.session_events(school_id,session_id,actor_id,action,before_state,after_state,reason)
  values(p_school,s.id,actor,p_command,prior,result,coalesce(reason,'Server-timestamp teacher capture'));
 insert into sayasync_private.session_requests values(p_school,actor,p_request,p_command,p_payload,result);
 return result;
end;
$$;
revoke all on function public.capture_teaching_session(uuid,uuid,text,jsonb) from public,anon;
grant execute on function public.capture_teaching_session(uuid,uuid,text,jsonb) to authenticated;

create view public.session_records with(security_invoker=true) as
 select s.*,t.name as teacher_name,t.code as teacher_code,c.name as class_name,c.subject,c.code as class_code,
 concat_ws(' ',t.name,c.name,c.subject,'S'||lpad(s.code::text,4,'0'),'T'||lpad(t.code::text,3,'0')) as search_text,
 case when s.end_at is null then case when (s.start_at at time zone 'Asia/Yangon')::date<(clock_timestamp() at time zone 'Asia/Yangon')::date
   then 'Missing checkout' else 'In progress' end else s.verification end as record_status
 from public.teaching_sessions s join public.teachers t on t.id=s.teacher_id join public.classes c on c.id=s.class_id;
revoke all on public.session_records from anon,authenticated;
grant select on public.session_records to authenticated,service_role;
create function public.teaching_server_time() returns timestamptz language sql volatile set search_path='' as $$ select clock_timestamp(); $$;
revoke all on function public.teaching_server_time() from public,anon;
grant execute on function public.teaching_server_time() to authenticated;
commit;
