alter table public.profiles
  add column if not exists signature_path text;

create or replace function public.set_my_signature_path(new_signature_path text)
returns jsonb
language plpgsql
security definer
set search_path = pg_catalog, public, auth
as $$
declare
  current_user_id uuid := auth.uid();
  updated_profile jsonb;
begin
  if current_user_id is null then
    raise exception 'Authentication is required';
  end if;

  update public.profiles as profile
  set
    signature_path = new_signature_path,
    updated_at = timezone('utc', now())
  where profile.id = current_user_id
  returning to_jsonb(profile) into updated_profile;

  if updated_profile is null then
    raise exception 'Profile not found';
  end if;

  return updated_profile;
end;
$$;

revoke all on function public.set_my_signature_path(text)
  from public, anon;
grant execute on function public.set_my_signature_path(text)
  to authenticated, service_role;

drop policy if exists "profiles: self read" on public.profiles;
create policy "profiles: self read"
  on public.profiles for select to authenticated
  using (id = (select auth.uid()));

drop policy if exists "profiles: self update" on public.profiles;
drop policy if exists "profiles update own" on public.profiles;
create policy "profiles: self update"
  on public.profiles for update to authenticated
  using (id = (select auth.uid()))
  with check (id = (select auth.uid()));

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values (
  'instructor-signatures',
  'instructor-signatures',
  false,
  1048576,
  array['image/png']
)
on conflict (id) do update set
  public = excluded.public,
  file_size_limit = excluded.file_size_limit,
  allowed_mime_types = excluded.allowed_mime_types;

drop policy if exists "signatures: user select" on storage.objects;
drop policy if exists "signatures: user insert" on storage.objects;
drop policy if exists "signatures: user update" on storage.objects;
drop policy if exists "signatures: user delete" on storage.objects;

create policy "signatures: user select"
  on storage.objects for select to authenticated
  using (
    bucket_id = 'instructor-signatures'
    and (storage.foldername(name))[1] = (select auth.uid()::text)
  );

create policy "signatures: user insert"
  on storage.objects for insert to authenticated
  with check (
    bucket_id = 'instructor-signatures'
    and (storage.foldername(name))[1] = (select auth.uid()::text)
  );

create policy "signatures: user update"
  on storage.objects for update to authenticated
  using (
    bucket_id = 'instructor-signatures'
    and (storage.foldername(name))[1] = (select auth.uid()::text)
  )
  with check (
    bucket_id = 'instructor-signatures'
    and (storage.foldername(name))[1] = (select auth.uid()::text)
  );

create policy "signatures: user delete"
  on storage.objects for delete to authenticated
  using (
    bucket_id = 'instructor-signatures'
    and (storage.foldername(name))[1] = (select auth.uid()::text)
  );