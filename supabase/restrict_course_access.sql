-- Require a class code before a student can view or enroll in a course.
-- Run this after supabase/harden_rls.sql in the Supabase SQL Editor.

do $$
declare
  policy_record record;
begin
  for policy_record in
    select policyname, tablename
    from pg_policies
    where schemaname = 'public'
      and tablename in ('courses', 'enrollments')
  loop
    execute format(
      'drop policy if exists %I on public.%I',
      policy_record.policyname,
      policy_record.tablename
    );
  end loop;
end;
$$;

create or replace function public.join_course_by_code(join_code text)
returns table (course_id uuid, enrollment_id uuid)
language plpgsql
security definer
set search_path = pg_catalog, public, auth
as $$
declare
  authenticated_user_id uuid := (select auth.uid());
  normalized_code text := upper(trim(join_code));
  target_course_id uuid;
  target_lesson_count integer;
  target_is_published boolean;
  created_enrollment_id uuid;
begin
  if authenticated_user_id is null then
    raise exception 'Authentication is required';
  end if;

  if normalized_code !~ '^[A-Z0-9]{6}$' then
    raise exception 'Invalid class code. Please check and try again.';
  end if;

  if not exists (
    select 1
    from public.profiles
    where id = authenticated_user_id and role = 'student'
  ) then
    raise exception 'Only student accounts can join courses.';
  end if;

  select id, lesson_count, is_published
  into target_course_id, target_lesson_count, target_is_published
  from public.courses
  where course_code = normalized_code;

  if target_course_id is null then
    raise exception 'Invalid class code. Please check and try again.';
  end if;

  if not target_is_published then
    raise exception 'This class has not been published yet. Ask your instructor to publish it first.';
  end if;

  insert into public.enrollments (
    course_id,
    user_id,
    student_name,
    student_email,
    progress,
    completed_lessons,
    total_lessons
  )
  select
    target_course_id,
    id,
    display_name,
    email,
    0,
    0,
    target_lesson_count
  from public.profiles
  where id = authenticated_user_id
  -- The function return column is also named course_id. Target the generated
  -- unique constraint explicitly so PL/pgSQL cannot confuse it with that
  -- output variable.
  on conflict on constraint enrollments_course_id_user_id_key do nothing
  returning id into created_enrollment_id;

  if created_enrollment_id is null then
    raise exception 'You are already enrolled in this course.';
  end if;

  return query select target_course_id, created_enrollment_id;
end;
$$;

revoke all on function public.join_course_by_code(text) from public;
revoke all on function public.join_course_by_code(text) from anon;
grant execute on function public.join_course_by_code(text) to authenticated;

create policy "courses: enrolled, owner, or admin read"
  on public.courses for select to authenticated
  using (
    (
      instructor_id = (select auth.uid())
      and (select private.is_staff())
    )
    or (select private.is_admin())
    or (
      is_published
      and exists (
        select 1
        from public.enrollments
        where course_id = courses.id
          and user_id = (select auth.uid())
      )
    )
  );

create policy "courses: owner or admin manage"
  on public.courses for all to authenticated
  using ((select private.can_manage_course(id)))
  with check (
    (
      instructor_id = (select auth.uid())
      and (select private.is_staff())
    )
    or (select private.is_admin())
  );

create policy "courses: instructors create"
  on public.courses for insert to authenticated
  with check (
    instructor_id = (select auth.uid())
    and (select private.is_staff())
  );

create policy "enrollments: self or course manager read"
  on public.enrollments for select to authenticated
  using (
    user_id = (select auth.uid())
    or (select private.can_manage_course(course_id))
  );

create policy "enrollments: self update"
  on public.enrollments for update to authenticated
  using (user_id = (select auth.uid()))
  with check (user_id = (select auth.uid()));

create policy "enrollments: self delete"
  on public.enrollments for delete to authenticated
  using (user_id = (select auth.uid()));
