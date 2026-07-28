-- Fix the class-code join function after error 42702:
-- "column reference course_id is ambiguous".
-- Safe to run in the Supabase SQL Editor. It preserves class-code-only access.

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
  created_enrollment_id uuid;
begin
  if authenticated_user_id is null then
    raise exception 'Authentication is required';
  end if;

  if normalized_code !~ '^[A-Z0-9]{6}$' then
    raise exception 'Invalid course code. Please check and try again.';
  end if;

  if not exists (
    select 1
    from public.profiles
    where id = authenticated_user_id and role = 'student'
  ) then
    raise exception 'Only student accounts can join courses.';
  end if;

  select id, lesson_count
  into target_course_id, target_lesson_count
  from public.courses
  where course_code = normalized_code and is_published;

  if target_course_id is null then
    raise exception 'Invalid course code. Please check and try again.';
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
  -- Explicit constraint name avoids the course_id output-variable collision.
  on conflict on constraint enrollments_course_id_user_id_key do nothing
  returning id into created_enrollment_id;

  if created_enrollment_id is null then
    raise exception 'You are already enrolled in this course.';
  end if;

  update public.courses
  set enrollment_count = enrollment_count + 1
  where id = target_course_id;

  return query select target_course_id, created_enrollment_id;
end;
$$;

revoke all on function public.join_course_by_code(text) from public;
grant execute on function public.join_course_by_code(text) to authenticated;

-- Verify the repaired function definition exists. Do not run the function here:
-- it requires a real signed-in student's JWT.
select routine_name
from information_schema.routines
where routine_schema = 'public'
  and routine_name = 'join_course_by_code';
