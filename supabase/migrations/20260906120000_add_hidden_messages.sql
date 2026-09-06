create table if not exists public.hidden_messages (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  message_type text not null check (message_type in ('thread', 'reply')),
  message_id uuid not null,
  created_at timestamptz not null default timezone('utc', now()),
  unique (user_id, message_type, message_id)
);

create index if not exists hidden_messages_user_type_idx
  on public.hidden_messages (user_id, message_type);

alter table public.hidden_messages enable row level security;

drop policy if exists "hidden messages: read own" on public.hidden_messages;
create policy "hidden messages: read own"
  on public.hidden_messages for select to authenticated
  using (user_id = (select auth.uid()));

drop policy if exists "hidden messages: create own" on public.hidden_messages;
create policy "hidden messages: create own"
  on public.hidden_messages for insert to authenticated
  with check (
    user_id = (select auth.uid())
    and (
      (message_type = 'thread' and exists (
        select 1 from public.threads
        where threads.id = message_id
          and (select private.is_course_member(threads.course_id))
      ))
      or (message_type = 'reply' and exists (
        select 1 from public.replies
        where replies.id = message_id
          and (select private.is_course_member(replies.course_id))
      ))
    )
  );

drop policy if exists "hidden messages: delete own" on public.hidden_messages;
create policy "hidden messages: delete own"
  on public.hidden_messages for delete to authenticated
  using (user_id = (select auth.uid()));