-- Keep participant SELECT policies unchanged: readable, redacted tombstones
-- let Realtime deliver UPDATE events to both participants after an unsend.
alter table public.private_messages
  add column if not exists hidden_for_sender boolean not null default false;

-- Mutations need elevated UPDATE rights (clients may only update read_at).
-- Keep privileged implementations outside the exposed schema and check the
-- authenticated sender and course membership inside each mutation.
create or replace function private.hide_private_message(target_message_id uuid)
returns void
language plpgsql security definer
set search_path = ''
as $$
begin
  update public.private_messages
  set hidden_for_sender = true
  where id = target_message_id
    and sender_id = (select auth.uid())
    and private.is_course_member(course_id, (select auth.uid()));
  if not found then
    raise exception 'You can only unsend your own messages.' using errcode = '42501';
  end if;
end;
$$;

create or replace function public.hide_private_message(target_message_id uuid)
returns void
language sql security invoker
set search_path = ''
as $$ select private.hide_private_message(target_message_id); $$;

create or replace function private.unsend_private_message(target_message_id uuid)
returns setof public.private_messages
language plpgsql security definer
set search_path = ''
as $$
declare
  unsent public.private_messages;
begin
  update public.private_messages
  set body = 'Message unsent', is_unsent = true, edited_at = null,
      read_at = coalesce(read_at, now())
  where id = target_message_id
    and sender_id = (select auth.uid())
    and private.is_course_member(course_id, (select auth.uid()))
  returning * into unsent;
  if not found then
    raise exception 'You can only unsend your own messages.' using errcode = '42501';
  end if;

  -- Redact existing previews and clear unread notification badges atomically.
  -- UPDATE preserves notification history and delivers user-filtered realtime
  -- events; it does not dispatch a new push notification.
  update public.notifications
  set body = 'Message unsent', is_read = true
  where user_id = unsent.recipient_id
    and type = 'privateMessage'
    and data ->> 'message_id' = target_message_id::text;

  return next unsent;
end;
$$;

-- Preserve the existing RPC signature for older clients.
create or replace function public.unsend_private_message(target_message_id uuid)
returns setof public.private_messages
language sql security invoker
set search_path = ''
as $$ select * from private.unsend_private_message(target_message_id); $$;

revoke all on function private.hide_private_message(uuid) from public, anon;
revoke all on function public.hide_private_message(uuid) from public, anon;
revoke all on function private.unsend_private_message(uuid) from public, anon;
revoke all on function public.unsend_private_message(uuid) from public, anon;
grant execute on function private.hide_private_message(uuid) to authenticated;
grant execute on function public.hide_private_message(uuid) to authenticated;
grant execute on function private.unsend_private_message(uuid) to authenticated;
grant execute on function public.unsend_private_message(uuid) to authenticated;
