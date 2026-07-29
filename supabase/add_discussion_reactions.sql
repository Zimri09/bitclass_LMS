-- Add single-choice reactions to discussion threads and replies.
-- Existing likes are migrated to the "like" reaction.

alter table public.threads
  add column if not exists reaction_count integer not null default 0,
  add column if not exists reaction_counts jsonb not null default
    '{"like": 0, "haha": 0, "sad": 0, "heart": 0, "angry": 0}'::jsonb;

alter table public.replies
  add column if not exists reaction_count integer not null default 0,
  add column if not exists reaction_counts jsonb not null default
    '{"like": 0, "haha": 0, "sad": 0, "heart": 0, "angry": 0}'::jsonb;

create table if not exists public.thread_reactions (
  id uuid primary key default gen_random_uuid(),
  thread_id uuid not null references public.threads(id) on delete cascade,
  user_id uuid not null references public.profiles(id) on delete cascade,
  reaction text not null check (
    reaction in ('like', 'haha', 'sad', 'heart', 'angry')
  ),
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now()),
  unique (thread_id, user_id)
);

create table if not exists public.reply_reactions (
  id uuid primary key default gen_random_uuid(),
  reply_id uuid not null references public.replies(id) on delete cascade,
  user_id uuid not null references public.profiles(id) on delete cascade,
  reaction text not null check (
    reaction in ('like', 'haha', 'sad', 'heart', 'angry')
  ),
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now()),
  unique (reply_id, user_id)
);

drop trigger if exists thread_reactions_updated_at on public.thread_reactions;
create trigger thread_reactions_updated_at
before insert or update on public.thread_reactions
for each row execute function public.set_updated_at();

drop trigger if exists reply_reactions_updated_at on public.reply_reactions;
create trigger reply_reactions_updated_at
before insert or update on public.reply_reactions
for each row execute function public.set_updated_at();

create or replace function public.sync_thread_reaction_summary()
returns trigger
language plpgsql
security definer
set search_path = pg_catalog, public
as $$
declare
  target_thread_id uuid;
begin
  target_thread_id := case when tg_op = 'DELETE' then old.thread_id else new.thread_id end;

  update public.threads
  set
    reaction_count = summary.total,
    reaction_counts = summary.counts
  from (
    select
      count(*)::integer as total,
      jsonb_build_object(
        'like', count(*) filter (where reaction = 'like'),
        'haha', count(*) filter (where reaction = 'haha'),
        'sad', count(*) filter (where reaction = 'sad'),
        'heart', count(*) filter (where reaction = 'heart'),
        'angry', count(*) filter (where reaction = 'angry')
      ) as counts
    from public.thread_reactions
    where thread_id = target_thread_id
  ) as summary
  where id = target_thread_id;

  if tg_op = 'UPDATE' and old.thread_id is distinct from new.thread_id then
    update public.threads
    set
      reaction_count = summary.total,
      reaction_counts = summary.counts
    from (
      select
        count(*)::integer as total,
        jsonb_build_object(
          'like', count(*) filter (where reaction = 'like'),
          'haha', count(*) filter (where reaction = 'haha'),
          'sad', count(*) filter (where reaction = 'sad'),
          'heart', count(*) filter (where reaction = 'heart'),
          'angry', count(*) filter (where reaction = 'angry')
        ) as counts
      from public.thread_reactions
      where thread_id = old.thread_id
    ) as summary
    where id = old.thread_id;
  end if;

  if tg_op = 'DELETE' then
    return old;
  end if;
  return new;
end;
$$;

create or replace function public.sync_reply_reaction_summary()
returns trigger
language plpgsql
security definer
set search_path = pg_catalog, public
as $$
declare
  target_reply_id uuid;
begin
  target_reply_id := case when tg_op = 'DELETE' then old.reply_id else new.reply_id end;

  update public.replies
  set
    reaction_count = summary.total,
    reaction_counts = summary.counts
  from (
    select
      count(*)::integer as total,
      jsonb_build_object(
        'like', count(*) filter (where reaction = 'like'),
        'haha', count(*) filter (where reaction = 'haha'),
        'sad', count(*) filter (where reaction = 'sad'),
        'heart', count(*) filter (where reaction = 'heart'),
        'angry', count(*) filter (where reaction = 'angry')
      ) as counts
    from public.reply_reactions
    where reply_id = target_reply_id
  ) as summary
  where id = target_reply_id;

  if tg_op = 'UPDATE' and old.reply_id is distinct from new.reply_id then
    update public.replies
    set
      reaction_count = summary.total,
      reaction_counts = summary.counts
    from (
      select
        count(*)::integer as total,
        jsonb_build_object(
          'like', count(*) filter (where reaction = 'like'),
          'haha', count(*) filter (where reaction = 'haha'),
          'sad', count(*) filter (where reaction = 'sad'),
          'heart', count(*) filter (where reaction = 'heart'),
          'angry', count(*) filter (where reaction = 'angry')
        ) as counts
      from public.reply_reactions
      where reply_id = old.reply_id
    ) as summary
    where id = old.reply_id;
  end if;

  if tg_op = 'DELETE' then
    return old;
  end if;
  return new;
end;
$$;

revoke all on function public.sync_thread_reaction_summary()
from public, anon, authenticated;
revoke all on function public.sync_reply_reaction_summary()
from public, anon, authenticated;

drop trigger if exists thread_reactions_sync_summary
on public.thread_reactions;
create trigger thread_reactions_sync_summary
after insert or update or delete on public.thread_reactions
for each row execute function public.sync_thread_reaction_summary();

drop trigger if exists reply_reactions_sync_summary
on public.reply_reactions;
create trigger reply_reactions_sync_summary
after insert or update or delete on public.reply_reactions
for each row execute function public.sync_reply_reaction_summary();

insert into public.thread_reactions (thread_id, user_id, reaction)
select thread_likes.thread_id, thread_likes.user_id, 'like'
from public.thread_likes
on conflict (thread_id, user_id) do nothing;

insert into public.thread_reactions (thread_id, user_id, reaction)
select threads.id, profiles.id, 'like'
from public.threads
cross join lateral jsonb_array_elements_text(threads.liked_by) as liked(user_id)
join public.profiles on profiles.id::text = liked.user_id
on conflict (thread_id, user_id) do nothing;

insert into public.reply_reactions (reply_id, user_id, reaction)
select replies.id, profiles.id, 'like'
from public.replies
cross join lateral jsonb_array_elements_text(replies.liked_by) as liked(user_id)
join public.profiles on profiles.id::text = liked.user_id
on conflict (reply_id, user_id) do nothing;

update public.threads
set
  reaction_count = summary.total,
  reaction_counts = summary.counts
from (
  select
    threads.id,
    count(thread_reactions.id)::integer as total,
    jsonb_build_object(
      'like', count(thread_reactions.id) filter (where reaction = 'like'),
      'haha', count(thread_reactions.id) filter (where reaction = 'haha'),
      'sad', count(thread_reactions.id) filter (where reaction = 'sad'),
      'heart', count(thread_reactions.id) filter (where reaction = 'heart'),
      'angry', count(thread_reactions.id) filter (where reaction = 'angry')
    ) as counts
  from public.threads
  left join public.thread_reactions
    on thread_reactions.thread_id = threads.id
  group by threads.id
) as summary
where threads.id = summary.id;

update public.replies
set
  reaction_count = summary.total,
  reaction_counts = summary.counts
from (
  select
    replies.id,
    count(reply_reactions.id)::integer as total,
    jsonb_build_object(
      'like', count(reply_reactions.id) filter (where reaction = 'like'),
      'haha', count(reply_reactions.id) filter (where reaction = 'haha'),
      'sad', count(reply_reactions.id) filter (where reaction = 'sad'),
      'heart', count(reply_reactions.id) filter (where reaction = 'heart'),
      'angry', count(reply_reactions.id) filter (where reaction = 'angry')
    ) as counts
  from public.replies
  left join public.reply_reactions
    on reply_reactions.reply_id = replies.id
  group by replies.id
) as summary
where replies.id = summary.id;

alter table public.thread_reactions enable row level security;
alter table public.reply_reactions enable row level security;

drop policy if exists "thread reactions read own"
on public.thread_reactions;
drop policy if exists "thread reactions create own"
on public.thread_reactions;
drop policy if exists "thread reactions update own"
on public.thread_reactions;
drop policy if exists "thread reactions delete own"
on public.thread_reactions;

create policy "thread reactions read own"
  on public.thread_reactions for select to authenticated
  using (user_id = (select auth.uid()));
create policy "thread reactions create own"
  on public.thread_reactions for insert to authenticated
  with check (
    user_id = (select auth.uid())
    and exists (
      select 1 from public.threads
      where threads.id = thread_reactions.thread_id
        and (select private.is_course_member(threads.course_id))
    )
  );
create policy "thread reactions update own"
  on public.thread_reactions for update to authenticated
  using (user_id = (select auth.uid()))
  with check (
    user_id = (select auth.uid())
    and exists (
      select 1 from public.threads
      where threads.id = thread_reactions.thread_id
        and (select private.is_course_member(threads.course_id))
    )
  );
create policy "thread reactions delete own"
  on public.thread_reactions for delete to authenticated
  using (user_id = (select auth.uid()));

drop policy if exists "reply reactions read own"
on public.reply_reactions;
drop policy if exists "reply reactions create own"
on public.reply_reactions;
drop policy if exists "reply reactions update own"
on public.reply_reactions;
drop policy if exists "reply reactions delete own"
on public.reply_reactions;

create policy "reply reactions read own"
  on public.reply_reactions for select to authenticated
  using (user_id = (select auth.uid()));
create policy "reply reactions create own"
  on public.reply_reactions for insert to authenticated
  with check (
    user_id = (select auth.uid())
    and exists (
      select 1 from public.replies
      where replies.id = reply_reactions.reply_id
        and (select private.is_course_member(replies.course_id))
    )
  );
create policy "reply reactions update own"
  on public.reply_reactions for update to authenticated
  using (user_id = (select auth.uid()))
  with check (
    user_id = (select auth.uid())
    and exists (
      select 1 from public.replies
      where replies.id = reply_reactions.reply_id
        and (select private.is_course_member(replies.course_id))
    )
  );
create policy "reply reactions delete own"
  on public.reply_reactions for delete to authenticated
  using (user_id = (select auth.uid()));

revoke all on public.thread_reactions from anon;
revoke all on public.reply_reactions from anon;
grant select, insert, update, delete on public.thread_reactions
to authenticated;
grant select, insert, update, delete on public.reply_reactions
to authenticated;
grant all on public.thread_reactions to service_role;
grant all on public.reply_reactions to service_role;
