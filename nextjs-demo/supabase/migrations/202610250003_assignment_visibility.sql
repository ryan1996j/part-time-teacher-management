-- Assignments are stamped with clock_timestamp(). A transaction-start now()
-- can precede a just-created assignment in the same transaction.
begin;
alter policy classes_read on public.classes using (
 sayasync_private.is_admin(school_id) or exists (
  select 1 from public.teacher_assignments a where a.class_id=classes.id
   and a.effective_from<=clock_timestamp()
   and (a.effective_to is null or a.effective_to>clock_timestamp())
   and sayasync_private.owns_teacher(a.teacher_id)
 )
);
commit;
