-- Link an already-invited account. No email is sent and no Auth user is created.
begin;
create function public.link_teacher_account(p_school uuid,p_teacher uuid,p_version integer,p_request uuid,p_reason text)
returns jsonb language plpgsql security definer set search_path='' as $$
declare
 actor uuid:=auth.uid(); t public.teachers%rowtype; u auth.users%rowtype;
 m public.memberships%rowtype; prior jsonb; result jsonb; payload jsonb;
 previous_request sayasync_private.master_requests%rowtype;
begin
 if actor is null or not sayasync_private.is_admin(p_school) then raise exception 'Administrator access required' using errcode='42501';end if;
 if p_request is null or length(trim(coalesce(p_reason,''))) not between 1 and 1000 then raise exception 'A request ID and reason are required';end if;
 perform pg_advisory_xact_lock(hashtextextended(p_school::text,0));
 payload:=jsonb_build_object('teacher',p_teacher,'version',p_version,'reason',trim(p_reason));
 select * into previous_request from sayasync_private.master_requests where school_id=p_school and actor_id=actor and request_id=p_request;
 if found then
  if previous_request.command<>'link_teacher_account' or previous_request.payload<>payload then raise exception 'Request ID already used';end if;
  return previous_request.result;
 end if;
 select * into t from public.teachers where school_id=p_school and id=p_teacher for update;
 if not found then raise exception 'Teacher not found';end if;
 if p_version is null or t.version<>p_version then raise exception 'Record changed. Reload before linking.' using errcode='40001';end if;
 if not t.active or t.user_id is not null then raise exception 'Only active, unlinked teacher profiles can be linked';end if;
 if (select count(*) from auth.users where lower(email)=t.email)<>1 then raise exception 'The project owner must invite this exact email first';end if;
 select * into u from auth.users where lower(email)=t.email for update;
 if not found or (u.invited_at is null and u.email_confirmed_at is null) then raise exception 'The project owner must invite this exact email first';end if;
 -- Serialize two schools trying to link the same Auth account.
 perform pg_advisory_xact_lock(hashtextextended(u.id::text,1));
 if exists(select 1 from public.teachers where user_id=u.id)
 or exists(select 1 from public.memberships where user_id=u.id and (school_id<>p_school or role<>'teacher'))
 then raise exception 'Account requires project-owner review before linking';end if;
 select * into m from public.memberships where school_id=p_school and user_id=u.id for update;
 if found then
  if not m.active or m.role<>'teacher' then raise exception 'Existing account access requires separate review';end if;
 else
  insert into public.memberships(school_id,user_id,role,active) values(p_school,u.id,'teacher',true);
 end if;
 prior:=to_jsonb(t);
 update public.teachers set user_id=u.id,version=version+1 where id=t.id returning to_jsonb(teachers.*) into result;
 update public.profiles set display_name=t.name where user_id=u.id and display_name='';
 insert into public.master_data_events(school_id,actor_id,action,entity_id,before_state,after_state,reason)
  values(p_school,actor,'link_teacher_account',t.id,prior,result,trim(p_reason));
 insert into sayasync_private.master_requests values(p_school,actor,p_request,'link_teacher_account',payload,result);
 return result;
end;
$$;
revoke all on function public.link_teacher_account(uuid,uuid,integer,uuid,text) from public,anon;
grant execute on function public.link_teacher_account(uuid,uuid,integer,uuid,text) to authenticated;

create function public.teacher_account_states(p_school uuid)
returns table(teacher_id uuid,account_state text)
language plpgsql stable security definer set search_path='' as $$
begin
 if not sayasync_private.is_admin(p_school) then raise exception 'Administrator access required' using errcode='42501';end if;
 return query select t.id,case
  when not t.active then 'disabled'
  when t.user_id is not null then case
   when not coalesce(m.active,false) or m.role<>'teacher' then 'disabled'
   when linked.email_confirmed_at is null then 'linked_pending'
   else 'active' end
  when candidate.id is null or (candidate.invited_at is null and candidate.email_confirmed_at is null) then 'not_linked'
  when exists(select 1 from public.teachers other where other.user_id=candidate.id)
    or exists(select 1 from public.memberships other where other.user_id=candidate.id and (other.school_id<>p_school or other.role<>'teacher' or not other.active)) then 'review_required'
  else 'ready_to_link' end
 from public.teachers t
 left join auth.users linked on linked.id=t.user_id
 left join public.memberships m on m.school_id=t.school_id and m.user_id=t.user_id
 left join auth.users candidate on lower(candidate.email)=t.email
 where t.school_id=p_school;
end;
$$;
revoke all on function public.teacher_account_states(uuid) from public,anon;
grant execute on function public.teacher_account_states(uuid) to authenticated;
commit;
