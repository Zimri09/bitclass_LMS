-- Explicit Supabase role grants can exist in addition to PUBLIC defaults.
revoke all on function public.unsubmit_assignment(uuid) from public, anon;
grant execute on function public.unsubmit_assignment(uuid) to authenticated;

revoke all on function public.set_submission_completion_metadata()
  from public, anon, authenticated;

create index if not exists assignments_course_published_due_idx
  on public.assignments (course_id, is_published, due_date);
create index if not exists assignments_lesson_idx
  on public.assignments (lesson_id)
  where lesson_id is not null;
create index if not exists submissions_course_user_idx
  on public.submissions (course_id, user_id);
