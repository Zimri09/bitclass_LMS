-- BitClass LMS: secure assignment submissions
-- Run this after harden_rls.sql in the Supabase SQL Editor.
-- It prevents students from changing grades directly and enforces the
-- assignment publication and late-submission rules at the database boundary.

alter table public.submissions enable row level security;

do $$
declare
  policy_record record;
begin
  for policy_record in
    select policyname
    from pg_policies
    where schemaname = 'public' and tablename = 'submissions'
  loop
    execute format(
      'drop policy if exists %I on public.submissions',
      policy_record.policyname
    );
  end loop;
end $$;

create policy "submissions: students read own, managers read course"
  on public.submissions for select to authenticated
  using (
    user_id = (select auth.uid())
    or (select private.can_manage_course(course_id))
  );

create policy "submissions: course managers manage"
  on public.submissions for all to authenticated
  using ((select private.can_manage_course(course_id)))
  with check ((select private.can_manage_course(course_id)));

create policy "submissions: students create valid work"
  on public.submissions for insert to authenticated
  with check (
    user_id = (select auth.uid())
    and status in ('draft'::public.submission_status, 'submitted'::public.submission_status)
    and score is null
    and feedback is null
    and graded_by is null
    and graded_at is null
    and exists (
      select 1
      from public.assignments
      where id = submissions.assignment_id
        and course_id = submissions.course_id
        and is_published
        and (select private.is_course_member(submissions.course_id))
        and (
          submissions.status = 'draft'::public.submission_status
          or allow_late_submission
          or due_date is null
          or now() <= due_date
        )
    )
  );

create policy "submissions: students update valid work"
  on public.submissions for update to authenticated
  using (
    user_id = (select auth.uid())
    and status in ('draft'::public.submission_status, 'submitted'::public.submission_status)
  )
  with check (
    user_id = (select auth.uid())
    and status in ('draft'::public.submission_status, 'submitted'::public.submission_status)
    and score is null
    and feedback is null
    and graded_by is null
    and graded_at is null
    and exists (
      select 1
      from public.assignments
      where id = submissions.assignment_id
        and course_id = submissions.course_id
        and is_published
        and (select private.is_course_member(submissions.course_id))
        and (
          submissions.status = 'draft'::public.submission_status
          or allow_late_submission
          or due_date is null
          or now() <= due_date
        )
    )
  );
