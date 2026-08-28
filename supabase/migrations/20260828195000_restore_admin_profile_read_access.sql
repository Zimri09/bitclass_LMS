-- The admin dashboard reads the complete profile directory in order to show
-- user totals and manage student/instructor access. Keep ordinary users
-- limited to their own profile while allowing active administrators to read
-- every profile row.
drop policy if exists "profiles: self read" on public.profiles;
drop policy if exists "profiles: self or admin read" on public.profiles;

create policy "profiles: self or admin read"
  on public.profiles
  for select
  to authenticated
  using (
    id = (select auth.uid())
    or (select private.is_admin())
  );

