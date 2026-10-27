-- DEVELOPMENT ONLY: tdrwggtpmzgazyceqeym. Schema only, no users or production data.
-- Historical source comments may mention the original project; UI target is the NEW development project.
begin;
do $$ begin
 if exists(select 1 from auth.users) or exists(select 1 from pg_class c join pg_namespace n on n.oid=c.relnamespace where n.nspname in ('public','sayasync_private') and c.relkind in ('r','p','v','m','S')) then raise exception 'Expected empty development target; stop and inspect';end if;
end $$;
-- SOURCE 202610250001_identity_foundation.sql
-- Approved development project: ereyjhtkypeowifrmyqv.
-- Additive migration. No initial administrator or school membership is granted.

create schema if not exists sayasync_private;
revoke all on schema sayasync_private from public, anon;
grant usage on schema sayasync_private to authenticated;

create table public.schools (
  id uuid primary key default gen_random_uuid(),
  name text not null check (length(trim(name)) between 1 and 160),
  timezone text not null default 'Asia/Yangon' check (timezone = 'Asia/Yangon'),
  currency text not null default 'MMK' check (currency = 'MMK'),
  active boolean not null default true,
  created_at timestamptz not null default now()
);

create table public.profiles (
  user_id uuid primary key references auth.users(id) on delete cascade,
  display_name text not null default '' check (length(display_name) <= 160),
  created_at timestamptz not null default now()
);

create table public.memberships (
  school_id uuid not null references public.schools(id) on delete restrict,
  user_id uuid not null references public.profiles(user_id) on delete restrict,
  role text not null check (role in ('admin','teacher')),
  active boolean not null default true,
  created_at timestamptz not null default now(),
  primary key (school_id, user_id)
);
create index memberships_user_school_idx on public.memberships(user_id, school_id);

create function sayasync_private.is_member(target_school uuid)
returns boolean language sql stable security definer set search_path = '' as $$
  select exists (
    select 1 from public.memberships m join public.schools s on s.id=m.school_id
    where m.school_id=target_school and m.user_id=(select auth.uid())
      and m.active and s.active
  );
$$;
create function sayasync_private.is_admin(target_school uuid)
returns boolean language sql stable security definer set search_path = '' as $$
  select exists (
    select 1 from public.memberships m join public.schools s on s.id=m.school_id
    where m.school_id=target_school and m.user_id=(select auth.uid())
      and m.role='admin' and m.active and s.active
  );
$$;
revoke all on function sayasync_private.is_member(uuid) from public, anon;
revoke all on function sayasync_private.is_admin(uuid) from public, anon;
grant execute on function sayasync_private.is_member(uuid) to authenticated;
grant execute on function sayasync_private.is_admin(uuid) to authenticated;

alter table public.schools enable row level security;
alter table public.profiles enable row level security;
alter table public.memberships enable row level security;
revoke all on public.schools, public.profiles, public.memberships from anon, authenticated;
grant select on public.schools, public.profiles, public.memberships to authenticated;
grant all on public.schools, public.profiles, public.memberships to service_role;

create policy schools_read_members on public.schools for select to authenticated
  using (sayasync_private.is_member(id));
create policy memberships_read_own_or_school_admin on public.memberships for select to authenticated
  using ((user_id=(select auth.uid()) and sayasync_private.is_member(school_id))
    or sayasync_private.is_admin(school_id));
create policy profiles_read_own_or_school_admin on public.profiles for select to authenticated
  using (user_id=(select auth.uid()) or exists (
    select 1 from public.memberships m where m.user_id=profiles.user_id
      and sayasync_private.is_admin(m.school_id)
  ));

-- This trigger creates only a profile, never a role or membership.
create function sayasync_private.create_auth_profile()
returns trigger language plpgsql security definer set search_path = '' as $$
begin
  insert into public.profiles(user_id) values (new.id);
  return new;
end;
$$;
revoke all on function sayasync_private.create_auth_profile() from public, anon, authenticated;
create trigger sayasync_auth_user_profile after insert on auth.users
  for each row execute function sayasync_private.create_auth_profile();

-- Preserve pre-existing accounts without inventing a school or role.
insert into public.profiles(user_id) select id from auth.users on conflict (user_id) do nothing;

-- SOURCE 202610250002_master_data.sql
-- Development master data. No fictional records are imported.

create extension if not exists btree_gist with schema extensions;
set local search_path=public,extensions,pg_catalog;

create table public.teachers (
 id uuid primary key default gen_random_uuid(), school_id uuid not null references public.schools(id),
 code bigint generated always as identity, name text not null check(length(trim(name)) between 1 and 160),
 email text not null check(length(email)<=254 and email=lower(trim(email)) and email ~ '^[^[:space:]@]+@[^[:space:]@]+\.[^[:space:]@]+$'),
 user_id uuid unique, active boolean not null default true, version integer not null default 1 check(version>0),
 created_at timestamptz not null default now(), unique(school_id,id), unique(school_id,code), unique(school_id,email),
 foreign key(school_id,user_id) references public.memberships(school_id,user_id)
);
create table public.classes (
 id uuid primary key default gen_random_uuid(), school_id uuid not null references public.schools(id),
 code bigint generated always as identity, name text not null check(length(trim(name)) between 1 and 160),
 subject text not null check(length(trim(subject)) between 1 and 160), active boolean not null default true,
 version integer not null default 1 check(version>0), created_at timestamptz not null default now(),
 unique(school_id,id), unique(school_id,code)
);
create table public.teacher_rates (
 id uuid primary key default gen_random_uuid(), school_id uuid not null, teacher_id uuid not null,
 effective_from date not null, hourly_mmk bigint not null check(hourly_mmk between 1 and 9007199254740991),
 reason text not null check(length(trim(reason)) between 1 and 1000), created_by uuid not null references auth.users(id),
 created_at timestamptz not null default now(),
 foreign key(school_id,teacher_id) references public.teachers(school_id,id), unique(teacher_id,effective_from)
 -- Each immutable version runs until the next effective_from; no end date can overlap.
);
create table public.teacher_assignments (
 id uuid primary key default gen_random_uuid(), school_id uuid not null, teacher_id uuid not null, class_id uuid not null,
 effective_from timestamptz not null default now(), effective_to timestamptz,
 reason text not null check(length(trim(reason)) between 1 and 1000), created_by uuid not null references auth.users(id),
 check(effective_to is null or effective_to>effective_from),
 foreign key(school_id,teacher_id) references public.teachers(school_id,id),
 foreign key(school_id,class_id) references public.classes(school_id,id),
 exclude using gist (teacher_id with =,class_id with =,tstzrange(effective_from,effective_to,'[)') with &&)
);
create index teacher_assignments_school_class_idx on public.teacher_assignments(school_id,class_id);
create index teachers_school_user_idx on public.teachers(school_id,user_id);
create index classes_school_idx on public.classes(school_id);
create index teacher_rates_school_idx on public.teacher_rates(school_id);
create table public.master_data_events (
 id uuid primary key default gen_random_uuid(), school_id uuid not null references public.schools(id),
 actor_id uuid not null references auth.users(id), action text not null, entity_id uuid not null,
 before_state jsonb, after_state jsonb not null, reason text not null, created_at timestamptz not null default now()
);
create table sayasync_private.master_requests (
 school_id uuid not null references public.schools(id), actor_id uuid not null references auth.users(id),
 request_id uuid not null, command text not null, payload jsonb not null, result jsonb not null,
 primary key(school_id,actor_id,request_id)
);
revoke all on sayasync_private.master_requests from public,anon,authenticated;

create function sayasync_private.owns_teacher(target_teacher uuid)
returns boolean language sql stable security definer set search_path='' as $$
 select exists(select 1 from public.teachers t where t.id=target_teacher and t.user_id=(select auth.uid()) and t.active
   and sayasync_private.is_member(t.school_id));
$$;
revoke all on function sayasync_private.owns_teacher(uuid) from public,anon;
grant execute on function sayasync_private.owns_teacher(uuid) to authenticated;

alter table public.teachers enable row level security;
alter table public.classes enable row level security;
alter table public.teacher_rates enable row level security;
alter table public.teacher_assignments enable row level security;
alter table public.master_data_events enable row level security;
revoke all on public.teachers,public.classes,public.teacher_rates,public.teacher_assignments,public.master_data_events from anon,authenticated;
grant select on public.teachers,public.classes,public.teacher_rates,public.teacher_assignments,public.master_data_events to authenticated;
grant all on public.teachers,public.classes,public.teacher_rates,public.teacher_assignments,public.master_data_events to service_role;
grant usage,select on sequence public.teachers_code_seq,public.classes_code_seq to service_role;
revoke all on sequence public.teachers_code_seq,public.classes_code_seq from anon,authenticated;
create policy teachers_read on public.teachers for select to authenticated using(sayasync_private.is_admin(school_id) or sayasync_private.owns_teacher(id));
create policy rates_read on public.teacher_rates for select to authenticated using(sayasync_private.is_admin(school_id) or sayasync_private.owns_teacher(teacher_id));
create policy assignments_read on public.teacher_assignments for select to authenticated using(sayasync_private.is_admin(school_id) or sayasync_private.owns_teacher(teacher_id));
create policy classes_read on public.classes for select to authenticated using(sayasync_private.is_admin(school_id) or exists(
 select 1 from public.teacher_assignments a where a.class_id=classes.id and a.effective_from<=now()
 and (a.effective_to is null or a.effective_to>now()) and sayasync_private.owns_teacher(a.teacher_id)));
create policy master_events_admin on public.master_data_events for select to authenticated using(sayasync_private.is_admin(school_id));

create function public.manage_master_data(p_school uuid,p_request uuid,p_command text,p_payload jsonb)
returns jsonb language plpgsql security definer set search_path='' as $$
declare
 actor uuid:=auth.uid(); entity uuid; prior jsonb; result jsonb; reason text;
 chosen uuid[]; previous_request sayasync_private.master_requests%rowtype;
 teacher public.teachers%rowtype; class public.classes%rowtype;
 stamp timestamptz; expected integer; is_active boolean;
begin
 if actor is null or not sayasync_private.is_admin(p_school) then raise exception 'Administrator access required' using errcode='42501'; end if;
 if p_request is null or p_payload is null or jsonb_typeof(p_payload)<>'object' then raise exception 'Invalid request'; end if;
 -- Serialize master-data changes per school; protect assignment replacement and retries.
 perform pg_advisory_xact_lock(hashtextextended(p_school::text,0));
 select * into previous_request from sayasync_private.master_requests where school_id=p_school and actor_id=actor and request_id=p_request;
 if found then
  if previous_request.command<>p_command or previous_request.payload<>p_payload then raise exception 'Request key was already used for different data'; end if;
  return previous_request.result;
 end if;
 reason:=trim(coalesce(p_payload->>'reason',''));
 if length(reason) not between 1 and 1000 then raise exception 'Enter a reason (1–1000 characters)'; end if;
 entity:=nullif(p_payload->>'id','')::uuid;
 expected:=nullif(p_payload->>'version','')::integer;
 stamp:=clock_timestamp();

 if p_command='create_teacher' then
  insert into public.teachers(school_id,name,email) values(p_school,trim(p_payload->>'name'),lower(trim(p_payload->>'email'))) returning * into teacher;
  entity:=teacher.id;
  insert into public.teacher_rates(school_id,teacher_id,effective_from,hourly_mmk,reason,created_by)
   values(p_school,entity,(p_payload->>'from')::date,(p_payload->>'rate')::bigint,reason,actor);
  select coalesce(array_agg(value::uuid),'{}'::uuid[]) into chosen from jsonb_array_elements_text(coalesce(p_payload->'classes','[]'::jsonb));
  if exists(select 1 from unnest(chosen) x where not exists(select 1 from public.classes c where c.id=x and c.school_id=p_school and c.active)) then raise exception 'Select active classes in your school'; end if;
  insert into public.teacher_assignments(school_id,teacher_id,class_id,effective_from,reason,created_by)
   select p_school,entity,x,stamp,reason,actor from (select distinct unnest(chosen) x) ids;
  update public.classes set version=version+1 where school_id=p_school and id=any(chosen);
  result:=to_jsonb(teacher);
 elsif p_command='create_class' then
  insert into public.classes(school_id,name,subject) values(p_school,trim(p_payload->>'name'),trim(p_payload->>'subject')) returning * into class;
  entity:=class.id;result:=to_jsonb(class);
 elsif p_command in ('add_rate','teacher_status','teacher_assignments') then
  select * into teacher from public.teachers where school_id=p_school and id=entity for update;
  if not found then raise exception 'Teacher not found'; end if;
  if expected is null or teacher.version<>expected then raise exception 'Record changed. Reload and try again.' using errcode='40001'; end if;
  prior:=to_jsonb(teacher)||jsonb_build_object('rates',(select coalesce(jsonb_agg(to_jsonb(r)),'[]') from public.teacher_rates r where r.teacher_id=entity),
   'assignment_ids',(select coalesce(jsonb_agg(a.class_id),'[]') from public.teacher_assignments a where a.teacher_id=entity and a.effective_to is null));
  if p_command='add_rate' then
   insert into public.teacher_rates(school_id,teacher_id,effective_from,hourly_mmk,reason,created_by)
    values(p_school,entity,(p_payload->>'from')::date,(p_payload->>'rate')::bigint,reason,actor);
  elsif p_command='teacher_status' then
   is_active:=(p_payload->>'active')::boolean;
   if is_active is null then raise exception 'Status required'; end if;
   update public.teachers set active=is_active where id=entity;
   -- Deactivation also stops access for an existing linked teacher account.
   if not is_active and teacher.user_id is not null then
    update public.memberships set active=false where school_id=p_school and user_id=teacher.user_id and role='teacher';
   end if;
  else
   select coalesce(array_agg(value::uuid),'{}'::uuid[]) into chosen from jsonb_array_elements_text(coalesce(p_payload->'classes','[]'::jsonb));
   if exists(select 1 from unnest(chosen) x where not exists(select 1 from public.classes c where c.id=x and c.school_id=p_school and c.active)) then raise exception 'Select active classes in your school'; end if;
   update public.teacher_assignments a set effective_to=stamp where a.school_id=p_school and a.teacher_id=entity and a.effective_to is null
    and not(a.class_id=any(chosen)) and exists(select 1 from public.classes c where c.id=a.class_id and c.active);
   insert into public.teacher_assignments(school_id,teacher_id,class_id,effective_from,reason,created_by)
    select p_school,entity,x,stamp,reason,actor from (select distinct unnest(chosen) x) ids
    where not exists(select 1 from public.teacher_assignments a where a.teacher_id=entity and a.class_id=x and a.effective_to is null);
   update public.classes c set version=version+1 where c.school_id=p_school and exists(
    select 1 from public.teacher_assignments a where a.teacher_id=entity and a.class_id=c.id and (a.effective_to is null or a.effective_to=stamp));
  end if;
  update public.teachers set version=version+1 where id=entity returning to_jsonb(teachers.*) into result;
 elsif p_command in ('class_status','class_assignments') then
  select * into class from public.classes where school_id=p_school and id=entity for update;
  if not found then raise exception 'Class not found'; end if;
  if expected is null or class.version<>expected then raise exception 'Record changed. Reload and try again.' using errcode='40001'; end if;
  prior:=to_jsonb(class)||jsonb_build_object('assignment_ids',(select coalesce(jsonb_agg(a.teacher_id),'[]') from public.teacher_assignments a where a.class_id=entity and a.effective_to is null));
  if p_command='class_status' then
   is_active:=(p_payload->>'active')::boolean;
   if is_active is null then raise exception 'Status required'; end if;
   update public.classes set active=is_active where id=entity;
  else
   if not class.active then raise exception 'Activate the class before changing assignments'; end if;
   select coalesce(array_agg(value::uuid),'{}'::uuid[]) into chosen from jsonb_array_elements_text(coalesce(p_payload->'teachers','[]'::jsonb));
   if exists(select 1 from unnest(chosen) x where not exists(select 1 from public.teachers t where t.id=x and t.school_id=p_school)) then raise exception 'Select teachers in your school'; end if;
   update public.teacher_assignments set effective_to=stamp where school_id=p_school and class_id=entity and effective_to is null and not(teacher_id=any(chosen));
   insert into public.teacher_assignments(school_id,teacher_id,class_id,effective_from,reason,created_by)
    select p_school,x,entity,stamp,reason,actor from (select distinct unnest(chosen) x) ids
    where not exists(select 1 from public.teacher_assignments a where a.class_id=entity and a.teacher_id=x and a.effective_to is null);
   update public.teachers t set version=version+1 where t.school_id=p_school and exists(
    select 1 from public.teacher_assignments a where a.class_id=entity and a.teacher_id=t.id and (a.effective_to is null or a.effective_to=stamp));
  end if;
  update public.classes set version=version+1 where id=entity returning to_jsonb(classes.*) into result;
 else raise exception 'Unsupported master-data command'; end if;

 -- Capture versions, effective rate history and current assignments for audit.
 if p_command in ('create_teacher','add_rate','teacher_status','teacher_assignments') then
  result:=result||jsonb_build_object('rates',(select coalesce(jsonb_agg(to_jsonb(r)),'[]') from public.teacher_rates r where r.teacher_id=entity),
    'assignment_ids',(select coalesce(jsonb_agg(a.class_id),'[]') from public.teacher_assignments a where a.teacher_id=entity and a.effective_to is null));
 else
  result:=result||jsonb_build_object('assignment_ids',(select coalesce(jsonb_agg(a.teacher_id),'[]') from public.teacher_assignments a where a.class_id=entity and a.effective_to is null));
 end if;
 insert into public.master_data_events(school_id,actor_id,action,entity_id,before_state,after_state,reason)
  values(p_school,actor,p_command,entity,prior,result,reason);
 insert into sayasync_private.master_requests values(p_school,actor,p_request,p_command,p_payload,result);
 return result;
end;
$$;
revoke all on function public.manage_master_data(uuid,uuid,text,jsonb) from public,anon;
grant execute on function public.manage_master_data(uuid,uuid,text,jsonb) to authenticated;

-- SOURCE 202610250003_assignment_visibility.sql
-- Assignments are stamped with clock_timestamp(). A transaction-start now()
-- can precede a just-created assignment in the same transaction.

alter policy classes_read on public.classes using (
 sayasync_private.is_admin(school_id) or exists (
  select 1 from public.teacher_assignments a where a.class_id=classes.id
   and a.effective_from<=clock_timestamp()
   and (a.effective_to is null or a.effective_to>clock_timestamp())
   and sayasync_private.owns_teacher(a.teacher_id)
 )
);

-- SOURCE 202610250004_teacher_accounts.sql
-- Link an already-invited account. No email is sent and no Auth user is created.

create function public.link_teacher_account(p_school uuid,p_teacher uuid,p_version integer,p_request uuid,p_reason text)
returns jsonb language plpgsql security definer set search_path='' as $$
declare
 actor uuid:=auth.uid(); t public.teachers%rowtype; u auth.users%rowtype;
 m public.memberships%rowtype; prior jsonb; result jsonb; payload jsonb;
 previous_request sayasync_private.master_requests%rowtype;
begin
 if actor is null or not sayasync_private.is_admin(p_school) then raise exception 'Administrator access required' using errcode='42501';end if;
 if p_request is null or length(trim(coalesce(p_reason,''))) not between 1 and 1000 then raise exception 'A request ID and reason are required';end if;
 perform pg_advisory_xact_lock(hashtextextended(p_school::text,0));
 payload:=jsonb_build_object('teacher',p_teacher,'version',p_version,'reason',trim(p_reason));
 select * into previous_request from sayasync_private.master_requests where school_id=p_school and actor_id=actor and request_id=p_request;
 if found then
  if previous_request.command<>'link_teacher_account' or previous_request.payload<>payload then raise exception 'Request ID already used';end if;
  return previous_request.result;
 end if;
 select * into t from public.teachers where school_id=p_school and id=p_teacher for update;
 if not found then raise exception 'Teacher not found';end if;
 if p_version is null or t.version<>p_version then raise exception 'Record changed. Reload before linking.' using errcode='40001';end if;
 if not t.active or t.user_id is not null then raise exception 'Only active, unlinked teacher profiles can be linked';end if;
 if (select count(*) from auth.users where lower(email)=t.email)<>1 then raise exception 'The project owner must invite this exact email first';end if;
 select * into u from auth.users where lower(email)=t.email for update;
 if not found or (u.invited_at is null and u.email_confirmed_at is null) then raise exception 'The project owner must invite this exact email first';end if;
 -- Serialize two schools trying to link the same Auth account.
 perform pg_advisory_xact_lock(hashtextextended(u.id::text,1));
 if exists(select 1 from public.teachers where user_id=u.id)
 or exists(select 1 from public.memberships where user_id=u.id and (school_id<>p_school or role<>'teacher'))
 then raise exception 'Account requires project-owner review before linking';end if;
 select * into m from public.memberships where school_id=p_school and user_id=u.id for update;
 if found then
  if not m.active or m.role<>'teacher' then raise exception 'Existing account access requires separate review';end if;
 else
  insert into public.memberships(school_id,user_id,role,active) values(p_school,u.id,'teacher',true);
 end if;
 prior:=to_jsonb(t);
 update public.teachers set user_id=u.id,version=version+1 where id=t.id returning to_jsonb(teachers.*) into result;
 update public.profiles set display_name=t.name where user_id=u.id and display_name='';
 insert into public.master_data_events(school_id,actor_id,action,entity_id,before_state,after_state,reason)
  values(p_school,actor,'link_teacher_account',t.id,prior,result,trim(p_reason));
 insert into sayasync_private.master_requests values(p_school,actor,p_request,'link_teacher_account',payload,result);
 return result;
end;
$$;
revoke all on function public.link_teacher_account(uuid,uuid,integer,uuid,text) from public,anon;
grant execute on function public.link_teacher_account(uuid,uuid,integer,uuid,text) to authenticated;

create function public.teacher_account_states(p_school uuid)
returns table(teacher_id uuid,account_state text)
language plpgsql stable security definer set search_path='' as $$
begin
 if not sayasync_private.is_admin(p_school) then raise exception 'Administrator access required' using errcode='42501';end if;
 return query select t.id,case
  when not t.active then 'disabled'
  when t.user_id is not null then case
   when not coalesce(m.active,false) or m.role<>'teacher' then 'disabled'
   when linked.email_confirmed_at is null then 'linked_pending'
   else 'active' end
  when candidate.id is null or (candidate.invited_at is null and candidate.email_confirmed_at is null) then 'not_linked'
  when exists(select 1 from public.teachers other where other.user_id=candidate.id)
    or exists(select 1 from public.memberships other where other.user_id=candidate.id and (other.school_id<>p_school or other.role<>'teacher' or not other.active)) then 'review_required'
  else 'ready_to_link' end
 from public.teachers t
 left join auth.users linked on linked.id=t.user_id
 left join public.memberships m on m.school_id=t.school_id and m.user_id=t.user_id
 left join auth.users candidate on lower(candidate.email)=t.email
 where t.school_id=p_school;
end;
$$;
revoke all on function public.teacher_account_states(uuid) from public,anon;
grant execute on function public.teacher_account_states(uuid) to authenticated;

-- SOURCE 202610250005_teaching_sessions.sql
-- Server-authoritative capture. Financial and review mutations are later slices.

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

-- SOURCE 202610250006_session_reviews.sql
-- Additive development migration. No existing attendance is rewritten.

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

-- SOURCE 202610250007_review_reason_fix.sql
-- Follow-up to development migration 006: disambiguate reviewer reason variable.

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

-- SOURCE 202610250008_payroll_drafts.sql
-- Draft calculation only. No approvals, allocations, payments or attendance edits.

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

-- SOURCE 202610250009_payroll_approval.sql
-- Approval/adjustment slice. Existing drafts and attendance are preserved.

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

-- SOURCE 202610250010_manual_payments.sql
-- Manual full-payment records only; no transfer, reversal or Void operation.

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

select 'PASS: development schema migrations001-010 applied atomically; no school/users created' as result;
commit;
