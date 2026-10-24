-- Development master data. No fictional records are imported.
begin;
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
commit;
