create table if not exists public.support_requests (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  request_type text not null check (request_type in ('feedback', 'bug')),
  category text not null check (char_length(category) between 1 and 80),
  subject text not null check (char_length(subject) between 3 and 160),
  description text not null check (char_length(description) between 10 and 5000),
  metadata jsonb not null default '{}'::jsonb
    check (jsonb_typeof(metadata) = 'object'),
  status text not null default 'open'
    check (status in ('open', 'in_review', 'resolved', 'closed')),
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now())
);

create index if not exists support_requests_user_created_idx
  on public.support_requests (user_id, created_at desc);

drop trigger if exists support_requests_updated_at on public.support_requests;
create trigger support_requests_updated_at
before update on public.support_requests
for each row execute function public.set_updated_at();

alter table public.support_requests enable row level security;

drop policy if exists "support requests: users create own"
  on public.support_requests;
create policy "support requests: users create own"
  on public.support_requests for insert to authenticated
  with check (
    user_id = (select auth.uid())
    and status = 'open'
  );

drop policy if exists "support requests: users view own"
  on public.support_requests;
create policy "support requests: users view own"
  on public.support_requests for select to authenticated
  using (user_id = (select auth.uid()));

revoke all on table public.support_requests from anon;
revoke update, delete on table public.support_requests from authenticated;
grant select, insert on table public.support_requests to authenticated;
