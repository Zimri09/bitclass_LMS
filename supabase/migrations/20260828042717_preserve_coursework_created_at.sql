create schema if not exists private;

create or replace function private.preserve_created_at()
returns trigger
language plpgsql
set search_path = pg_catalog
as $$
begin
  new.created_at = old.created_at;
  return new;
end;
$$;

comment on function private.preserve_created_at() is
  'Keeps the original row creation timestamp unchanged during updates.';

drop trigger if exists assignments_preserve_created_at
  on public.assignments;
create trigger assignments_preserve_created_at
before update of created_at on public.assignments
for each row execute function private.preserve_created_at();

drop trigger if exists quizzes_preserve_created_at
  on public.quizzes;
create trigger quizzes_preserve_created_at
before update of created_at on public.quizzes
for each row execute function private.preserve_created_at();
