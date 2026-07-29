-- =============================================================================
-- Profile avatar storage for BitClass LMS
-- Run this once in the Supabase SQL Editor.
-- =============================================================================

-- Public delivery lets profile photos render anywhere the user's name appears.
-- Only each authenticated user can create, replace, or delete objects in their
-- own <user-id>/ folder.
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values (
  'avatars',
  'avatars',
  true,
  5242880,
  array['image/jpeg']
)
on conflict (id) do update set
  public = excluded.public,
  file_size_limit = excluded.file_size_limit,
  allowed_mime_types = excluded.allowed_mime_types;

drop policy if exists "avatars: public read" on storage.objects;
drop policy if exists "avatars: user insert" on storage.objects;
drop policy if exists "avatars: user update" on storage.objects;
drop policy if exists "avatars: user delete" on storage.objects;

create policy "avatars: public read"
  on storage.objects for select
  using (bucket_id = 'avatars');

create policy "avatars: user insert"
  on storage.objects for insert
  to authenticated
  with check (
    bucket_id = 'avatars'
    and (storage.foldername(name))[1] = (select auth.uid()::text)
  );

create policy "avatars: user update"
  on storage.objects for update
  to authenticated
  using (
    bucket_id = 'avatars'
    and (storage.foldername(name))[1] = (select auth.uid()::text)
  )
  with check (
    bucket_id = 'avatars'
    and (storage.foldername(name))[1] = (select auth.uid()::text)
  );

create policy "avatars: user delete"
  on storage.objects for delete
  to authenticated
  using (
    bucket_id = 'avatars'
    and (storage.foldername(name))[1] = (select auth.uid()::text)
  );
