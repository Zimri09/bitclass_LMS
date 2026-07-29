-- Only the original author may delete a discussion thread or reply.
drop policy if exists "threads: authors and managers write" on public.threads;
drop policy if exists "threads manage instructors and authors" on public.threads;
drop policy if exists "threads: members create" on public.threads;
drop policy if exists "threads: authors and managers update" on public.threads;
drop policy if exists "threads: creators delete" on public.threads;

create policy "threads: members create"
  on public.threads for insert to authenticated
  with check (
    author_id = (select auth.uid())
    and (select private.is_course_member(course_id))
    and exists (
      select 1
      from public.discussion_channels dc
      where dc.id = threads.channel_id
        and dc.course_id = threads.course_id
        and (
          not dc.is_announcement
          or (select private.can_manage_course(threads.course_id))
        )
    )
  );

create policy "threads: authors and managers update"
  on public.threads for update to authenticated
  using (
    author_id = (select auth.uid())
    or (select private.can_manage_course(course_id))
  )
  with check (
    (
      author_id = (select auth.uid())
      or (select private.can_manage_course(course_id))
    )
    and exists (
      select 1
      from public.discussion_channels dc
      where dc.id = threads.channel_id
        and dc.course_id = threads.course_id
    )
  );

create policy "threads: creators delete"
  on public.threads for delete to authenticated
  using (author_id = (select auth.uid()));

drop policy if exists "replies: authors and managers write" on public.replies;
drop policy if exists "replies manage authors and instructors" on public.replies;
drop policy if exists "replies: members create" on public.replies;
drop policy if exists "replies: authors and managers update" on public.replies;
drop policy if exists "replies update own" on public.replies;
drop policy if exists "replies: creators delete" on public.replies;

create policy "replies: members create"
  on public.replies for insert to authenticated
  with check (
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
  );

create policy "replies update own"
  on public.replies for update to authenticated
  using (author_id = (select auth.uid()))
  with check (
    author_id = (select auth.uid())
    and exists (
      select 1
      from public.threads
      join public.discussion_channels on discussion_channels.id = threads.channel_id
      where threads.id = thread_id
        and threads.course_id = replies.course_id
        and threads.channel_id = replies.channel_id
        and discussion_channels.course_id = replies.course_id
    )
  );

create policy "replies: creators delete"
  on public.replies for delete to authenticated
  using (author_id = (select auth.uid()));
