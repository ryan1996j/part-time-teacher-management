-- Disposable fixtures; all inserts are rolled back. Sends no email.
begin;
insert into auth.users(id) values
 ('10000000-0000-4000-8000-000000000001'),
 ('10000000-0000-4000-8000-000000000002'),
 ('10000000-0000-4000-8000-000000000003'),
 ('10000000-0000-4000-8000-000000000004');
insert into public.schools(id,name) values
 ('20000000-0000-4000-8000-000000000001','Disposable school A'),
 ('20000000-0000-4000-8000-000000000002','Disposable school B');
insert into public.memberships(school_id,user_id,role,active) values
 ('20000000-0000-4000-8000-000000000001','10000000-0000-4000-8000-000000000001','admin',true),
 ('20000000-0000-4000-8000-000000000001','10000000-0000-4000-8000-000000000002','teacher',true),
 ('20000000-0000-4000-8000-000000000001','10000000-0000-4000-8000-000000000003','teacher',false),
 ('20000000-0000-4000-8000-000000000002','10000000-0000-4000-8000-000000000004','admin',true);

set local role authenticated;
select set_config('request.jwt.claim.sub','10000000-0000-4000-8000-000000000001',true);
do $$ begin
 if (select count(*) from public.schools) <> 1 then raise exception 'Admin school isolation failed'; end if;
 if (select count(*) from public.memberships) <> 3 then raise exception 'Admin membership visibility failed'; end if;
 if (select count(*) from public.profiles) <> 3 then raise exception 'Admin profile isolation failed'; end if;
end $$;

select set_config('request.jwt.claim.sub','10000000-0000-4000-8000-000000000002',true);
do $$ begin
 if (select count(*) from public.schools) <> 1 then raise exception 'Teacher school visibility failed'; end if;
 if (select count(*) from public.memberships) <> 1 then raise exception 'Teacher membership isolation failed'; end if;
 if (select count(*) from public.profiles) <> 1 then raise exception 'Teacher profile isolation failed'; end if;
 begin
  update public.memberships set role='admin' where user_id=auth.uid();
  raise exception 'Teacher privilege escalation was allowed';
 exception when insufficient_privilege then null; end;
 begin
  insert into public.schools(name) values ('Must not be created');
  raise exception 'Untrusted school creation was allowed';
 exception when insufficient_privilege then null; end;
end $$;

select set_config('request.jwt.claim.sub','10000000-0000-4000-8000-000000000003',true);
do $$ begin
 if exists(select 1 from public.schools) or exists(select 1 from public.memberships)
 then raise exception 'Deactivated membership retained access'; end if;
end $$;

select set_config('request.jwt.claim.sub','10000000-0000-4000-8000-000000000004',true);
do $$ begin
 if (select count(*) from public.schools) <> 1 or (select count(*) from public.memberships) <> 1
 or (select count(*) from public.profiles) <> 1 then raise exception 'Second school isolation failed'; end if;
end $$;

reset role;
update public.schools set active=false where id='20000000-0000-4000-8000-000000000002';
set local role authenticated;
do $$ begin
 if exists(select 1 from public.schools) or exists(select 1 from public.memberships)
 then raise exception 'Disabled school retained access'; end if;
end $$;

reset role;
set local role anon;
do $$ begin
 begin
  perform 1 from public.profiles;
  raise exception 'Anonymous profile read was allowed';
 exception when insufficient_privilege then null; end;
end $$;
reset role;
select 'PASS: admin/teacher isolation, cross-school isolation, inactive membership, disabled school, anonymous denial, privilege escalation denial' as result;
rollback;
