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

-- A short original capture has zero whole minutes and must never verify.
insert into public.teaching_sessions(id,school_id,teacher_id,class_id,assignment_id,start_at,end_at,original_start_at,original_end_at,source,created_by)
 values('95000000-0000-4000-8000-000000000002','91000000-0000-4000-8000-000000000001','92000000-0000-4000-8000-000000000001','93000000-0000-4000-8000-000000000001','94000000-0000-4000-8000-000000000001',now()-interval '8 hours',now()-interval '8 hours'+interval '15 seconds',now()-interval '8 hours',now()-interval '8 hours'+interval '15 seconds','Teacher check-in','90000000-0000-4000-8000-000000000001');
-- All review mutations below concern disposable fixture schools only.
set local role authenticated;
select set_config('request.jwt.claim.sub','90000000-0000-4000-8000-000000000003',true);
do $$
declare school uuid:='91000000-0000-4000-8000-000000000001';s jsonb;c jsonb;r jsonb;payload jsonb;key uuid:=gen_random_uuid();original_start timestamptz;original_end timestamptz;
begin
 begin perform public.review_teaching_session(school,gen_random_uuid(),'verify_session','{"id":"95000000-0000-4000-8000-000000000002","version":1,"decision":"Verified"}');raise exception 'Zero minute verified';exception when raise_exception then if SQLERRM='Zero minute verified' then raise;end if;end;
 s:=public.capture_teaching_session(school,gen_random_uuid(),'admin_entry',jsonb_build_object('teacher_id','92000000-0000-4000-8000-000000000001','class_id','93000000-0000-4000-8000-000000000001','start_at',now()-interval '5 hours','end_at',now()-interval '4 hours','reason','Review fixture'));
 original_start:=(s->>'original_start_at')::timestamptz;original_end:=(s->>'original_end_at')::timestamptz;
 perform set_config('request.jwt.claim.sub','90000000-0000-4000-8000-000000000002',true);
 begin perform public.review_teaching_session(school,gen_random_uuid(),'request_correction',jsonb_build_object('id',s->>'id','version',s->'version'));raise exception 'Other teacher request accepted';exception when insufficient_privilege then null;end;
 perform set_config('request.jwt.claim.sub','90000000-0000-4000-8000-000000000001',true);
 payload:=jsonb_build_object('id',s->>'id','version',s->'version','start_at',now()-interval '5 hours','end_at',now()-interval '230 minutes','reason','Correct classroom end');
 c:=public.review_teaching_session(school,key,'request_correction',payload);
 r:=public.review_teaching_session(school,key,'request_correction',payload);
 if c<>r or (select count(*) from public.correction_records)<>1 then raise exception 'Correction retry duplicated';end if;
 begin perform public.review_teaching_session(school,gen_random_uuid(),'request_correction',payload);raise exception 'Second pending request accepted';exception when raise_exception then if SQLERRM='Second pending request accepted' then raise;end if;end;
 begin perform public.review_teaching_session(school,gen_random_uuid(),'verify_session',jsonb_build_object('id',s->>'id','version',s->'version','decision','Verified'));raise exception 'Teacher verified';exception when insufficient_privilege then null;end;
 perform set_config('request.jwt.claim.sub','90000000-0000-4000-8000-000000000003',true);
 begin perform public.review_teaching_session(school,gen_random_uuid(),'verify_session',jsonb_build_object('id',s->>'id','version',s->'version','decision','Verified'));raise exception 'Pending correction verified';exception when raise_exception then if SQLERRM='Pending correction verified' then raise;end if;end;
 key:=gen_random_uuid();payload:=jsonb_build_object('id',c->>'id','version',c->'version','session_version',s->'version','decision','Approved','reason','Checked');
 r:=public.review_teaching_session(school,key,'review_correction',payload);
 if public.review_teaching_session(school,key,'review_correction',payload)<>r then raise exception 'Review retry mismatch';end if;
 select to_jsonb(x) into s from public.teaching_sessions x where id=(s->>'id')::uuid;
 if s->>'verification'<>'Pending' or (s->>'minutes')::int<>70 or (s->>'original_start_at')::timestamptz<>original_start or (s->>'original_end_at')::timestamptz<>original_end then raise exception 'Correction/original/verification mismatch';end if;
 begin perform public.review_teaching_session(school,gen_random_uuid(),'verify_session',jsonb_build_object('id',s->>'id','version',1,'decision','Verified'));raise exception 'Stale verify accepted';exception when serialization_failure then null;end;
 s:=public.review_teaching_session(school,gen_random_uuid(),'verify_session',jsonb_build_object('id',s->>'id','version',s->'version','decision','Verified','reason','Reviewed teaching'));
 if s->>'verification'<>'Verified' then raise exception 'Verification failed';end if;
 -- Withdrawal leaves verified times untouched and releases the pending hold.
 perform set_config('request.jwt.claim.sub','90000000-0000-4000-8000-000000000001',true);
 c:=public.review_teaching_session(school,gen_random_uuid(),'request_correction',jsonb_build_object('id',s->>'id','version',s->'version','start_at',now()-interval '5 hours','end_at',now()-interval '220 minutes','reason','Withdraw fixture'));
 r:=public.review_teaching_session(school,gen_random_uuid(),'withdraw_correction',jsonb_build_object('id',c->>'id','version',c->'version'));
 if r->>'status'<>'Withdrawn' or (select pending_correction from public.session_records where id=(s->>'id')::uuid) then raise exception 'Withdrawal failed';end if;
 c:=public.review_teaching_session(school,gen_random_uuid(),'request_correction',jsonb_build_object('id',s->>'id','version',s->'version','start_at',now()-interval '5 hours','end_at',now()-interval '210 minutes','reason','Reject fixture'));
 perform set_config('request.jwt.claim.sub','90000000-0000-4000-8000-000000000003',true);
 begin perform public.review_teaching_session(school,gen_random_uuid(),'review_correction',jsonb_build_object('id',c->>'id','version',c->'version','decision','Rejected'));raise exception 'Blank rejection accepted';exception when raise_exception then if SQLERRM='Blank rejection accepted' then raise;end if;end;
 r:=public.review_teaching_session(school,gen_random_uuid(),'review_correction',jsonb_build_object('id',c->>'id','version',c->'version','decision','Rejected','reason','Not supported'));
 if (select end_at from public.teaching_sessions where id=(s->>'id')::uuid)<>(s->>'end_at')::timestamptz then raise exception 'Rejection changed effective time';end if;
 -- New overlaps invalidate past verification, require a reason, and make requests stale.
 c:=public.review_teaching_session(school,gen_random_uuid(),'request_correction',jsonb_build_object('id',s->>'id','version',s->'version','start_at',now()-interval '5 hours','end_at',now()-interval '200 minutes','reason','Stale fixture'));
 r:=public.capture_teaching_session(school,gen_random_uuid(),'admin_entry',jsonb_build_object('teacher_id','92000000-0000-4000-8000-000000000001','class_id','93000000-0000-4000-8000-000000000001','start_at',now()-interval '270 minutes','end_at',now()-interval '210 minutes','reason','Overlap fixture'));
 begin perform public.review_teaching_session(school,gen_random_uuid(),'review_correction',jsonb_build_object('id',c->>'id','version',c->'version','session_version',s->'version','decision','Approved'));raise exception 'Stale approval accepted';exception when serialization_failure then null;end;
 perform public.review_teaching_session(school,gen_random_uuid(),'review_correction',jsonb_build_object('id',c->>'id','version',c->'version','decision','Rejected','reason','Stale; resubmit'));
 begin perform public.review_teaching_session(school,gen_random_uuid(),'verify_session',jsonb_build_object('id',r->>'id','version',r->'version','decision','Verified'));raise exception 'Unresolved overlap verified';exception when raise_exception then if SQLERRM='Unresolved overlap verified' then raise;end if;end;
 r:=public.review_teaching_session(school,gen_random_uuid(),'verify_session',jsonb_build_object('id',r->>'id','version',r->'version','decision','Verified','reason','Reviewed fixture overlap'));
 if r->>'overlap_resolution'='' then raise exception 'Overlap reason missing';end if;
 -- Open/missing-checkout session can be corrected without inventing original checkout.
 c:=public.review_teaching_session(school,gen_random_uuid(),'request_correction',jsonb_build_object('id','95000000-0000-4000-8000-000000000001','version',1,'start_at',now()-interval '2 days','end_at',now()-interval '47 hours','reason','Forgot checkout'));
 perform public.review_teaching_session(school,gen_random_uuid(),'review_correction',jsonb_build_object('id',c->>'id','version',c->'version','session_version',1,'decision','Approved'));
 if (select original_end_at from public.teaching_sessions where id='95000000-0000-4000-8000-000000000001') is not null then raise exception 'Original checkout fabricated';end if;
 begin update public.correction_requests set status='Approved';raise exception 'Direct correction write allowed';exception when insufficient_privilege then null;end;
 perform set_config('request.jwt.claim.sub','90000000-0000-4000-8000-000000000004',true);
 if exists(select 1 from public.correction_records) then raise exception 'Foreign school correction leaked';end if;
 begin perform public.review_teaching_session(school,gen_random_uuid(),'request_correction','{}');raise exception 'Foreign school mutation allowed';exception when insufficient_privilege then null;end;
end $$;
reset role;
-- Anonymous execution and missing audit are release blockers.
do $$ begin
 if has_function_privilege('anon','public.review_teaching_session(uuid,uuid,text,jsonb)','execute') then raise exception 'Anonymous review exposed';end if;
 if not exists(select 1 from public.session_events where school_id='91000000-0000-4000-8000-000000000001' and action='review_correction') then raise exception 'Review audit missing';end if;
end $$;
select 'PASS: own/school RLS, admin-only review, retries, pending uniqueness/hold, original preservation, separate verification, stale decisions, withdrawal/rejection, overlap reasons, missing-checkout correction, zero-minute verification denial, audit, denied direct/anon writes' as result;
rollback;
