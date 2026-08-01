-- Keep discussion author names and avatars synchronized with profiles.
-- Threads and replies remain readable through their existing course RLS policies;
-- clients do not need broad SELECT access to the profiles table.

create or replace function private.discussion_profile_display_name(
  profile_row public.profiles
)
returns text
language sql
stable
set search_path = public, pg_temp
as $$
  select coalesce(
    nullif(trim(concat_ws(' ', profile_row.first_name, profile_row.last_name)), ''),
    nullif(trim(profile_row.display_name), ''),
    nullif(trim(profile_row.email), ''),
    'User'
  );
$$;

create or replace function private.set_discussion_author_profile()
returns trigger
language plpgsql
set search_path = ''
as $$
declare
  author_profile public.profiles;
begin
  select profile_row.*
  into author_profile
  from public.profiles profile_row
  where profile_row.id = new.author_id;

  if not found then
    raise exception 'Discussion author profile was not found.';
  end if;

  new.author_name := private.discussion_profile_display_name(author_profile);
  new.author_avatar_url := author_profile.avatar_url;
  return new;
end;
$$;

drop trigger if exists threads_set_author_profile on public.threads;
create trigger threads_set_author_profile
  before insert or update of author_id on public.threads
  for each row
  execute function private.set_discussion_author_profile();

drop trigger if exists replies_set_author_profile on public.replies;
create trigger replies_set_author_profile
  before insert or update of author_id on public.replies
  for each row
  execute function private.set_discussion_author_profile();

create or replace function private.sync_discussion_authors_from_profile()
returns trigger
language plpgsql
set search_path = ''
as $$
declare
  current_name text;
begin
  current_name := private.discussion_profile_display_name(new);

  update public.threads
  set
    author_name = current_name,
    author_avatar_url = new.avatar_url
  where author_id = new.id
    and (
      author_name is distinct from current_name
      or author_avatar_url is distinct from new.avatar_url
    );

  update public.replies
  set
    author_name = current_name,
    author_avatar_url = new.avatar_url
  where author_id = new.id
    and (
      author_name is distinct from current_name
      or author_avatar_url is distinct from new.avatar_url
    );

  return new;
end;
$$;

drop trigger if exists profiles_sync_discussion_authors on public.profiles;
create trigger profiles_sync_discussion_authors
  after update of first_name, last_name, display_name, avatar_url
  on public.profiles
  for each row
  execute function private.sync_discussion_authors_from_profile();

-- Backfill all existing discussions and replies with the latest profile data.
update public.threads thread_row
set
  author_name = private.discussion_profile_display_name(profile_row),
  author_avatar_url = profile_row.avatar_url
from public.profiles profile_row
where profile_row.id = thread_row.author_id
  and (
    thread_row.author_name is distinct from
      private.discussion_profile_display_name(profile_row)
    or thread_row.author_avatar_url is distinct from profile_row.avatar_url
  );

update public.replies reply_row
set
  author_name = private.discussion_profile_display_name(profile_row),
  author_avatar_url = profile_row.avatar_url
from public.profiles profile_row
where profile_row.id = reply_row.author_id
  and (
    reply_row.author_name is distinct from
      private.discussion_profile_display_name(profile_row)
    or reply_row.author_avatar_url is distinct from profile_row.avatar_url
  );
