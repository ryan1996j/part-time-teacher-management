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
 s jsonb;d jsonb;other_run jsonb;payload jsonb;key uuid;again jsonb;withdraw_id uuid;
begin
 s:=public.capture_teaching_session(school,gen_random_uuid(),'admin_entry',jsonb_build_object('teacher_id','92000000-0000-4000-8000-000000000001','class_id','93000000-0000-4000-8000-000000000001','start_at',day||'T09:00:00+06:30','end_at',day||'T09:50:00+06:30','reason','Approval fixture'));
 s:=public.review_teaching_session(school,gen_random_uuid(),'verify_session',jsonb_build_object('id',s->>'id','version',s->'version','decision','Verified'));
 perform set_config('test.approval_session',s->>'id',true);
 s:=public.capture_teaching_session(school,gen_random_uuid(),'admin_entry',jsonb_build_object('teacher_id','92000000-0000-4000-8000-000000000001','class_id','93000000-0000-4000-8000-000000000001','start_at',day||'T10:00:00+06:30','end_at',day||'T10:01:00+06:30','reason','Approval fixture second'));
 perform public.review_teaching_session(school,gen_random_uuid(),'verify_session',jsonb_build_object('id',s->>'id','version',s->'version','decision','Verified'));
 payload:=jsonb_build_object('period_start',day,'period_end',day);
 d:=public.calculate_payroll_draft(school,gen_random_uuid(),payload);
 other_run:=public.calculate_payroll_draft(school,gen_random_uuid(),payload);
 if d->'snapshot'->>'net_mmk'<>'8500' then raise exception 'Initial exact net mismatch';end if;
 payload:=jsonb_build_object('id',d->>'id','version',1,'teacher_id','92000000-0000-4000-8000-000000000001','amount','1000','reason','Documented bonus','reference','Fixture reference');key:=gen_random_uuid();
 d:=public.manage_payroll_approval(school,key,'add_adjustment',payload);again:=public.manage_payroll_approval(school,key,'add_adjustment',payload);
 if d<>again or jsonb_array_length(d->'snapshot'->'adjustments')<>1 or d->'snapshot'->>'net_mmk'<>'9500' then raise exception 'Adjustment retry or exact net failed';end if;
 begin perform public.manage_payroll_approval(school,key,'add_adjustment',payload||'{"amount":"1001"}');raise exception 'Changed adjustment retry accepted';exception when raise_exception then if SQLERRM<>'Request key conflict' then raise;end if;end;
 begin perform public.manage_payroll_approval(school,gen_random_uuid(),'approve',jsonb_build_object('id',d->>'id','version',1));raise exception 'Stale approval version accepted';exception when serialization_failure then null;end;
 begin perform public.manage_payroll_approval(school,gen_random_uuid(),'add_adjustment',payload||jsonb_build_object('version',2,'reason',''));raise exception 'Blank adjustment reason accepted';exception when raise_exception then if SQLERRM<>'Enter a non-zero whole MMK adjustment and reason' then raise;end if;end;
 d:=public.manage_payroll_approval(school,gen_random_uuid(),'add_adjustment',payload||'{"version":2,"amount":"-500","reason":"Documented deduction"}');
 if d->'snapshot'->>'net_mmk'<>'9000' then raise exception 'Signed net mismatch';end if;
 d:=public.manage_payroll_approval(school,gen_random_uuid(),'add_adjustment',payload||'{"version":3,"amount":"-10000","reason":"Negative net fixture"}');
 select (x->>'id')::uuid into withdraw_id from jsonb_array_elements(d->'snapshot'->'adjustments') x where x->>'amount_mmk'='-10000';
 begin perform public.manage_payroll_approval(school,gen_random_uuid(),'approve',jsonb_build_object('id',d->>'id','version',4));raise exception 'Negative net approved';exception when raise_exception then if SQLERRM<>'A teacher net amount is negative. Review adjustments before approval' then raise;end if;end;
 d:=public.manage_payroll_approval(school,gen_random_uuid(),'withdraw_adjustment',jsonb_build_object('id',d->>'id','version',4,'adjustment_id',withdraw_id,'reason','Remove negative fixture'));
 if d->'snapshot'->>'net_mmk'<>'9000' then raise exception 'Withdrawal failed';end if;
 d:=public.manage_payroll_approval(school,gen_random_uuid(),'add_adjustment',payload||'{"version":5,"teacher_id":"92000000-0000-4000-8000-000000000002","amount":"-1","reason":"Negative teacher with positive school total"}');
 select (x->>'id')::uuid into withdraw_id from jsonb_array_elements(d->'snapshot'->'adjustments') x where x->>'amount_mmk'='-1';
 begin perform public.manage_payroll_approval(school,gen_random_uuid(),'approve',jsonb_build_object('id',d->>'id','version',6));raise exception 'Negative teacher hidden by positive school net';exception when raise_exception then if SQLERRM<>'A teacher net amount is negative. Review adjustments before approval' then raise;end if;end;
 d:=public.manage_payroll_approval(school,gen_random_uuid(),'withdraw_adjustment',jsonb_build_object('id',d->>'id','version',6,'adjustment_id',withdraw_id,'reason','Remove cross-teacher fixture'));
 if jsonb_array_length(d->'snapshot'->'teachers')<>1 then raise exception 'Withdrawn-only teacher retained in totals';end if;
 key:=gen_random_uuid();payload:=jsonb_build_object('id',d->>'id','version',7,'reason','Fixture approval after review');
 d:=public.manage_payroll_approval(school,key,'approve',payload);again:=public.manage_payroll_approval(school,key,'approve',payload);
 if d<>again or d->>'status'<>'Approved' or d->>'approved_at' is null or d->'snapshot'->>'net_mmk'<>'9000' or (select count(*) from public.payroll_allocations)<>2 then raise exception 'Approval atomicity/snapshot/retry/allocation failed';end if;
 perform set_config('test.approved_run',d->>'id',true);perform set_config('test.approved_snapshot',(d->'snapshot')::text,true);
 begin perform public.calculate_payroll_draft(school,gen_random_uuid(),jsonb_build_object('id',d->>'id','version',8,'period_start',day,'period_end',day));raise exception 'Approved run recalculated';exception when raise_exception then if SQLERRM<>'Approved payroll is immutable' then raise;end if;end;
 begin perform public.manage_payroll_approval(school,gen_random_uuid(),'add_adjustment',jsonb_build_object('id',d->>'id','version',8,'teacher_id','92000000-0000-4000-8000-000000000001','amount','1','reason','Try changing approved pay'));raise exception 'Approved adjustment changed';exception when raise_exception then if SQLERRM<>'Approved payroll is immutable' then raise;end if;end;
 if not (public.payroll_draft_state(school,(other_run->>'id')::uuid)->>'stale')::boolean then raise exception 'Competing draft not stale';end if;
 begin perform public.manage_payroll_approval(school,gen_random_uuid(),'approve',jsonb_build_object('id',other_run->>'id','version',1));raise exception 'Duplicate allocation approved';exception when serialization_failure then null;end;
 other_run:=public.calculate_payroll_draft(school,gen_random_uuid(),jsonb_build_object('id',other_run->>'id','version',1,'period_start',day,'period_end',day));
 if other_run->'snapshot'->>'net_mmk'<>'0' or (other_run->'snapshot'->>'held_count')::int<>2 or not exists(select 1 from jsonb_array_elements(other_run->'snapshot'->'lines') x where x->'reasons' ? 'Already allocated to approved payroll') then raise exception 'Already allocated session included';end if;
 begin perform public.manage_payroll_approval(school,gen_random_uuid(),'approve',jsonb_build_object('id',other_run->>'id','version',2));raise exception 'Empty payroll approved';exception when raise_exception then if SQLERRM<>'There are no eligible sessions or adjustments to approve' then raise;end if;end;
 begin perform public.review_teaching_session(school,gen_random_uuid(),'request_correction',jsonb_build_object('id',current_setting('test.approval_session'),'version',2,'start_at',day||'T09:01:00+06:30','end_at',day||'T09:50:00+06:30','reason','Try changing approved attendance'));raise exception 'Locked correction accepted';exception when raise_exception then if SQLERRM<>'This class record is locked by approved payroll' then raise;end if;end;
 begin perform public.review_teaching_session(school,gen_random_uuid(),'verify_session',jsonb_build_object('id',current_setting('test.approval_session'),'version',2,'decision','Rejected','reason','Try changing approved review'));raise exception 'Locked session review accepted';exception when raise_exception then if SQLERRM<>'This class record is locked by approved payroll' then raise;end if;end;
 begin perform public.capture_teaching_session(school,gen_random_uuid(),'admin_entry',jsonb_build_object('teacher_id','92000000-0000-4000-8000-000000000001','class_id','93000000-0000-4000-8000-000000000001','start_at',day||'T09:10:00+06:30','end_at',day||'T09:20:00+06:30','reason','Try overlapping locked record'));raise exception 'Locked overlap accepted';exception when raise_exception then if SQLERRM<>'This class record is locked by approved payroll' then raise;end if;end;
 if (select count(*) from public.session_records where teacher_id='92000000-0000-4000-8000-000000000001')<>2 then raise exception 'Failed capture left partial attendance';end if;
 begin update public.payroll_adjustments set amount_mmk=999;raise exception 'Direct adjustment write allowed';exception when insufficient_privilege then null;end;
 perform set_config('request.jwt.claim.sub','90000000-0000-4000-8000-000000000001',true);
 if exists(select 1 from public.payroll_drafts) or exists(select 1 from public.payroll_adjustments) then raise exception 'Teacher read school financial data';end if;
 if not (select payroll_locked from public.session_records where id=current_setting('test.approval_session')::uuid) then raise exception 'Teacher cannot see own lock';end if;
 begin perform public.manage_payroll_approval(school,gen_random_uuid(),'approve',payload);raise exception 'Teacher approved payroll';exception when insufficient_privilege then null;end;
 perform set_config('request.jwt.claim.sub','90000000-0000-4000-8000-000000000004',true);
 if exists(select 1 from public.payroll_allocations) then raise exception 'Foreign allocation leaked';end if;
 begin perform public.manage_payroll_approval(school,gen_random_uuid(),'approve',payload);raise exception 'Foreign school approved';exception when insufficient_privilege then null;end;
end $$;
reset role;
-- Trusted-writer backstops also preserve approved history.
do $$ begin
 begin update public.payroll_drafts set snapshot='{}' where id=current_setting('test.approved_run')::uuid;raise exception 'Approved snapshot overwritten';exception when raise_exception then if SQLERRM<>'Approved payroll is immutable' then raise;end if;end;
 begin update public.payroll_adjustments set amount_mmk=999 where draft_id=current_setting('test.approved_run')::uuid;raise exception 'Approved ledger overwritten';exception when raise_exception then if SQLERRM<>'Approved payroll is immutable' then raise;end if;end;
 begin delete from public.payroll_allocations where draft_id=current_setting('test.approved_run')::uuid;raise exception 'Approved allocation removed';exception when raise_exception then if SQLERRM<>'Approved allocation history is immutable' then raise;end if;end;
 begin update public.teacher_assignments set effective_to=((clock_timestamp() at time zone 'Asia/Yangon')::date-1||'T08:00:00+06:30')::timestamptz where id='94000000-0000-4000-8000-000000000001';raise exception 'Approved assignment history invalidated';exception when raise_exception then if SQLERRM<>'Assignment change would invalidate approved payroll history' then raise;end if;end;
 begin delete from public.payroll_draft_events where draft_id=current_setting('test.approved_run')::uuid;raise exception 'Financial audit deleted';exception when raise_exception then if SQLERRM<>'Payroll audit history is append-only' then raise;end if;end;
end $$;
insert into public.teacher_rates(school_id,teacher_id,effective_from,hourly_mmk,reason,created_by)
 values('91000000-0000-4000-8000-000000000001','92000000-0000-4000-8000-000000000001',(clock_timestamp() at time zone 'Asia/Yangon')::date-1,12000,'New rate after payroll approval','90000000-0000-4000-8000-000000000003');
set local role authenticated;
select set_config('request.jwt.claim.sub','90000000-0000-4000-8000-000000000003',true);
do $$ declare state jsonb;begin
 state:=public.payroll_draft_state('91000000-0000-4000-8000-000000000001',current_setting('test.approved_run')::uuid);
 if state->'draft'->'snapshot'<>current_setting('test.approved_snapshot')::jsonb or (state->>'stale')::boolean then raise exception 'New rates changed approved pay';end if;
end $$;
reset role;
do $$ begin
 if has_function_privilege('anon','public.manage_payroll_approval(uuid,uuid,text,jsonb)','execute') then raise exception 'Anonymous approval exposed';end if;
 if (select count(*) from public.payroll_draft_events where school_id='91000000-0000-4000-8000-000000000001' and action='approve')<>1 or (select count(*) from public.payroll_adjustments where school_id='91000000-0000-4000-8000-000000000001' and not active)<>2 then raise exception 'Approval retry/audit/withdrawal history mismatch';end if;
end $$;
select 'PASS: signed adjustments, required reason, retry/version checks, negative run and per-teacher net denial, soft withdrawal audit, exact approval snapshot, one allocation per session, competing draft invalidation, immutable approved pay after rate change, session/correction/assignment locks, atomic overlap rollback, audit preservation, role/tenant/anonymous denial' as result;
rollback;
