-- Stored on the message so the existing participant-only Realtime subscription
-- delivers additions, changes and removals without a separate DELETE stream.
alter table public.private_messages
  add column sender_reaction text check (sender_reaction in ('haha', 'sad', 'angry', 'heart')),
  add column recipient_reaction text check (recipient_reaction in ('haha', 'sad', 'angry', 'heart'));

-- Prevent clients from supplying someone else's reaction when sending a message.
create function private.initialize_private_message_reactions()
returns trigger language plpgsql set search_path = '' as $$
begin
  new.sender_reaction := null;
  new.recipient_reaction := null;
  return new;
end;
$$;
create trigger initialize_private_message_reactions
before insert on public.private_messages
for each row execute function private.initialize_private_message_reactions();

-- Existing direct UPDATE grants remain limited to read_at. The privileged
-- mutation checks membership and changes only the authenticated user's slot.
create function private.set_private_message_reaction(target_message_id uuid, new_reaction text)
returns void language plpgsql security definer set search_path = '' as $$
declare actor uuid := (select auth.uid());
begin
  if actor is null then
    raise exception 'Sign in to react.' using errcode = '42501';
  end if;
  if new_reaction is not null and new_reaction not in ('haha', 'sad', 'angry', 'heart') then
    raise exception 'Invalid reaction.' using errcode = '22023';
  end if;
  update public.private_messages
  set sender_reaction = case when sender_id = actor then new_reaction else sender_reaction end,
      recipient_reaction = case when recipient_id = actor then new_reaction else recipient_reaction end
  where id = target_message_id and not is_unsent
    and actor in (sender_id, recipient_id)
    and not (sender_id = actor and hidden_for_sender)
    and private.is_course_member(course_id, actor);
  if not found then
    raise exception 'Message unavailable for reactions.' using errcode = '42501';
  end if;
end;
$$;

create function public.set_private_message_reaction(target_message_id uuid, new_reaction text)
returns void language sql security invoker set search_path = '' as $$
  select private.set_private_message_reaction(target_message_id, new_reaction);
$$;
revoke all on function private.initialize_private_message_reactions() from public, anon, authenticated;
revoke all on function private.set_private_message_reaction(uuid, text) from public, anon;
revoke all on function public.set_private_message_reaction(uuid, text) from public, anon;
grant execute on function private.set_private_message_reaction(uuid, text) to authenticated;
grant execute on function public.set_private_message_reaction(uuid, text) to authenticated;
