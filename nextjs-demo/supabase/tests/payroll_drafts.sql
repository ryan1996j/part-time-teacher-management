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

-- All objects here are disposable fixtures, rolled back at the end.
insert into public.teacher_rates(school_id,teacher_id,effective_from,hourly_mmk,reason,created_by)
 values('91000000-0000-4000-8000-000000000001','92000000-0000-4000-8000-000000000001',current_date-3,10000,'Draft fixture','90000000-0000-4000-8000-000000000003');
set local role authenticated;
select set_config('request.jwt.claim.sub','90000000-0000-4000-8000-000000000003',true);
do $$
declare school uuid:='91000000-0000-4000-8000-000000000001';day date:=(clock_timestamp() at time zone 'Asia/Yangon')::date-1;
 s jsonb;d jsonb;again jsonb;payload jsonb;key uuid:=gen_random_uuid();
begin
 s:=public.capture_teaching_session(school,gen_random_uuid(),'admin_entry',jsonb_build_object('teacher_id','92000000-0000-4000-8000-000000000001','class_id','93000000-0000-4000-8000-000000000001','start_at',day||'T09:00:00+06:30','end_at',day||'T09:50:00+06:30','reason','50-minute fixture'));
 s:=public.review_teaching_session(school,gen_random_uuid(),'verify_session',jsonb_build_object('id',s->>'id','version',s->'version','decision','Verified'));
 perform set_config('test.payroll_first',s->>'id',true);
 s:=public.capture_teaching_session(school,gen_random_uuid(),'admin_entry',jsonb_build_object('teacher_id','92000000-0000-4000-8000-000000000001','class_id','93000000-0000-4000-8000-000000000001','start_at',day||'T10:00:00+06:30','end_at',day||'T10:01:00+06:30','reason','One-minute fixture'));
 perform public.review_teaching_session(school,gen_random_uuid(),'verify_session',jsonb_build_object('id',s->>'id','version',s->'version','decision','Verified'));
 payload:=jsonb_build_object('period_start',day,'period_end',day,'gross_mmk','999999999999');
 d:=public.calculate_payroll_draft(school,key,payload);again:=public.calculate_payroll_draft(school,key,payload);
 if d<>again or (select count(*) from public.payroll_drafts)<>1 then raise exception 'Draft retry duplicated';end if;
 if d->'snapshot'->>'gross_mmk'<>'8500' or (d->'snapshot'->>'minutes')::int<>51 or (d->'snapshot'->>'included_count')::int<>2 then raise exception 'Per-session 50+1 rounding or client amount trust failed';end if;
 if not exists(select 1 from jsonb_array_elements(d->'snapshot'->'lines') x where x->>'amount_mmk'='8333') or not exists(select 1 from jsonb_array_elements(d->'snapshot'->'lines') x where x->>'amount_mmk'='167') then raise exception 'Per-line rounding mismatch';end if;
 if (public.payroll_draft_state(school,(d->>'id')::uuid)->>'stale')::boolean then raise exception 'Unchanged draft marked stale';end if;
 begin perform public.calculate_payroll_draft(school,key,payload||'{"extra":"changed"}');raise exception 'Changed request accepted';exception when raise_exception then if SQLERRM='Changed request accepted' then raise;end if;end;
 begin perform public.calculate_payroll_draft(school,gen_random_uuid(),payload||jsonb_build_object('id',d->>'id','version',99));raise exception 'Stale draft version accepted';exception when serialization_failure then null;end;
 perform set_config('test.payroll_draft',d->>'id',true);
 begin update public.payroll_drafts set version=999;raise exception 'Direct draft update allowed';exception when insufficient_privilege then null;end;
 begin perform public.calculate_payroll_draft(school,gen_random_uuid(),jsonb_build_object('period_start',day,'period_end',day-1));raise exception 'Reversed period accepted';exception when raise_exception then if SQLERRM='Reversed period accepted' then raise;end if;end;
end $$;
reset role;
insert into public.teacher_rates(school_id,teacher_id,effective_from,hourly_mmk,reason,created_by)
 values('91000000-0000-4000-8000-000000000001','92000000-0000-4000-8000-000000000001',(clock_timestamp() at time zone 'Asia/Yangon')::date-1,12000,'Changed applicable rate','90000000-0000-4000-8000-000000000003');
set local role authenticated;
select set_config('request.jwt.claim.sub','90000000-0000-4000-8000-000000000003',true);
do $$
declare school uuid:='91000000-0000-4000-8000-000000000001';day date:=(clock_timestamp() at time zone 'Asia/Yangon')::date-1;
 state jsonb;d jsonb;s jsonb;payload jsonb;
begin
 state:=public.payroll_draft_state(school,current_setting('test.payroll_draft')::uuid);
 if not (state->>'stale')::boolean or state->'draft'->'snapshot'->>'gross_mmk'<>'8500' then raise exception 'Rate change silently rewrote snapshot or did not mark stale';end if;
 payload:=jsonb_build_object('id',current_setting('test.payroll_draft'),'version',1,'period_start',day,'period_end',day);
 d:=public.calculate_payroll_draft(school,gen_random_uuid(),payload);
 if d->'snapshot'->>'gross_mmk'<>'10200' or (d->>'version')::int<>2 then raise exception 'Rate recalculation failed';end if;
 perform set_config('request.jwt.claim.sub','90000000-0000-4000-8000-000000000001',true);
 perform public.review_teaching_session(school,gen_random_uuid(),'request_correction',jsonb_build_object('id',current_setting('test.payroll_first'),'version',2,'start_at',day||'T09:01:00+06:30','end_at',day||'T09:50:00+06:30','reason','Pending correction fixture'));
 if exists(select 1 from public.payroll_drafts) then raise exception 'Teacher read draft';end if;
 if exists(select 1 from public.payroll_draft_events) then raise exception 'Teacher read financial audit';end if;
 begin perform public.payroll_draft_state(school,(d->>'id')::uuid);raise exception 'Teacher read draft RPC';exception when insufficient_privilege then null;end;
 begin perform public.calculate_payroll_draft(school,gen_random_uuid(),payload);raise exception 'Teacher calculated draft';exception when insufficient_privilege then null;end;
 perform set_config('request.jwt.claim.sub','90000000-0000-4000-8000-000000000003',true);
 if not (public.payroll_draft_state(school,(d->>'id')::uuid)->>'stale')::boolean then raise exception 'Pending correction did not mark stale';end if;
 d:=public.calculate_payroll_draft(school,gen_random_uuid(),payload||'{"version":2}');
 if d->'snapshot'->>'gross_mmk'<>'200' or (d->'snapshot'->>'held_count')::int<>1 then raise exception 'Pending correction included in payroll';end if;
 -- Missing rate / unverified / overlap stays held, never a guessed zero rate.
 perform public.capture_teaching_session(school,gen_random_uuid(),'admin_entry',jsonb_build_object('teacher_id','92000000-0000-4000-8000-000000000002','class_id','93000000-0000-4000-8000-000000000001','start_at',day||'T13:00:00+06:30','end_at',day||'T14:00:00+06:30','reason','No rate fixture'));
 d:=public.calculate_payroll_draft(school,gen_random_uuid(),payload||'{"version":3}');
 if (d->'snapshot'->>'held_count')::int<>2 or not exists(select 1 from jsonb_array_elements(d->'snapshot'->'lines') x where x->'reasons' ? 'No applicable hourly rate') then raise exception 'Missing rate not held';end if;
 -- The 65-minute example must calculate exactly 13,000 MMK at 12,000/hour.
 s:=public.capture_teaching_session(school,gen_random_uuid(),'admin_entry',jsonb_build_object('teacher_id','92000000-0000-4000-8000-000000000001','class_id','93000000-0000-4000-8000-000000000001','start_at',day||'T13:00:00+06:30','end_at',day||'T14:05:00+06:30','reason','65-minute fixture'));
 perform public.review_teaching_session(school,gen_random_uuid(),'verify_session',jsonb_build_object('id',s->>'id','version',s->'version','decision','Verified'));
 if not (public.payroll_draft_state(school,(d->>'id')::uuid)->>'stale')::boolean then raise exception 'New session not stale';end if;
 d:=public.calculate_payroll_draft(school,gen_random_uuid(),payload||'{"version":4}');
 if d->'snapshot'->>'gross_mmk'<>'13200' or not exists(select 1 from jsonb_array_elements(d->'snapshot'->'lines') x where x->>'amount_mmk'='13000') then raise exception '65-minute calculation mismatch';end if;
 -- Overnight time belongs wholly to its Myanmar start day.
 s:=public.capture_teaching_session(school,gen_random_uuid(),'admin_entry',jsonb_build_object('teacher_id','92000000-0000-4000-8000-000000000001','class_id','93000000-0000-4000-8000-000000000001','start_at',day||'T23:30:00+06:30','end_at',(day+1)||'T00:30:00+06:30','reason','Overnight fixture'));
 perform public.review_teaching_session(school,gen_random_uuid(),'verify_session',jsonb_build_object('id',s->>'id','version',s->'version','decision','Verified'));
 s:=public.calculate_payroll_draft(school,gen_random_uuid(),jsonb_build_object('period_start',day,'period_end',day));
 if s->'snapshot'->>'gross_mmk'<>'25200' or (s->'snapshot'->>'minutes')::int<>126 then raise exception 'Overnight start-date period or complete duration failed';end if;
 s:=public.calculate_payroll_draft(school,gen_random_uuid(),jsonb_build_object('period_start',day+1,'period_end',day+1));
 if s->'snapshot'->>'gross_mmk'<>'0' or (s->'snapshot'->>'included_count')::int<>0 then raise exception 'Empty period did not return zero';end if;
 s:=public.calculate_payroll_draft(school,gen_random_uuid(),jsonb_build_object('period_start',day-1,'period_end',day-1));
 if (s->'snapshot'->>'held_count')::int<>1 or not exists(select 1 from jsonb_array_elements(s->'snapshot'->'lines') x where x->'reasons' ? 'Missing checkout') then raise exception 'Missing checkout not held';end if;
 perform set_config('request.jwt.claim.sub','90000000-0000-4000-8000-000000000004',true);
 if exists(select 1 from public.payroll_drafts) then raise exception 'Foreign school draft leaked';end if;
 begin perform public.payroll_draft_state(school,(d->>'id')::uuid);raise exception 'Foreign school RPC allowed';exception when insufficient_privilege then null;end;
end $$;
reset role;
update public.teachers set active=false where id='92000000-0000-4000-8000-000000000001';
set local role authenticated;
select set_config('request.jwt.claim.sub','90000000-0000-4000-8000-000000000003',true);
do $$ declare result jsonb;day date:=(clock_timestamp() at time zone 'Asia/Yangon')::date-1;begin
 result:=public.calculate_payroll_draft('91000000-0000-4000-8000-000000000001',gen_random_uuid(),jsonb_build_object('period_start',day,'period_end',day));
 if result->'snapshot'->>'gross_mmk'<>'25200' then raise exception 'Inactive teacher historical sessions were lost';end if;
end $$;
reset role;
do $$ begin
 if has_function_privilege('anon','public.calculate_payroll_draft(uuid,uuid,jsonb)','execute') or has_function_privilege('anon','public.payroll_draft_state(uuid,uuid)','execute') then raise exception 'Anonymous payroll access';end if;
 if (select count(*) from public.payroll_draft_events where school_id='91000000-0000-4000-8000-000000000001' and action='recalculate')<>4 then raise exception 'Draft audit missing';end if;
end $$;
select 'PASS: exact per-session decimal rounding, applicable rate version, immutable saved snapshot/staleness, pending correction and missing-rate holds, empty period, overnight/start-date bounds, missing checkout, inactive teacher history, new-source detection, retries/conflicts, versions, audit, Teacher/cross-school/anonymous/direct-write denial' as result;
rollback;
