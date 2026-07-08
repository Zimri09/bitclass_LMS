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

create trigger todos_updated_at
before update on public.todos
for each row execute function public.set_updated_at();

-- RLS
alter table public.todos enable row level security;

-- Users can read their own todos
create policy "todos read own" on public.todos
  for select using (user_id = auth.uid());

-- Users can update their own todos
create policy "todos update own" on public.todos
  for update using (user_id = auth.uid())
  with check (user_id = auth.uid());

