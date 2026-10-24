-- Approved development project: ereyjhtkypeowifrmyqv.
-- Additive migration. No initial administrator or school membership is granted.
begin;

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
commit;
