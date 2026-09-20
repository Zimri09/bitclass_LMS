create table if not exists public.private_messages (
  id uuid primary key default gen_random_uuid(),
  course_id uuid not null references public.courses(id) on delete cascade,
  sender_id uuid not null references public.profiles(id) on delete cascade,
  recipient_id uuid not null references public.profiles(id) on delete cascade,
  body text not null check (char_length(trim(body)) between 1 and 4000),
  created_at timestamptz not null default timezone('utc', now()),
  read_at timestamptz,
  edited_at timestamptz,
  is_unsent boolean not null default false,
  constraint private_messages_distinct_users check (sender_id <> recipient_id)
);

create index if not exists private_messages_conversation_idx
  on public.private_messages (course_id, sender_id, recipient_id, created_at);
create index if not exists private_messages_unread_idx
  on public.private_messages (course_id, recipient_id, read_at)
  where read_at is null;

alter table public.private_messages enable row level security;

create or replace function private.is_course_member(
  target_course_id uuid,
  target_user_id uuid
)
returns boolean
language sql
stable
security definer
set search_path = pg_catalog, public
as $$
  select exists (
    select 1 from public.courses
    where id = target_course_id and instructor_id = target_user_id
  ) or exists (
    select 1 from public.enrollments
    where course_id = target_course_id and user_id = target_user_id
  );
$$;

revoke all on function private.is_course_member(uuid, uuid)
  from public, anon, authenticated;
grant execute on function private.is_course_member(uuid, uuid) to authenticated;

create policy "private messages: participants read"
  on public.private_messages for select to authenticated
  using (
    (sender_id = (select auth.uid()) or recipient_id = (select auth.uid()))
    and private.is_course_member(course_id, (select auth.uid()))
  );

create policy "private messages: course members send"
  on public.private_messages for insert to authenticated
  with check (
    sender_id = (select auth.uid())
    and private.is_course_member(course_id, sender_id)
    and private.is_course_member(course_id, recipient_id)
  );

create policy "private messages: recipient marks read"
  on public.private_messages for update to authenticated
  using (recipient_id = (select auth.uid()))
  with check (recipient_id = (select auth.uid()));

revoke update on public.private_messages from authenticated;
grant update (read_at) on public.private_messages to authenticated;

alter publication supabase_realtime add table public.private_messages;