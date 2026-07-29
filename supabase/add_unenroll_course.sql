-- =============================================================================
-- Student self-unenrollment for BitClass LMS
-- Run once in the Supabase SQL Editor.
-- =============================================================================

create or replace function public.unenroll_from_course(target_course_id uuid)
returns void
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if (select auth.uid()) is null then
    raise exception 'You must be signed in to unenroll.';
  end if;

  delete from public.enrollments
  where course_id = target_course_id
    and user_id = (select auth.uid());

  if not found then
    raise exception 'You are not enrolled in this class.';
  end if;

  update public.courses
  set
    enrollment_count = greatest(enrollment_count - 1, 0),
    updated_at = timezone('utc', now())
  where id = target_course_id;
end;
$$;

revoke all on function public.unenroll_from_course(uuid) from public;
grant execute on function public.unenroll_from_course(uuid) to authenticated;
