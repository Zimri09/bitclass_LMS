-- Prevent null discussion timestamps from bypassing the column defaults.
create or replace function public.set_updated_at()
returns trigger
language plpgsql
set search_path = pg_catalog
as $$
begin
  new.updated_at = timezone('utc', now());
  return new;
end;
$$;

drop trigger if exists threads_updated_at on public.threads;
create trigger threads_updated_at
before insert or update on public.threads
for each row execute function public.set_updated_at();

drop trigger if exists replies_updated_at on public.replies;
create trigger replies_updated_at
before insert or update on public.replies
for each row execute function public.set_updated_at();
