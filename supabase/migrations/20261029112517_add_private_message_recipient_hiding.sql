-- Keep the shared message readable to Realtime; each client filters only its
-- own visibility flag. Sender hiding and unsend behavior are unchanged.
alter table public.private_messages
  add column hidden_for_recipient boolean not null default false;

-- A sender must not hide a new message on behalf of its recipient.
create function private.initialize_private_message_recipient_visibility()
returns trigger language plpgsql set search_path = '' as $$
begin
  new.hidden_for_recipient := false;
  return new;
end;
$$;
create trigger initialize_private_message_recipient_visibility
before insert on public.private_messages
for each row execute function private.initialize_private_message_recipient_visibility();

-- Direct client UPDATE remains restricted to read_at. This privileged function
-- checks the authenticated recipient and course membership before updating.
create function private.hide_received_private_message(target_message_id uuid)
returns void language plpgsql security definer set search_path = '' as $$
begin
  update public.private_messages
  set hidden_for_recipient = true
  where id = target_message_id
    and recipient_id = (select auth.uid())
    and not is_unsent
    and private.is_course_member(course_id, (select auth.uid()));
  if not found then
    raise exception 'You can only hide received messages.' using errcode = '42501';
  end if;
end;
$$;
create function public.hide_received_private_message(target_message_id uuid)
returns void language sql security invoker set search_path = '' as $$
  select private.hide_received_private_message(target_message_id);
$$;
revoke all on function private.initialize_private_message_recipient_visibility() from public, anon, authenticated;
revoke all on function private.hide_received_private_message(uuid) from public, anon;
revoke all on function public.hide_received_private_message(uuid) from public, anon;
grant execute on function private.hide_received_private_message(uuid) to authenticated;
grant execute on function public.hide_received_private_message(uuid) to authenticated;
