-- Keep each discussion channel badge aligned with its unresolved threads.
-- Safe to run more than once in the Supabase SQL editor.

create or replace function public.sync_discussion_thread_count()
returns trigger
language plpgsql
security definer
set search_path = pg_catalog, public
as $$
begin
  if tg_op = 'DELETE' then
    update public.discussion_channels as channel
    set thread_count = (
      select count(*)::integer
      from public.threads as thread
      where thread.channel_id = channel.id
        and not thread.is_resolved
    )
    where channel.id = old.channel_id;
    return old;
  end if;

  update public.discussion_channels as channel
  set
    thread_count = (
      select count(*)::integer
      from public.threads as thread
      where thread.channel_id = channel.id
        and not thread.is_resolved
    ),
    last_activity_at = case
      when tg_op = 'INSERT' then new.created_at
      else channel.last_activity_at
    end
  where channel.id = new.channel_id;

  if tg_op = 'UPDATE' and old.channel_id is distinct from new.channel_id then
    update public.discussion_channels as channel
    set thread_count = (
      select count(*)::integer
      from public.threads as thread
      where thread.channel_id = channel.id
        and not thread.is_resolved
    )
    where channel.id = old.channel_id;
  end if;

  return new;
end;
$$;

revoke all on function public.sync_discussion_thread_count()
from public, anon, authenticated;

drop trigger if exists threads_sync_channel_count on public.threads;
create trigger threads_sync_channel_count
after insert or delete on public.threads
for each row execute function public.sync_discussion_thread_count();

drop trigger if exists threads_sync_channel_count_on_status on public.threads;
create trigger threads_sync_channel_count_on_status
after update of is_resolved, channel_id on public.threads
for each row
when (
  old.is_resolved is distinct from new.is_resolved
  or old.channel_id is distinct from new.channel_id
)
execute function public.sync_discussion_thread_count();

update public.discussion_channels as channel
set thread_count = (
  select count(*)::integer
  from public.threads as thread
  where thread.channel_id = channel.id
    and not thread.is_resolved
);
