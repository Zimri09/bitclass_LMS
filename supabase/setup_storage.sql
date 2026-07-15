-- =============================================================================
-- Supabase Storage Setup for BitClass LMS
-- =============================================================================
-- Run this entire script in the Supabase SQL Editor (Dashboard → SQL Editor)
-- in ONE execution. It is safe to re-run (all statements use IF NOT EXISTS /
-- OR REPLACE / ON CONFLICT DO NOTHING).
-- =============================================================================

-- ─────────────────────────────────────────────────────────────────────────────
-- 1. FILES TABLE  (public database table that tracks uploaded files)
-- ─────────────────────────────────────────────────────────────────────────────

create table if not exists public.files (
  id            text        primary key,
  course_id     uuid        not null references public.courses(id) on delete cascade,
  lesson_id     uuid        references public.lessons(id) on delete set null,
  uploader_id   uuid        not null references public.profiles(id) on delete cascade,
  uploader_name text        not null,
  name          text        not null,
  description   text        not null default '',
  bucket        text        not null default 'bitclass_storage',
  storage_path  text        not null,
  public_url    text        not null,
  thumbnail_url text,
  file_type     file_type   not null default 'other',
  mime_type     text        not null default 'application/octet-stream',
  size_bytes    bigint      not null default 0,
  download_count integer    not null default 0,
  created_at    timestamptz not null default timezone('utc', now()),
  updated_at    timestamptz not null default timezone('utc', now())
);

create index if not exists files_course_idx    on public.files (course_id);
create index if not exists files_lesson_idx    on public.files (lesson_id);
create index if not exists files_uploader_idx  on public.files (uploader_id);
create index if not exists files_created_idx   on public.files (created_at desc);

drop trigger if exists files_updated_at on public.files;
create trigger files_updated_at
  before update on public.files
  for each row execute function public.set_updated_at();

-- ─────────────────────────────────────────────────────────────────────────────
-- 2. STORAGE BUCKET  ('materials')
-- ─────────────────────────────────────────────────────────────────────────────

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values (
  'bitclass_storage',
  'bitclass_storage',
  true,
  104857600,   -- 100 MB
  array[
    'application/pdf',
    'application/msword',
    'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
    'application/vnd.ms-powerpoint',
    'application/vnd.openxmlformats-officedocument.presentationml.presentation',
    'application/vnd.ms-excel',
    'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
    'text/plain','text/markdown','text/csv','text/html','text/css',
    'text/x-dart','text/x-python','text/typescript',
    'application/javascript','application/json','application/xml','application/yaml',
    'image/png','image/jpeg','image/gif','image/webp','image/svg+xml','image/bmp',
    'video/mp4','video/webm','video/x-msvideo','video/quicktime','video/x-matroska',
    'audio/mpeg','audio/wav','audio/ogg','audio/aac',
    'application/zip','application/gzip','application/x-tar',
    'application/x-rar-compressed','application/x-7z-compressed',
    'application/octet-stream'
  ]
)
on conflict (id) do update set
  public             = excluded.public,
  file_size_limit    = excluded.file_size_limit,
  allowed_mime_types = excluded.allowed_mime_types;

-- ─────────────────────────────────────────────────────────────────────────────
-- 3. STORAGE OBJECT RLS POLICIES
-- ─────────────────────────────────────────────────────────────────────────────

drop policy if exists "bitclass_storage: public read"          on storage.objects;
drop policy if exists "bitclass_storage: authenticated upload" on storage.objects;
drop policy if exists "bitclass_storage: owner delete"         on storage.objects;
drop policy if exists "bitclass_storage: owner update"         on storage.objects;

-- Anyone can download (bucket is public)
create policy "bitclass_storage: public read"
  on storage.objects for select
  using ( bucket_id = 'bitclass_storage' );

-- Any authenticated user can upload
create policy "bitclass_storage: authenticated upload"
  on storage.objects for insert
  to authenticated
  with check ( bucket_id = 'bitclass_storage' );

-- Only uploader or admin can delete
create policy "bitclass_storage: owner delete"
  on storage.objects for delete
  to authenticated
  using (
    bucket_id = 'bitclass_storage'
    and (
      owner = auth.uid()
      or exists (
        select 1 from public.profiles
        where id = auth.uid() and role = 'admin'
      )
    )
  );

-- Only uploader or admin can update/replace
create policy "bitclass_storage: owner update"
  on storage.objects for update
  to authenticated
  using (
    bucket_id = 'bitclass_storage'
    and (
      owner = auth.uid()
      or exists (
        select 1 from public.profiles
        where id = auth.uid() and role = 'admin'
      )
    )
  );

-- ─────────────────────────────────────────────────────────────────────────────
-- 4. FILES TABLE RLS POLICIES
-- ─────────────────────────────────────────────────────────────────────────────

alter table public.files enable row level security;

drop policy if exists "files: enrolled can read"   on public.files;
drop policy if exists "files: authenticated insert" on public.files;
drop policy if exists "files: owner update"         on public.files;
drop policy if exists "files: owner delete"         on public.files;

-- Read: course instructor, enrolled student, or admin
create policy "files: enrolled can read"
  on public.files for select
  to authenticated
  using (
    exists (
      select 1 from public.courses c
      where c.id = files.course_id and c.instructor_id = auth.uid()
    )
    or exists (
      select 1 from public.enrollments e
      where e.course_id = files.course_id and e.user_id = auth.uid()
    )
    or exists (
      select 1 from public.profiles p
      where p.id = auth.uid() and p.role = 'admin'
    )
  );

-- Insert: uploader must be the authenticated user
create policy "files: authenticated insert"
  on public.files for insert
  to authenticated
  with check ( uploader_id = auth.uid() );

-- Update: uploader or admin
create policy "files: owner update"
  on public.files for update
  to authenticated
  using (
    uploader_id = auth.uid()
    or exists (
      select 1 from public.profiles p
      where p.id = auth.uid() and p.role = 'admin'
    )
  );

-- Delete: uploader or admin
create policy "files: owner delete"
  on public.files for delete
  to authenticated
  using (
    uploader_id = auth.uid()
    or exists (
      select 1 from public.profiles p
      where p.id = auth.uid() and p.role = 'admin'
    )
  );

-- ─────────────────────────────────────────────────────────────────────────────
-- Verify:
--   select * from storage.buckets where id = 'bitclass_storage';
--   select tablename from pg_tables where schemaname='public' and tablename='files';
--   select policyname from pg_policies where schemaname='storage' and tablename='objects';
--   select policyname from pg_policies where schemaname='public'  and tablename='files';
-- ─────────────────────────────────────────────────────────────────────────────
