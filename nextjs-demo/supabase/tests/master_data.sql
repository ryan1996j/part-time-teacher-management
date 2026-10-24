-- Disposable fixtures only. Real school/account records are untouched.
begin;
insert into auth.users(id) values('30000000-0000-4000-8000-000000000001'),('30000000-0000-4000-8000-000000000002'),('30000000-0000-4000-8000-000000000003');
insert into public.schools(id,name) values('40000000-0000-4000-8000-000000000001','Master test A'),('40000000-0000-4000-8000-000000000002','Master test B');
insert into public.memberships(school_id,user_id,role) values
 ('40000000-0000-4000-8000-000000000001','30000000-0000-4000-8000-000000000001','admin'),
 ('40000000-0000-4000-8000-000000000001','30000000-0000-4000-8000-000000000002','teacher'),
 ('40000000-0000-4000-8000-000000000002','30000000-0000-4000-8000-000000000003','admin');
insert into public.classes(id,school_id,name,subject) values('50000000-0000-4000-8000-000000000001','40000000-0000-4000-8000-000000000002','Other school','Other subject');
set local role authenticated;
select set_config('request.jwt.claim.sub','30000000-0000-4000-8000-000000000001',true);
do $$
declare s uuid:='40000000-0000-4000-8000-000000000001'; c jsonb; t jsonb; repeated jsonb; payload jsonb; tid uuid; cid uuid; v integer; req uuid:=gen_random_uuid();
begin
 c:=public.manage_master_data(s,gen_random_uuid(),'create_class','{"name":"Fixture class","subject":"Mathematics","reason":"Test setup"}');cid:=(c->>'id')::uuid;
 payload:=jsonb_build_object('name','Fixture Teacher','email','master-fixture@example.com','rate',15000,'from','2026-01-01','classes',jsonb_build_array(cid),'reason','Test setup');
 t:=public.manage_master_data(s,req,'create_teacher',payload);tid:=(t->>'id')::uuid;
 repeated:=public.manage_master_data(s,req,'create_teacher',payload);
 if t<>repeated or (select count(*) from public.teachers)<>1 or (select count(*) from public.teacher_assignments)<>1 then raise exception 'Retry created duplicate data'; end if;
 begin perform public.manage_master_data(s,req,'create_teacher',payload||'{"name":"Changed"}');raise exception 'Reused request accepted';exception when raise_exception then if SQLERRM='Reused request accepted' then raise;end if;end;
 begin perform public.manage_master_data(s,gen_random_uuid(),'create_teacher',payload);raise exception 'Duplicate email accepted';exception when unique_violation then null;end;
 begin perform public.manage_master_data(s,gen_random_uuid(),'teacher_assignments',jsonb_build_object('id',tid,'version',1,'classes',jsonb_build_array('50000000-0000-4000-8000-000000000001'),'reason','Cross school test'));raise exception 'Cross-school assignment accepted';exception when raise_exception then if SQLERRM='Cross-school assignment accepted' then raise;end if;end;
 t:=public.manage_master_data(s,gen_random_uuid(),'add_rate',jsonb_build_object('id',tid,'version',1,'rate',20000,'from','2026-02-01','reason','Test raise'));
 if (select count(*) from public.teacher_rates)<>2 then raise exception 'Rate history missing';end if;
 begin perform public.manage_master_data(s,gen_random_uuid(),'add_rate',jsonb_build_object('id',tid,'version',2,'rate',22000,'from','2026-02-01','reason','Duplicate date'));raise exception 'Duplicate rate date accepted';exception when unique_violation then null;end;
 begin perform public.manage_master_data(s,gen_random_uuid(),'teacher_status',jsonb_build_object('id',tid,'version',1,'active',false,'reason','Stale write'));raise exception 'Stale write accepted';exception when serialization_failure then null;end;
 t:=public.manage_master_data(s,gen_random_uuid(),'teacher_assignments',jsonb_build_object('id',tid,'version',2,'classes','[]'::jsonb,'reason','End assignment'));
 if (select count(*) from public.teacher_assignments where effective_to is not null)<>1 then raise exception 'Assignment history lost';end if;
 select version into v from public.classes where id=cid;
 c:=public.manage_master_data(s,gen_random_uuid(),'class_assignments',jsonb_build_object('id',cid,'version',v,'teachers',jsonb_build_array(tid),'reason','Reassign teacher'));
 if (select count(*) from public.teacher_assignments where effective_to is null)<>1 or (select count(*) from public.teacher_assignments)<>2 then raise exception 'Reassignment history invalid';end if;
 begin update public.teachers set active=false where id=tid;raise exception 'Direct write allowed';exception when insufficient_privilege then null;end;
 if (select count(*) from public.master_data_events)<>5 then raise exception 'Audit/idempotency counts invalid';end if;
end $$;
reset role;
-- Link only the disposable test teacher to exercise own-record RLS.
update public.teachers set user_id='30000000-0000-4000-8000-000000000002' where school_id='40000000-0000-4000-8000-000000000001' and email='master-fixture@example.com';
set local role authenticated;
select set_config('request.jwt.claim.sub','30000000-0000-4000-8000-000000000002',true);
do $$ begin
 if (select count(*) from public.teachers)<>1 or (select count(*) from public.classes)<>1 or (select count(*) from public.teacher_rates)<>2 then raise exception 'Teacher own access failed';end if;
 if exists(select 1 from public.master_data_events) then raise exception 'Teacher read full audit';end if;
 begin perform public.manage_master_data('40000000-0000-4000-8000-000000000001',gen_random_uuid(),'create_class','{"name":"Bad","subject":"Bad","reason":"Forbidden"}');raise exception 'Teacher mutation allowed';exception when insufficient_privilege then null;end;
end $$;
select set_config('request.jwt.claim.sub','30000000-0000-4000-8000-000000000003',true);
do $$ begin
 if exists(select 1 from public.teachers) or exists(select 1 from public.teacher_rates) or exists(select 1 from public.teacher_assignments) or (select count(*) from public.classes)<>1 then raise exception 'Cross-school isolation failed';end if;
end $$;
select set_config('request.jwt.claim.sub','30000000-0000-4000-8000-000000000001',true);
do $$ declare t public.teachers%rowtype;begin
 select * into t from public.teachers where email='master-fixture@example.com';
 perform public.manage_master_data(t.school_id,gen_random_uuid(),'teacher_status',jsonb_build_object('id',t.id,'version',t.version,'active',false,'reason','Test deactivation'));
end $$;
select set_config('request.jwt.claim.sub','30000000-0000-4000-8000-000000000002',true);
do $$ begin
 if exists(select 1 from public.teachers) or exists(select 1 from public.teacher_rates) or exists(select 1 from public.classes) or exists(select 1 from public.memberships) then raise exception 'Deactivated teacher retained access';end if;
end $$;
reset role;
select 'PASS: atomic creation, retry deduplication, duplicate constraints, stale-write rejection, dated assignment history, audit, teacher isolation, cross-school isolation and deactivation' as result;
rollback;
