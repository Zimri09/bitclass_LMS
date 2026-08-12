create index if not exists submissions_user_idx
  on public.submissions (user_id);
create index if not exists submissions_graded_by_idx
  on public.submissions (graded_by)
  where graded_by is not null;
