-- ============================================================
-- Fix: Infinite recursion in profiles RLS policy
-- ============================================================
-- The "profiles read own" policy queries the profiles table
-- to check if the current user is an instructor/admin, which
-- triggers the same policy again → infinite loop → 500 error.
--
-- Solution: Create a SECURITY DEFINER function that reads the
-- role from auth.users.raw_user_meta_data (bypasses RLS).
-- ============================================================

-- 1. Helper function: get current user's role without hitting profiles RLS
create or replace function public.current_user_role()
returns text
language sql
stable
security definer
set search_path = public, auth
as $$
  select coalesce(
    -- First try the profiles table directly (bypasses RLS because SECURITY DEFINER)
    (select role::text from public.profiles where id = auth.uid()),
    -- Fallback to auth metadata
    (select raw_user_meta_data->>'role' from auth.users where id = auth.uid()),
    'student'
  );
$$;

-- 2. Drop the problematic profiles policies
drop policy if exists "profiles read own" on public.profiles;
drop policy if exists "profiles write own" on public.profiles;
drop policy if exists "profiles update own" on public.profiles;

-- 3. Recreate profiles policies WITHOUT recursion
-- Users can always read their own profile.
-- Instructors and admins can read all profiles (checked via the helper function).
create policy "profiles read own" on public.profiles
  for select using (
    auth.uid() = id
    or public.current_user_role() in ('instructor', 'admin')
  );

create policy "profiles write own" on public.profiles
  for insert with check (auth.uid() = id);

create policy "profiles update own" on public.profiles
  for update using (auth.uid() = id);

-- 4. Also add missing INSERT/DELETE policies for todos
drop policy if exists "todos insert own" on public.todos;
drop policy if exists "todos delete own" on public.todos;

create policy "todos insert own" on public.todos
  for insert with check (user_id = auth.uid());

create policy "todos delete own" on public.todos
  for delete using (user_id = auth.uid());

-- 5. Add missing policies for enrollments (students need to enroll)
drop policy if exists "enrollments insert own" on public.enrollments;
drop policy if exists "enrollments update own" on public.enrollments;

create policy "enrollments insert own" on public.enrollments
  for insert with check (user_id = auth.uid());

create policy "enrollments update own" on public.enrollments
  for update using (
    user_id = auth.uid()
    or exists (
      select 1 from public.courses c
      where c.id = course_id and c.instructor_id = auth.uid()
    )
  );

-- 6. Add missing policies for lesson_progress
drop policy if exists "lesson progress insert own" on public.lesson_progress;
drop policy if exists "lesson progress update own" on public.lesson_progress;

create policy "lesson progress insert own" on public.lesson_progress
  for insert with check (
    exists (
      select 1 from public.enrollments e
      where e.id = enrollment_id and e.user_id = auth.uid()
    )
  );

create policy "lesson progress update own" on public.lesson_progress
  for update using (
    exists (
      select 1 from public.enrollments e
      where e.id = enrollment_id and e.user_id = auth.uid()
    )
  );

-- 7. Add missing policies for submissions (students need to create/update submissions)
drop policy if exists "submissions insert own" on public.submissions;
drop policy if exists "submissions update own or instructors" on public.submissions;

create policy "submissions insert own" on public.submissions
  for insert with check (user_id = auth.uid());

create policy "submissions update own or instructors" on public.submissions
  for update using (
    user_id = auth.uid()
    or exists (
      select 1 from public.courses c
      where c.id = course_id and c.instructor_id = auth.uid()
    )
  );

-- 8. Add missing policies for files (uploaders need to insert/manage)
drop policy if exists "files insert own" on public.files;
drop policy if exists "files update own" on public.files;
drop policy if exists "files delete own" on public.files;

create policy "files insert own" on public.files
  for insert with check (uploader_id = auth.uid());

create policy "files update own" on public.files
  for update using (
    uploader_id = auth.uid()
    or exists (
      select 1 from public.courses c
      where c.id = course_id and c.instructor_id = auth.uid()
    )
  );

create policy "files delete own" on public.files
  for delete using (
    uploader_id = auth.uid()
    or exists (
      select 1 from public.courses c
      where c.id = course_id and c.instructor_id = auth.uid()
    )
  );

-- 9. Add missing write policies for modules and lessons (instructors)
drop policy if exists "modules manage instructors" on public.modules;
drop policy if exists "lessons manage instructors" on public.lessons;
drop policy if exists "assignments manage instructors" on public.assignments;

create policy "modules manage instructors" on public.modules
  for all using (
    exists (
      select 1 from public.courses c
      where c.id = course_id and c.instructor_id = auth.uid()
    )
  ) with check (
    exists (
      select 1 from public.courses c
      where c.id = course_id and c.instructor_id = auth.uid()
    )
  );

create policy "lessons manage instructors" on public.lessons
  for all using (
    exists (
      select 1 from public.courses c
      where c.id = course_id and c.instructor_id = auth.uid()
    )
  ) with check (
    exists (
      select 1 from public.courses c
      where c.id = course_id and c.instructor_id = auth.uid()
    )
  );

create policy "assignments manage instructors" on public.assignments
  for all using (
    exists (
      select 1 from public.courses c
      where c.id = course_id and c.instructor_id = auth.uid()
    )
  ) with check (
    exists (
      select 1 from public.courses c
      where c.id = course_id and c.instructor_id = auth.uid()
    )
  );
