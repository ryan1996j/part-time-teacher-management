-- Disposable capture fixtures. No owner account/class/teacher is changed.
begin;
insert into auth.users(id) values('90000000-0000-4000-8000-000000000001'),('90000000-0000-4000-8000-000000000002'),('90000000-0000-4000-8000-000000000003'),('90000000-0000-4000-8000-000000000004');
insert into public.schools(id,name) values('91000000-0000-4000-8000-000000000001','Capture fixture A'),('91000000-0000-4000-8000-000000000002','Capture fixture B');
insert into public.memberships(school_id,user_id,role) values
 ('91000000-0000-4000-8000-000000000001','90000000-0000-4000-8000-000000000001','teacher'),
 ('91000000-0000-4000-8000-000000000001','90000000-0000-4000-8000-000000000002','teacher'),
 ('91000000-0000-4000-8000-000000000001','90000000-0000-4000-8000-000000000003','admin'),
 ('91000000-0000-4000-8000-000000000002','90000000-0000-4000-8000-000000000004','teacher');
insert into public.teachers(id,school_id,name,email,user_id) values
 ('92000000-0000-4000-8000-000000000001','91000000-0000-4000-8000-000000000001','Capture Teacher A','capture-a@example.com','90000000-0000-4000-8000-000000000001'),
 ('92000000-0000-4000-8000-000000000002','91000000-0000-4000-8000-000000000001','Capture Teacher B','capture-b@example.com','90000000-0000-4000-8000-000000000002'),
 ('92000000-0000-4000-8000-000000000003','91000000-0000-4000-8000-000000000002','Capture Teacher C','capture-c@example.com','90000000-0000-4000-8000-000000000004');
insert into public.classes(id,school_id,name,subject) values
 ('93000000-0000-4000-8000-000000000001','91000000-0000-4000-8000-000000000001','Capture Class','Math'),
 ('93000000-0000-4000-8000-000000000002','91000000-0000-4000-8000-000000000001','Unassigned','English'),
 ('93000000-0000-4000-8000-000000000003','91000000-0000-4000-8000-000000000002','Foreign class','Science');
insert into public.teacher_assignments(id,school_id,teacher_id,class_id,effective_from,reason,created_by) values
 ('94000000-0000-4000-8000-000000000001','91000000-0000-4000-8000-000000000001','92000000-0000-4000-8000-000000000001','93000000-0000-4000-8000-000000000001',now()-interval '3 days','Capture fixture','90000000-0000-4000-8000-000000000003'),
 ('94000000-0000-4000-8000-000000000002','91000000-0000-4000-8000-000000000001','92000000-0000-4000-8000-000000000002','93000000-0000-4000-8000-000000000001',now()-interval '3 days','Capture fixture','90000000-0000-4000-8000-000000000003'),
 ('94000000-0000-4000-8000-000000000003','91000000-0000-4000-8000-000000000002','92000000-0000-4000-8000-000000000003','93000000-0000-4000-8000-000000000003',now()-interval '3 days','Capture fixture','90000000-0000-4000-8000-000000000004');
insert into public.teaching_sessions(id,school_id,teacher_id,class_id,assignment_id,start_at,original_start_at,source,created_by)
 values('95000000-0000-4000-8000-000000000001','91000000-0000-4000-8000-000000000001','92000000-0000-4000-8000-000000000002','93000000-0000-4000-8000-000000000001','94000000-0000-4000-8000-000000000002',now()-interval '2 days',now()-interval '2 days','Teacher check-in','90000000-0000-4000-8000-000000000002');

set local role authenticated;
select set_config('request.jwt.claim.sub','90000000-0000-4000-8000-000000000001',true);
do $$
declare s uuid:='91000000-0000-4000-8000-000000000001';r uuid:=gen_random_uuid();payload jsonb:=jsonb_build_object('class_id','93000000-0000-4000-8000-000000000001','teacher_id','92000000-0000-4000-8000-000000000002','start_at','2040-01-01T00:00:00Z');first_result jsonb;again jsonb;finished jsonb;before_capture timestamptz:=clock_timestamp();
begin
 first_result:=public.capture_teaching_session(s,r,'check_in',payload);
 if (first_result->>'teacher_id')::uuid<>'92000000-0000-4000-8000-000000000001' or (first_result->>'start_at')::timestamptz<before_capture or (first_result->>'start_at')::timestamptz>clock_timestamp() then raise exception 'Capture trusted browser teacher/time';end if;
 again:=public.capture_teaching_session(s,r,'check_in',payload);
 if first_result<>again or (select count(*) from public.session_records)<>1 then raise exception 'Check-in retry duplicated record';end if;
 begin perform public.capture_teaching_session(s,r,'check_in','{"class_id":"93000000-0000-4000-8000-000000000002"}');raise exception 'Changed retry accepted';exception when raise_exception then if SQLERRM='Changed retry accepted' then raise;end if;end;
 begin perform public.capture_teaching_session(s,gen_random_uuid(),'check_in',payload);raise exception 'Second open session accepted';exception when raise_exception then if SQLERRM='Second open session accepted' then raise;end if;end;
 begin perform public.capture_teaching_session(s,gen_random_uuid(),'check_out','{"id":"95000000-0000-4000-8000-000000000001","version":1}');raise exception 'Another teacher checkout accepted';exception when insufficient_privilege then null;end;
 begin update public.teaching_sessions set end_at=clock_timestamp();raise exception 'Direct session update allowed';exception when insufficient_privilege then null;end;
 -- Actor switches are confined to these test JWT settings, never real accounts.
 perform set_config('request.jwt.claim.sub','90000000-0000-4000-8000-000000000003',true);
 begin perform public.manage_master_data(s,gen_random_uuid(),'teacher_status','{"id":"92000000-0000-4000-8000-000000000001","version":1,"active":false,"reason":"Open-session guard test"}');raise exception 'Teacher deactivated with open record';exception when raise_exception then if SQLERRM='Teacher deactivated with open record' then raise;end if;end;
 begin perform public.manage_master_data(s,gen_random_uuid(),'class_status','{"id":"93000000-0000-4000-8000-000000000001","version":1,"active":false,"reason":"Open-session guard test"}');raise exception 'Class deactivated with open record';exception when raise_exception then if SQLERRM='Class deactivated with open record' then raise;end if;end;
 perform set_config('request.jwt.claim.sub','90000000-0000-4000-8000-000000000001',true);
 begin perform public.capture_teaching_session(s,gen_random_uuid(),'check_out',jsonb_build_object('id',first_result->>'id','version',99));raise exception 'Stale checkout accepted';exception when serialization_failure then null;end;
 payload:=jsonb_build_object('id',first_result->>'id','version',first_result->'version','end_at','2040-01-01T00:00:00Z');r:=gen_random_uuid();
 finished:=public.capture_teaching_session(s,r,'check_out',payload);
 again:=public.capture_teaching_session(s,r,'check_out',payload);
 if finished<>again or (finished->>'end_at')::timestamptz>clock_timestamp() or finished->>'end_at'<>finished->>'original_end_at' or finished->>'verification'<>'Pending' then raise exception 'Checkout timestamp/retry/original mismatch';end if;
 again:=public.capture_teaching_session(s,gen_random_uuid(),'check_out',payload);
 if finished->>'end_at'<>again->>'end_at' or (select count(*) from public.session_events where action='check_out')<>1 then raise exception 'Repeated checkout changed the end time';end if;
 begin perform public.capture_teaching_session(s,gen_random_uuid(),'check_in','{"class_id":"93000000-0000-4000-8000-000000000002"}');raise exception 'Unassigned class accepted';exception when raise_exception then if SQLERRM='Unassigned class accepted' then raise;end if;end;
end $$;

select set_config('request.jwt.claim.sub','90000000-0000-4000-8000-000000000003',true);
do $$
declare s uuid:='91000000-0000-4000-8000-000000000001';payload jsonb;first_result jsonb;other jsonb;long_record jsonb;
begin
 payload:=jsonb_build_object('teacher_id','92000000-0000-4000-8000-000000000001','class_id','93000000-0000-4000-8000-000000000001','start_at',now()-interval '3 hours','end_at',now()-interval '2 hours','reason','Fixture completed class');
 first_result:=public.capture_teaching_session(s,gen_random_uuid(),'admin_entry',payload);
 if first_result->>'verification'<>'Pending' or (first_result->>'minutes')::integer<>60 then raise exception 'Admin entry status/duration mismatch';end if;
 begin perform public.capture_teaching_session(s,gen_random_uuid(),'admin_entry',payload);raise exception 'Duplicate completed entry accepted';exception when unique_violation then null;end;
 other:=public.capture_teaching_session(s,gen_random_uuid(),'admin_entry',payload||jsonb_build_object('start_at',now()-interval '150 minutes','end_at',now()-interval '90 minutes'));
 if not(other->>'overlap_flag')::boolean or not(select overlap_flag from public.teaching_sessions where id=(first_result->>'id')::uuid) then raise exception 'Overlap was not flagged on both records';end if;
 long_record:=public.capture_teaching_session(s,gen_random_uuid(),'admin_entry',payload||jsonb_build_object('start_at',now()-interval '12 hours','end_at',now()-interval '4 hours'));
 if (long_record->>'overlap_flag')::boolean then raise exception 'Unapproved long-duration threshold was applied';end if;
 begin perform public.capture_teaching_session(s,gen_random_uuid(),'admin_entry',payload||jsonb_build_object('start_at',now()+interval '1 hour','end_at',now()+interval '2 hours'));raise exception 'Future completed class accepted';exception when raise_exception then if SQLERRM='Future completed class accepted' then raise;end if;end;
 begin perform public.capture_teaching_session('91000000-0000-4000-8000-000000000002',gen_random_uuid(),'admin_entry',payload);raise exception 'Foreign school mutation accepted';exception when insufficient_privilege then null;end;
end $$;

select set_config('request.jwt.claim.sub','90000000-0000-4000-8000-000000000002',true);
do $$ declare result jsonb;begin
 if (select record_status from public.session_records where id='95000000-0000-4000-8000-000000000001')<>'Missing checkout' or exists(select 1 from public.session_records where end_at is not null) then raise exception 'Missing checkout was auto-completed or another teacher data leaked';end if;
 result:=public.capture_teaching_session('91000000-0000-4000-8000-000000000001',gen_random_uuid(),'check_out','{"id":"95000000-0000-4000-8000-000000000001","version":1}');
 if result->>'end_at' is null then raise exception 'Explicit overnight checkout failed';end if;
end $$;
select set_config('request.jwt.claim.sub','90000000-0000-4000-8000-000000000004',true);
do $$ begin if exists(select 1 from public.session_records) then raise exception 'Cross-school records leaked';end if;end $$;
reset role;
do $$ begin
 begin update public.teaching_sessions set original_start_at=original_start_at-interval '1 minute' where teacher_id='92000000-0000-4000-8000-000000000001';raise exception 'Original time mutated';exception when raise_exception then if SQLERRM='Original time mutated' then raise;end if;end;
end $$;
update public.memberships set active=false where user_id='90000000-0000-4000-8000-000000000001';
set local role authenticated;
select set_config('request.jwt.claim.sub','90000000-0000-4000-8000-000000000001',true);
do $$ begin
 if exists(select 1 from public.session_records) then raise exception 'Inactive account read sessions';end if;
 begin perform public.capture_teaching_session('91000000-0000-4000-8000-000000000001',gen_random_uuid(),'check_in','{"class_id":"93000000-0000-4000-8000-000000000001"}');raise exception 'Inactive account captured time';exception when insufficient_privilege then null;end;
end $$;
reset role;
select 'PASS: server timestamps, own-account capture, retries, one open record, stale checkout, immutable originals, assignment checks, admin entries, overlaps, missing/overnight checkout, deactivation guards, tenant isolation and inactive denial' as result;
rollback;
