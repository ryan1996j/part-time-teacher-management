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
insert into public.teacher_rates(school_id,teacher_id,effective_from,hourly_mmk,reason,created_by)
 values('91000000-0000-4000-8000-000000000001','92000000-0000-4000-8000-000000000002',current_date-3,12000,'Payment fixture B rate','90000000-0000-4000-8000-000000000003');
insert into public.teachers(id,school_id,name,email) values('92000000-0000-4000-8000-000000000005','91000000-0000-4000-8000-000000000001','Held-only Teacher','held-only@example.com');
insert into public.teacher_assignments(id,school_id,teacher_id,class_id,effective_from,reason,created_by)
 values('94000000-0000-4000-8000-000000000005','91000000-0000-4000-8000-000000000001','92000000-0000-4000-8000-000000000005','93000000-0000-4000-8000-000000000001',now()-interval '3 days','Held-only fixture','90000000-0000-4000-8000-000000000003');
set local role authenticated;
select set_config('request.jwt.claim.sub','90000000-0000-4000-8000-000000000003',true);
do $$
declare school uuid:='91000000-0000-4000-8000-000000000001';day date:=(clock_timestamp() at time zone 'Asia/Yangon')::date;
 s jsonb;run jsonb;draft jsonb;list jsonb;detail jsonb;pay jsonb;again jsonb;payload jsonb;key uuid:=gen_random_uuid();
begin
 s:=public.capture_teaching_session(school,gen_random_uuid(),'admin_entry',jsonb_build_object('teacher_id','92000000-0000-4000-8000-000000000001','class_id','93000000-0000-4000-8000-000000000001','start_at',(day-1)||'T09:00:00+06:30','end_at',(day-1)||'T10:00:00+06:30','reason','Payment fixture A'));
 perform public.review_teaching_session(school,gen_random_uuid(),'verify_session',jsonb_build_object('id',s->>'id','version',s->'version','decision','Verified'));
 s:=public.capture_teaching_session(school,gen_random_uuid(),'admin_entry',jsonb_build_object('teacher_id','92000000-0000-4000-8000-000000000002','class_id','93000000-0000-4000-8000-000000000001','start_at',(day-1)||'T11:00:00+06:30','end_at',(day-1)||'T11:30:00+06:30','reason','Payment fixture B'));
 perform public.review_teaching_session(school,gen_random_uuid(),'verify_session',jsonb_build_object('id',s->>'id','version',s->'version','decision','Verified','reason','Fixture overlap reviewed'));
 perform public.capture_teaching_session(school,gen_random_uuid(),'admin_entry',jsonb_build_object('teacher_id','92000000-0000-4000-8000-000000000005','class_id','93000000-0000-4000-8000-000000000001','start_at',(day-1)||'T12:00:00+06:30','end_at',(day-1)||'T13:00:00+06:30','reason','Held-only teacher fixture'));
 run:=public.calculate_payroll_draft(school,gen_random_uuid(),jsonb_build_object('period_start',day-1,'period_end',day-1));
 run:=public.manage_payroll_approval(school,gen_random_uuid(),'add_adjustment',jsonb_build_object('id',run->>'id','version',1,'teacher_id','92000000-0000-4000-8000-000000000001','amount','1000','reason','Prior-period adjustment fixture','reference','Own teacher reference'));
 run:=public.manage_payroll_approval(school,gen_random_uuid(),'approve',jsonb_build_object('id',run->>'id','version',2,'reason','Payment fixture approved'));
 perform set_config('test.payment_run',run->>'id',true);perform set_config('test.payment_snapshot',(run->'snapshot')::text,true);
 list:=public.read_teacher_payments(school);
 if (list->>'total')::int<>2 or exists(select 1 from jsonb_array_elements(list->'records') x where x->>'teacher_id'='92000000-0000-4000-8000-000000000005') then raise exception 'Held-only teacher exposed as approved payee';end if;
 if exists(select 1 from jsonb_array_elements(list->'records') x where x->>'payment_status'<>'Not paid') then raise exception 'Approval automatically marked Paid';end if;
 payload:=jsonb_build_object('run_id',run->>'id','version',3,'teacher_id','92000000-0000-4000-8000-000000000001','paid_date',day,'method','Cash','reference','Fixture cash receipt','amount_mmk','1');
 begin perform public.record_teacher_payment(school,gen_random_uuid(),payload||'{"version":2}');raise exception 'Wrong approved version accepted';exception when serialization_failure then null;end;
 begin perform public.record_teacher_payment(school,gen_random_uuid(),payload||jsonb_build_object('paid_date',day+1));raise exception 'Future payment accepted';exception when raise_exception then if SQLERRM<>'Paid date cannot be in the future' then raise;end if;end;
 begin perform public.record_teacher_payment(school,gen_random_uuid(),payload||'{"reference":""}');raise exception 'Blank receipt accepted';exception when raise_exception then if SQLERRM<>'Enter a valid paid date, method and reference or receipt note' then raise;end if;end;
 begin perform public.record_teacher_payment(school,gen_random_uuid(),payload||'{"teacher_id":"92000000-0000-4000-8000-000000000005"}');raise exception 'Held-only payment accepted';exception when raise_exception then if SQLERRM<>'Teacher has no included sessions or adjustments in this approved payroll' then raise;end if;end;
 draft:=public.calculate_payroll_draft(school,gen_random_uuid(),jsonb_build_object('period_start',day,'period_end',day));
 begin perform public.record_teacher_payment(school,gen_random_uuid(),payload||jsonb_build_object('run_id',draft->>'id','version',1));raise exception 'Draft payment accepted';exception when raise_exception then if SQLERRM<>'An approved payroll is required' then raise;end if;end;
 pay:=public.record_teacher_payment(school,key,payload);again:=public.record_teacher_payment(school,key,payload);
 if pay<>again or pay->>'amount_mmk'<>'11000' or pay->>'recorded_by'<>'90000000-0000-4000-8000-000000000003' or (select count(*) from public.teacher_payments)<>1 then raise exception 'Server amount/actor/retry/duplicate failed';end if;
 begin perform public.record_teacher_payment(school,key,payload||'{"reference":"changed"}');raise exception 'Changed payment key reused';exception when raise_exception then if SQLERRM<>'Request key conflict' then raise;end if;end;
 begin perform public.record_teacher_payment(school,gen_random_uuid(),payload);raise exception 'Duplicate payment recorded';exception when raise_exception then if SQLERRM<>'Payment is already recorded. Refresh the payment list.' then raise;end if;end;
 list:=public.read_teacher_payments(school,1,'Paid');if (list->>'total')::int<>1 or (list->'records'->0->>'paid_count')::int<>1 or (list->'records'->0->>'teacher_count')::int<>2 then raise exception 'Partial run paid count failed';end if;
 if (public.read_teacher_payments(school,1,'Not paid')->>'total')::int<>1 then raise exception 'Unpaid teacher lost';end if;
 perform set_config('request.jwt.claim.sub','90000000-0000-4000-8000-000000000001',true);
 list:=public.read_teacher_payments(school);
 detail:=public.teacher_payment_detail(school,(run->>'id')::uuid,'92000000-0000-4000-8000-000000000001');
 if (list->>'total')::int<>1 or list->'records'->0->>'net_mmk'<>'11000' or (list->'records'->0) ? 'paid_count' or (detail->'summary') ? 'teacher_count' then raise exception 'Teacher summary/aggregate privacy failed';end if;
 if jsonb_array_length(detail->'lines')<>1 or jsonb_array_length(detail->'adjustments')<>1 or detail->'adjustments'->0->>'reason'<>'Prior-period adjustment fixture' or position('92000000-0000-4000-8000-000000000002' in detail::text)>0 then raise exception 'Teacher own breakdown leaked another teacher';end if;
 if exists(select 1 from public.payroll_drafts) or (select count(*) from public.teacher_payments)<>1 then raise exception 'Teacher raw finance RLS failed';end if;
 begin perform public.read_teacher_payments(school,1,'','92000000-0000-4000-8000-000000000002');raise exception 'Forged teacher list accepted';exception when insufficient_privilege then null;end;
 begin perform public.teacher_payment_detail(school,(run->>'id')::uuid,'92000000-0000-4000-8000-000000000002');raise exception 'Other teacher detail accepted';exception when insufficient_privilege then null;end;
 begin perform sayasync_private.approved_payment_rows(school);raise exception 'Private school helper readable';exception when insufficient_privilege then null;end;
 begin perform public.record_teacher_payment(school,gen_random_uuid(),payload);raise exception 'Teacher recorded payment';exception when insufficient_privilege then null;end;
 begin update public.teacher_payments set reference='forged';raise exception 'Direct payment update allowed';exception when insufficient_privilege then null;end;
 perform set_config('request.jwt.claim.sub','90000000-0000-4000-8000-000000000002',true);
 list:=public.read_teacher_payments(school);
 if (list->>'total')::int<>1 or list->'records'->0->>'net_mmk'<>'6000' or list->'records'->0->>'payment_status'<>'Not paid' or exists(select 1 from public.teacher_payments) then raise exception 'Second teacher saw paid first-teacher receipt';end if;
 perform set_config('request.jwt.claim.sub','90000000-0000-4000-8000-000000000004',true);
 if (public.read_teacher_payments('91000000-0000-4000-8000-000000000002')->>'total')::int<>0 then raise exception 'Foreign school approved rows leaked';end if;
 begin perform public.read_teacher_payments(school);raise exception 'Cross-school read allowed';exception when insufficient_privilege then null;end;
 perform set_config('request.jwt.claim.sub','90000000-0000-4000-8000-000000000003',true);
 perform public.record_teacher_payment(school,gen_random_uuid(),payload||'{"teacher_id":"92000000-0000-4000-8000-000000000002","method":"Bank transfer","reference":"Fixture bank reference"}');
 list:=public.read_teacher_payments(school,1,'Paid');
 if (list->>'total')::int<>2 or (list->'records'->0->>'paid_count')::int<>2 or (list->'records'->0->>'teacher_count')::int<>2 then raise exception 'All-paid derivation failed';end if;
 if (select snapshot from public.payroll_drafts where id=(run->>'id')::uuid)<>run->'snapshot' or (select status from public.payroll_drafts where id=(run->>'id')::uuid)<>'Approved' then raise exception 'Payment changed frozen payroll';end if;
end $$;
reset role;
do $$ begin
 begin update public.teacher_payments set amount_mmk=1 where school_id='91000000-0000-4000-8000-000000000001';raise exception 'Payment history overwritten';exception when raise_exception then if SQLERRM<>'Payment history is immutable; reversal workflow is not available yet' then raise;end if;end;
 begin delete from public.teacher_payments where school_id='91000000-0000-4000-8000-000000000001';raise exception 'Receipt deleted';exception when raise_exception then if SQLERRM<>'Payment history is immutable; reversal workflow is not available yet' then raise;end if;end;
 begin insert into public.teacher_payments(school_id,run_id,teacher_id,amount_mmk,paid_date,method,reference,recorded_by)
 values('91000000-0000-4000-8000-000000000001',current_setting('test.payment_run')::uuid,'92000000-0000-4000-8000-000000000001',1,(clock_timestamp() at time zone 'Asia/Yangon')::date,'Cash','Try partial payment','90000000-0000-4000-8000-000000000003');raise exception 'Partial amount accepted';exception when raise_exception then if SQLERRM<>'Payment must equal the full frozen teacher net amount' then raise;end if;end;
 if has_function_privilege('anon','public.record_teacher_payment(uuid,uuid,jsonb)','execute') or has_function_privilege('anon','public.read_teacher_payments(uuid,integer,text,uuid)','execute') or has_function_privilege('anon','public.teacher_payment_detail(uuid,uuid,uuid)','execute') then raise exception 'Anonymous finance API exposed';end if;
 if (select count(*) from public.payroll_draft_events where school_id='91000000-0000-4000-8000-000000000001' and action='record_payment')<>2 then raise exception 'Payment audit retry mismatch';end if;
end $$;
select 'PASS: approved-only full frozen net payment, server amount/actor, future date/reference/version validation, retry/unique teacher payment, partial-run/all-paid derivation, immutable receipts and payroll, held-only exclusion, teacher-own sanitized breakdown/adjustments, no draft/other-teacher/cross-school/private-helper/anonymous/direct-write access' as result;
rollback;
