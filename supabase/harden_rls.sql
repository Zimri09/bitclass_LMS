-- BitClass RLS hardening (phase 1)
--
-- Run this after schema.sql, setup_storage.sql, and any legacy SQL patches.
-- It removes all policies from the tables managed here before adding the
-- hardened replacements, so permissive legacy policies cannot remain active.
--
-- This patch intentionally does not make the storage bucket private yet:
-- the Flutter client currently stores and opens public URLs. Move to signed
-- URLs before changing the bucket or storage-object read policy.
--
-- Quiz questions include correct answers in the same row. Keep the quiz-answer
-- separation work as a dedicated follow-up before claiming question secrecy.

create schema if not exists private;
revoke all on schema private from public;
grant usage on schema private to authenticated;

-- These helpers bypass profile RLS safely, but are not exposed through the API.
create or replace function private.is_admin()
returns boolean
language sql
stable
security definer
set search_path = pg_catalog, public, auth
as $$
  select exists (
    select 1
    from public.profiles
    where id = (select auth.uid())
      and role = 'admin'
  );
$$;

create or replace function private.is_staff()
returns boolean
language sql
stable
security definer
set search_path = pg_catalog, public, auth
as $$
  select exists (
    select 1
    from public.profiles
    where id = (select auth.uid())
      and role in ('instructor', 'admin')
  );
$$;

create or replace function private.can_manage_course(target_course_id uuid)
returns boolean
language sql
stable
security definer
set search_path = pg_catalog, public, auth
as $$
  select (select private.is_admin()) or exists (
    select 1
    from public.courses
    where id = target_course_id
      and instructor_id = (select auth.uid())
      and (select private.is_staff())
  );
$$;

create or replace function private.is_course_member(target_course_id uuid)
returns boolean
language sql
stable
security definer
set search_path = pg_catalog, public, auth
as $$
  select (select private.can_manage_course(target_course_id)) or exists (
    select 1
    from public.enrollments
    where course_id = target_course_id
      and user_id = (select auth.uid())
  );
$$;

revoke all on function private.is_admin() from public;
revoke all on function private.is_staff() from public;
revoke all on function private.can_manage_course(uuid) from public;
revoke all on function private.is_course_member(uuid) from public;
grant execute on function private.is_admin() to authenticated;
grant execute on function private.is_staff() to authenticated;
grant execute on function private.can_manage_course(uuid) to authenticated;
grant execute on function private.is_course_member(uuid) to authenticated;

-- This is the only route for students to discover and join a class. It checks
-- the code, publishes the enrollment, and increments the count atomically.
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
  -- The function return column is also named course_id. Target the generated
  -- unique constraint explicitly so PL/pgSQL cannot confuse it with that
  -- output variable.
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

-- Dashboard or migration SQL can assign roles; authenticated clients cannot.
create or replace function private.prevent_client_role_change()
returns trigger
language plpgsql
set search_path = pg_catalog, auth
as $$
begin
  if (select auth.uid()) is not null
     and new.role is distinct from old.role then
    raise exception 'Profile roles can only be changed by a privileged server action';
  end if;
  return new;
end;
$$;

drop trigger if exists profiles_role_immutable on public.profiles;
create trigger profiles_role_immutable
  before update of role on public.profiles
  for each row execute function private.prevent_client_role_change();

-- Replace policies, rather than layering new permissive policies over old ones.
do $$
declare
  policy_record record;
begin
  for policy_record in
    select policyname, tablename
    from pg_policies
    where schemaname = 'public'
      and tablename = any (
        array[
          'profiles',
          'courses',
          'modules',
          'lessons',
          'enrollments',
          'lesson_progress',
          'assignments',
          'discussion_channels',
          'threads',
          'replies',
          'files'
        ]
      )
  loop
    execute format(
      'drop policy if exists %I on public.%I',
      policy_record.policyname,
      policy_record.tablename
    );
  end loop;
end;
$$;

drop function if exists public.current_user_role();

create policy "profiles: self or staff read"
  on public.profiles for select to authenticated
  using (id = (select auth.uid()) or (select private.is_staff()));

create policy "profiles: self insert"
  on public.profiles for insert to authenticated
  with check (id = (select auth.uid()));

create policy "profiles: self update"
  on public.profiles for update to authenticated
  using (id = (select auth.uid()))
  with check (id = (select auth.uid()));

create policy "courses: enrolled, owner, or admin read"
  on public.courses for select to authenticated
  using (
    (select private.can_manage_course(id))
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

create policy "lesson progress: self or course manager read"
  on public.lesson_progress for select to authenticated
  using (
    user_id = (select auth.uid())
    or exists (
      select 1
      from public.enrollments
      where id = enrollment_id
        and (select private.can_manage_course(course_id))
    )
  );

create policy "lesson progress: valid enrollment write"
  on public.lesson_progress for all to authenticated
  using (
    user_id = (select auth.uid())
    and exists (
      select 1
      from public.enrollments
      join public.lessons on lessons.course_id = enrollments.course_id
      where enrollments.id = lesson_progress.enrollment_id
        and enrollments.user_id = (select auth.uid())
        and lessons.id = lesson_progress.lesson_id
    )
  )
  with check (
    user_id = (select auth.uid())
    and exists (
      select 1
      from public.enrollments
      join public.lessons on lessons.course_id = enrollments.course_id
      where enrollments.id = lesson_progress.enrollment_id
        and enrollments.user_id = (select auth.uid())
        and lessons.id = lesson_progress.lesson_id
    )
  );

create policy "modules: course members read published"
  on public.modules for select to authenticated
  using (
    (select private.can_manage_course(course_id))
    or (is_published and (select private.is_course_member(course_id)))
  );

create policy "modules: course managers write"
  on public.modules for all to authenticated
  using ((select private.can_manage_course(course_id)))
  with check ((select private.can_manage_course(course_id)));

create policy "lessons: course members read published"
  on public.lessons for select to authenticated
  using (
    (select private.can_manage_course(course_id))
    or (
      is_published
      and (select private.is_course_member(course_id))
      and exists (
        select 1
        from public.modules
        where id = module_id and is_published
      )
    )
  );

create policy "lessons: course managers write"
  on public.lessons for all to authenticated
  using ((select private.can_manage_course(course_id)))
  with check ((select private.can_manage_course(course_id)));

create policy "assignments: course members read published"
  on public.assignments for select to authenticated
  using (
    (select private.can_manage_course(course_id))
    or (is_published and (select private.is_course_member(course_id)))
  );

create policy "assignments: course managers write"
  on public.assignments for all to authenticated
  using ((select private.can_manage_course(course_id)))
  with check ((select private.can_manage_course(course_id)));

create policy "channels: course members read published"
  on public.discussion_channels for select to authenticated
  using (
    (select private.can_manage_course(course_id))
    or (is_published and (select private.is_course_member(course_id)))
  );

create policy "channels: course managers write"
  on public.discussion_channels for all to authenticated
  using ((select private.can_manage_course(course_id)))
  with check ((select private.can_manage_course(course_id)));

create policy "threads: course members read"
  on public.threads for select to authenticated
  using (
    (select private.is_course_member(course_id))
    and exists (
      select 1
      from public.discussion_channels
      where id = channel_id
        and course_id = threads.course_id
        and is_published
    )
  );

create policy "threads: authors and managers write"
  on public.threads for all to authenticated
  using (
    author_id = (select auth.uid())
    or (select private.can_manage_course(course_id))
  )
  with check (
    (
      author_id = (select auth.uid())
      and (select private.is_course_member(course_id))
      and exists (
        select 1
        from public.discussion_channels
        where id = channel_id
          and course_id = threads.course_id
      )
    )
    or (select private.can_manage_course(course_id))
  );

create policy "replies: course members read"
  on public.replies for select to authenticated
  using (
    (select private.is_course_member(course_id))
    and exists (
      select 1
      from public.threads
      join public.discussion_channels on discussion_channels.id = threads.channel_id
      where threads.id = thread_id
        and threads.course_id = replies.course_id
        and threads.channel_id = replies.channel_id
        and discussion_channels.course_id = replies.course_id
        and discussion_channels.is_published
    )
  );

create policy "replies: authors and managers write"
  on public.replies for all to authenticated
  using (
    author_id = (select auth.uid())
    or (select private.can_manage_course(course_id))
  )
  with check (
    (
      author_id = (select auth.uid())
      and (select private.is_course_member(course_id))
      and exists (
        select 1
        from public.threads
        join public.discussion_channels on discussion_channels.id = threads.channel_id
        where threads.id = thread_id
          and threads.course_id = replies.course_id
          and threads.channel_id = replies.channel_id
          and discussion_channels.course_id = replies.course_id
      )
    )
    or (select private.can_manage_course(course_id))
  );

create policy "files: course members read metadata"
  on public.files for select to authenticated
  using ((select private.is_course_member(course_id)));

create policy "files: course managers write metadata"
  on public.files for all to authenticated
  using ((select private.can_manage_course(course_id)))
  with check ((select private.can_manage_course(course_id)));

-- Manual verification after deployment:
-- 1. As a non-enrolled student, select modules, lessons, assignments,
--    channels, threads, replies, and files for a published course: expect no rows.
-- 2. As an enrolled student, select published content for that course: expect rows.
-- 3. As an enrolled student, update another student's thread/reply: expect denial.
-- 4. As an authenticated client, update profiles.role: expect an exception.
-- 5. As a database administrator, assign an admin role, then verify admin access.
