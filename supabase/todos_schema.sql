-- Todos table for BitClass
-- Matches lib/features/todos/data/* expectations

create table if not exists public.todos (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  name text not null,
  is_completed boolean not null default false,
  due_at timestamptz,
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now())
);

drop trigger if exists todos_updated_at on public.todos;
create trigger todos_updated_at
before update on public.todos
for each row execute function public.set_updated_at();

-- RLS
alter table public.todos enable row level security;

-- Users can read their own todos
drop policy if exists "todos read own" on public.todos;
create policy "todos read own" on public.todos
  for select using (user_id = auth.uid());

-- Users can update their own todos
drop policy if exists "todos update own" on public.todos;
create policy "todos update own" on public.todos
  for update using (user_id = auth.uid())
  with check (user_id = auth.uid());

-- Users can insert their own todos (adding this for completeness if needed)
drop policy if exists "todos insert own" on public.todos;
create policy "todos insert own" on public.todos
  for insert with check (user_id = auth.uid());

-- Users can delete their own todos
drop policy if exists "todos delete own" on public.todos;
create policy "todos delete own" on public.todos
  for delete using (user_id = auth.uid());

