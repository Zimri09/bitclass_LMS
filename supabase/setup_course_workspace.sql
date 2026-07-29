-- Course workspace setup
-- Run after supabase/schema.sql and supabase/harden_rls.sql.
--
-- Creates the default discussion spaces used by the in-course Discussion tab
-- and provides a privacy-safe course roster. Students do not receive any
-- direct read or write access to other students' enrollment records.

create or replace function public.create_default_course_discussion_channels()
returns trigger
language plpgsql
security definer
set search_path = pg_catalog, public
as $$
begin
  insert into public.discussion_channels (
    course_id,
    title,
    description,
    is_default,
    is_announcement,
    is_published,
    created_by
  )
  values
    (
      new.id,
      'Announcements',
      'Official updates from the instructor.',
      true,
      true,
      true,
      new.instructor_id
    ),
    (
      new.id,
      'General discussion',
      'Questions and class conversations.',
      true,
      false,
      true,
      new.instructor_id
    );
  return new;
end;
$$;

revoke all on function public.create_default_course_discussion_channels()
  from public;

drop trigger if exists courses_create_default_discussion_channels
  on public.courses;
create trigger courses_create_default_discussion_channels
after insert on public.courses
for each row execute function public.create_default_course_discussion_channels();

-- Backfill the two default channels for existing courses without duplicating
-- any channel a course already has with the same purpose.
insert into public.discussion_channels (
  course_id,
  title,
  description,
  is_default,
  is_announcement,
  is_published,
  created_by
)
select
  c.id,
  'Announcements',
  'Official updates from the instructor.',
  true,
  true,
  true,
  c.instructor_id
from public.courses c
where not exists (
  select 1
  from public.discussion_channels dc
  where dc.course_id = c.id and dc.is_announcement
);

insert into public.discussion_channels (
  course_id,
  title,
  description,
  is_default,
  is_announcement,
  is_published,
  created_by
)
select
  c.id,
  'General discussion',
  'Questions and class conversations.',
  true,
  false,
  true,
  c.instructor_id
from public.courses c
where not exists (
  select 1
  from public.discussion_channels dc
  where dc.course_id = c.id and dc.is_default and not dc.is_announcement
);

-- Keep enrollment records private. The roster is exposed through the limited
-- function below, which returns only the current display name and avatar URL.
drop policy if exists "enrollments: self or course manager read"
  on public.enrollments;
drop policy if exists "enrollments: course roster members read"
  on public.enrollments;
create policy "enrollments: self or course manager read"
  on public.enrollments for select to authenticated
  using (
    user_id = (select auth.uid())
    or (select private.can_manage_course(course_id))
  );

create or replace function public.get_course_roster(target_course_id uuid)
returns table (
  user_id uuid,
  display_name text,
  avatar_url text
)
language sql
stable
security definer
set search_path = pg_catalog, public, auth
as $$
  select
    profile.id,
    coalesce(
      nullif(trim(concat_ws(' ', profile.first_name, profile.last_name)), ''),
      nullif(profile.display_name, ''),
      'Student'
    ),
    profile.avatar_url
  from public.enrollments enrollment
  join public.profiles profile on profile.id = enrollment.user_id
  where enrollment.course_id = target_course_id
    and (select private.is_course_member(target_course_id))
  order by lower(
    coalesce(
      nullif(trim(concat_ws(' ', profile.first_name, profile.last_name)), ''),
      nullif(profile.display_name, ''),
      'Student'
    )
  );
$$;

revoke all on function public.get_course_roster(uuid) from public;
grant execute on function public.get_course_roster(uuid) to authenticated;

-- Counters are maintained by trusted database triggers. Clients may create
-- permitted posts but never need update access to channels or other threads.
create or replace function public.sync_discussion_thread_count()
returns trigger
language plpgsql
security definer
set search_path = pg_catalog, public
as $$
begin
  if tg_op = 'INSERT' then
    update public.discussion_channels
    set
      thread_count = thread_count + 1,
      last_activity_at = new.created_at
    where id = new.channel_id;
    return new;
  end if;

  update public.discussion_channels
  set thread_count = greatest(thread_count - 1, 0)
  where id = old.channel_id;
  return old;
end;
$$;

create or replace function public.sync_discussion_reply_count()
returns trigger
language plpgsql
security definer
set search_path = pg_catalog, public
as $$
begin
  if tg_op = 'INSERT' then
    update public.threads
    set
      reply_count = reply_count + 1,
      last_reply_at = new.created_at
    where id = new.thread_id;

    update public.discussion_channels
    set last_activity_at = new.created_at
    where id = new.channel_id;
    return new;
  end if;

  update public.threads
  set reply_count = greatest(reply_count - 1, 0)
  where id = old.thread_id;
  return old;
end;
$$;

revoke all on function public.sync_discussion_thread_count() from public;
revoke all on function public.sync_discussion_reply_count() from public;

drop trigger if exists threads_sync_channel_count on public.threads;
create trigger threads_sync_channel_count
after insert or delete on public.threads
for each row execute function public.sync_discussion_thread_count();

drop trigger if exists replies_sync_thread_count on public.replies;
create trigger replies_sync_thread_count
after insert or delete on public.replies
for each row execute function public.sync_discussion_reply_count();

-- Announcement posts are instructor-only. Every enrolled member can create
-- and reply to threads in non-announcement channels.
drop policy if exists "threads: authors and managers write" on public.threads;
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
        from public.discussion_channels dc
        where dc.id = threads.channel_id
          and dc.course_id = threads.course_id
          and (not dc.is_announcement or (select private.can_manage_course(threads.course_id)))
      )
    )
    or (select private.can_manage_course(course_id))
  );
