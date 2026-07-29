-- Allow reply creators to edit their own text and remove accepted-answer state.
alter table public.replies
  add column if not exists edited_at timestamptz;

alter table public.replies
  drop column if exists is_accepted_answer;

drop policy if exists "replies update authors and instructors"
  on public.replies;
drop policy if exists "replies: authors and managers update"
  on public.replies;
drop policy if exists "replies manage authors and instructors"
  on public.replies;
drop policy if exists "replies: authors and managers write"
  on public.replies;
drop policy if exists "replies update own"
  on public.replies;

create policy "replies update own"
  on public.replies for update to authenticated
  using (author_id = (select auth.uid()))
  with check (
    author_id = (select auth.uid())
    and exists (
      select 1
      from public.threads
      join public.discussion_channels
        on discussion_channels.id = threads.channel_id
      where threads.id = replies.thread_id
        and threads.course_id = replies.course_id
        and threads.channel_id = replies.channel_id
        and discussion_channels.course_id = replies.course_id
    )
  );
