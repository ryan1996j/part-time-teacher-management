-- No invitation email sent. All fixture rows roll back.
begin;
insert into auth.users(id,email,invited_at,email_confirmed_at) values
 ('60000000-0000-4000-8000-000000000001','link-admin-a@example.com',now(),now()),
 ('60000000-0000-4000-8000-000000000002','link-teacher@example.com',now(),null),
 ('60000000-0000-4000-8000-000000000003','link-admin-b@example.com',now(),now()),
 ('60000000-0000-4000-8000-000000000004','link-disabled@example.com',now(),now());
insert into public.schools(id,name) values
 ('70000000-0000-4000-8000-000000000001','Disposable link school A'),
 ('70000000-0000-4000-8000-000000000002','Disposable link school B');
insert into public.memberships(school_id,user_id,role,active) values
 ('70000000-0000-4000-8000-000000000001','60000000-0000-4000-8000-000000000001','admin',true),
 ('70000000-0000-4000-8000-000000000002','60000000-0000-4000-8000-000000000003','admin',true),
 ('70000000-0000-4000-8000-000000000001','60000000-0000-4000-8000-000000000004','teacher',false);
insert into public.teachers(id,school_id,name,email) values
 ('80000000-0000-4000-8000-000000000001','70000000-0000-4000-8000-000000000001','Invited fixture','link-teacher@example.com'),
 ('80000000-0000-4000-8000-000000000002','70000000-0000-4000-8000-000000000001','No invitation','link-absent@example.com'),
 ('80000000-0000-4000-8000-000000000003','70000000-0000-4000-8000-000000000001','Existing admin','link-admin-a@example.com'),
 ('80000000-0000-4000-8000-000000000004','70000000-0000-4000-8000-000000000001','Disabled member','link-disabled@example.com'),
 ('80000000-0000-4000-8000-000000000005','70000000-0000-4000-8000-000000000002','Other school duplicate','link-teacher@example.com');
set local role authenticated;
select set_config('request.jwt.claim.sub','60000000-0000-4000-8000-000000000001',true);
do $$
declare s uuid:='70000000-0000-4000-8000-000000000001';t uuid:='80000000-0000-4000-8000-000000000001';r uuid:=gen_random_uuid();first_result jsonb;again jsonb;
begin
 if (select account_state from public.teacher_account_states(s) where teacher_id=t)<>'ready_to_link' then raise exception 'Pending invitation state missing';end if;
 first_result:=public.link_teacher_account(s,t,1,r,'Approved fixture access');
 again:=public.link_teacher_account(s,t,1,r,'Approved fixture access');
 if first_result<>again or (select count(*) from public.master_data_events)<>1 then raise exception 'Link retry created duplicate access/audit';end if;
 if not exists(select 1 from public.memberships where user_id='60000000-0000-4000-8000-000000000002' and role='teacher' and active) then raise exception 'Teacher membership not created';end if;
 if (select account_state from public.teacher_account_states(s) where teacher_id=t)<>'linked_pending' then raise exception 'Invitation pending state lost';end if;
 begin perform public.link_teacher_account(s,t,1,gen_random_uuid(),'Stale request');raise exception 'Stale link accepted';exception when serialization_failure then null;end;
 begin perform public.link_teacher_account(s,'80000000-0000-4000-8000-000000000002',1,gen_random_uuid(),'Missing invitation');raise exception 'Uninvited account granted access';exception when raise_exception then if SQLERRM='Uninvited account granted access' then raise;end if;end;
 begin perform public.link_teacher_account(s,'80000000-0000-4000-8000-000000000003',1,gen_random_uuid(),'Must not demote administrator');raise exception 'Admin account linked as teacher';exception when raise_exception then if SQLERRM='Admin account linked as teacher' then raise;end if;end;
 begin perform public.link_teacher_account(s,'80000000-0000-4000-8000-000000000004',1,gen_random_uuid(),'Must not reactivate disabled member');raise exception 'Disabled account silently reactivated';exception when raise_exception then if SQLERRM='Disabled account silently reactivated' then raise;end if;end;
 begin perform public.link_teacher_account('70000000-0000-4000-8000-000000000002','80000000-0000-4000-8000-000000000005',1,gen_random_uuid(),'Wrong school');raise exception 'Foreign school operation allowed';exception when insufficient_privilege then null;end;
end $$;
select set_config('request.jwt.claim.sub','60000000-0000-4000-8000-000000000003',true);
do $$ begin
 begin perform public.link_teacher_account('70000000-0000-4000-8000-000000000002','80000000-0000-4000-8000-000000000005',1,gen_random_uuid(),'Already linked in another school');raise exception 'Cross-school account takeover allowed';exception when raise_exception then if SQLERRM='Cross-school account takeover allowed' then raise;end if;end;
end $$;
select set_config('request.jwt.claim.sub','60000000-0000-4000-8000-000000000002',true);
do $$ begin
 if (select count(*) from public.teachers)<>1 then raise exception 'Linked teacher own profile access failed';end if;
 begin perform public.teacher_account_states('70000000-0000-4000-8000-000000000001');raise exception 'Teacher enumerated account access';exception when insufficient_privilege then null;end;
 begin perform public.link_teacher_account('70000000-0000-4000-8000-000000000001','80000000-0000-4000-8000-000000000002',1,gen_random_uuid(),'Forbidden grant');raise exception 'Teacher granted access';exception when insufficient_privilege then null;end;
end $$;
reset role;
do $$ begin
 if (select role from public.memberships where school_id='70000000-0000-4000-8000-000000000001' and user_id='60000000-0000-4000-8000-000000000001')<>'admin' then raise exception 'Admin role changed';end if;
 if (select active from public.memberships where school_id='70000000-0000-4000-8000-000000000001' and user_id='60000000-0000-4000-8000-000000000004') then raise exception 'Disabled membership changed';end if;
end $$;
select 'PASS: exact-email linking, teacher-only role, idempotency, stale rejection, missing invitation denial, admin protection, disabled-account protection, tenant isolation and teacher grant denial' as result;
rollback;
