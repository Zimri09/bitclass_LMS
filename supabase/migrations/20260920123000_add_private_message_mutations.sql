alter table public.private_messages
	add column if not exists edited_at timestamptz,
	add column if not exists is_unsent boolean not null default false;

create or replace function public.can_modify_private_message(target_message_id uuid)
returns boolean
language sql
stable
security definer
set search_path = pg_catalog, public, private
as $$
	select exists (
		select 1
		from public.private_messages
		where id = target_message_id
			and sender_id = (select auth.uid())
			and created_at >= timezone('utc', now()) - interval '15 minutes'
			and not is_unsent
	);
$$;

create or replace function public.edit_private_message(
	target_message_id uuid,
	new_body text
)
returns setof public.private_messages
language plpgsql
security definer
set search_path = pg_catalog, public, private
as $$
begin
	if new_body is null or char_length(trim(new_body)) not between 1 and 4000 then
		raise exception 'Message cannot be empty or exceed 4000 characters.';
	end if;

	update public.private_messages
	set body = trim(new_body), edited_at = timezone('utc', now())
	where id = target_message_id
		and sender_id = (select auth.uid())
		and created_at >= timezone('utc', now()) - interval '15 minutes'
		and not is_unsent;

	if not found then
		raise exception 'Message can no longer be edited.';
	end if;

	return query
		select * from public.private_messages where id = target_message_id;
end;
$$;

create or replace function public.unsend_private_message(target_message_id uuid)
returns setof public.private_messages
language plpgsql
security definer
set search_path = pg_catalog, public, private
as $$
begin
	update public.private_messages
	set body = 'Message unsent', is_unsent = true, edited_at = null
	where id = target_message_id
		and sender_id = (select auth.uid())
		and created_at >= timezone('utc', now()) - interval '15 minutes'
		and not is_unsent;

	if not found then
		raise exception 'Message can no longer be unsent.';
	end if;

	return query
		select * from public.private_messages where id = target_message_id;
end;
$$;

revoke all on function public.can_modify_private_message(uuid) from public, anon;
revoke all on function public.edit_private_message(uuid, text) from public, anon;
revoke all on function public.unsend_private_message(uuid) from public, anon;
grant execute on function public.can_modify_private_message(uuid) to authenticated;
grant execute on function public.edit_private_message(uuid, text) to authenticated;
grant execute on function public.unsend_private_message(uuid) to authenticated;
