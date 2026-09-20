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

create table if not exists public.hidden_private_conversations (
	user_id uuid not null references public.profiles(id) on delete cascade,
	course_id uuid not null references public.courses(id) on delete cascade,
	participant_id uuid not null references public.profiles(id) on delete cascade,
	hidden_at timestamptz not null default timezone('utc', now()),
	primary key (user_id, course_id, participant_id),
	constraint hidden_private_conversations_distinct_users
		check (user_id <> participant_id)
);

alter table public.hidden_private_conversations enable row level security;

create policy "hidden private conversations: own rows"
	on public.hidden_private_conversations for select to authenticated
	using (user_id = (select auth.uid()));

create policy "hidden private conversations: hide own"
	on public.hidden_private_conversations for insert to authenticated
	with check (user_id = (select auth.uid()));

create policy "hidden private conversations: update own"
	on public.hidden_private_conversations for update to authenticated
	using (user_id = (select auth.uid()))
	with check (user_id = (select auth.uid()));

create or replace function public.hide_private_conversation(
	target_course_id uuid,
	target_participant_id uuid
)
returns timestamptz
language plpgsql
security invoker
set search_path = pg_catalog, public, private
as $$
declare
	server_hidden_at timestamptz := timezone('utc', now());
begin
	if not private.is_course_member(target_course_id, (select auth.uid()))
		 or not private.is_course_member(target_course_id, target_participant_id) then
		raise exception 'Conversation participants must belong to the same course.';
	end if;

	insert into public.hidden_private_conversations (
		user_id, course_id, participant_id, hidden_at
	) values (
		(select auth.uid()), target_course_id, target_participant_id, server_hidden_at
	)
	on conflict (user_id, course_id, participant_id)
	do update set hidden_at = excluded.hidden_at;

	return server_hidden_at;
end;
$$;

revoke all on function public.hide_private_conversation(uuid, uuid)
	from public, anon;
grant execute on function public.hide_private_conversation(uuid, uuid)
	to authenticated;
