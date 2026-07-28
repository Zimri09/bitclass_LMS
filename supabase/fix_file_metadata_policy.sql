-- Repair file metadata policies after harden_rls.sql.
-- Run this in the Supabase SQL Editor after the other setup scripts.

do $$
declare
  policy_record record;
begin
  for policy_record in
    select policyname
    from pg_policies
    where schemaname = 'public' and tablename = 'files'
  loop
    execute format(
      'drop policy if exists %I on public.files',
      policy_record.policyname
    );
  end loop;
end;
$$;

create policy "files: course members read"
  on public.files for select to authenticated
  using (
    exists (
      select 1
      from public.courses
      where id = files.course_id and instructor_id = (select auth.uid())
    )
    or exists (
      select 1
      from public.enrollments
      where course_id = files.course_id and user_id = (select auth.uid())
    )
    or exists (
      select 1
      from public.profiles
      where id = (select auth.uid()) and role = 'admin'
    )
  );

create policy "files: course instructors insert"
  on public.files for insert to authenticated
  with check (
    uploader_id = (select auth.uid())
    and (
      exists (
        select 1
        from public.courses
        where id = files.course_id and instructor_id = (select auth.uid())
      )
      or exists (
        select 1
        from public.profiles
        where id = (select auth.uid()) and role = 'admin'
      )
    )
  );

create policy "files: course instructors update"
  on public.files for update to authenticated
  using (
    exists (
      select 1
      from public.courses
      where id = files.course_id and instructor_id = (select auth.uid())
    )
    or exists (
      select 1
      from public.profiles
      where id = (select auth.uid()) and role = 'admin'
    )
  )
  with check (
    exists (
      select 1
      from public.courses
      where id = files.course_id and instructor_id = (select auth.uid())
    )
    or exists (
      select 1
      from public.profiles
      where id = (select auth.uid()) and role = 'admin'
    )
  );

create policy "files: course instructors delete"
  on public.files for delete to authenticated
  using (
    exists (
      select 1
      from public.courses
      where id = files.course_id and instructor_id = (select auth.uid())
    )
    or exists (
      select 1
      from public.profiles
      where id = (select auth.uid()) and role = 'admin'
    )
  );
