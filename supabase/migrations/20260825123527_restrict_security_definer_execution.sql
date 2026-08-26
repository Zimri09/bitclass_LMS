-- Profiles contain private fields such as email, age, and suspension state.
-- Public course-member details are exposed through get_course_roster instead.
drop policy if exists "profiles: self or staff read" on public.profiles;
drop policy if exists "profiles: self read" on public.profiles;
create policy "profiles: self read"
  on public.profiles
  for select
  to authenticated
  using (id = (select auth.uid()));

-- Trigger functions run through their owning triggers and must not be callable
-- directly through PostgREST RPC endpoints.
revoke all on function public.create_default_course_discussion_channels()
  from public, anon, authenticated;
revoke all on function public.sync_course_lesson_count()
  from public, anon, authenticated;
revoke all on function public.sync_discussion_reply_count()
  from public, anon, authenticated;

-- These RPCs are app-facing, but only signed-in users may invoke them.
revoke all on function public.delete_current_user_account()
  from public, anon;
grant execute on function public.delete_current_user_account()
  to authenticated, service_role;

revoke all on function public.get_course_roster(uuid)
  from public, anon;
grant execute on function public.get_course_roster(uuid)
  to authenticated, service_role;

-- Place trusted system schemas before the writable public schema when these
-- SECURITY DEFINER functions resolve unqualified names.
alter function public.delete_current_user_account()
  set search_path = pg_catalog, public, auth;
alter function public.sync_course_lesson_count()
  set search_path = pg_catalog, public;
