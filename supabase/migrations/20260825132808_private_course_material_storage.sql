-- Store course learning materials separately from public course thumbnails.
-- Signed URLs still pass through this SELECT policy before they are issued.

insert into storage.buckets (
  id,
  name,
  public,
  file_size_limit,
  allowed_mime_types
)
values (
  'course_materials',
  'course_materials',
  false,
  52428800,
  array[
    'application/pdf',
    'application/msword',
    'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
    'application/vnd.ms-powerpoint',
    'application/vnd.openxmlformats-officedocument.presentationml.presentation',
    'application/vnd.ms-excel',
    'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
    'text/plain', 'text/markdown', 'text/csv', 'text/html', 'text/css',
    'text/x-dart', 'text/x-python', 'text/typescript',
    'application/javascript', 'application/json', 'application/xml',
    'application/yaml',
    'image/png', 'image/jpeg', 'image/gif', 'image/webp', 'image/svg+xml',
    'image/bmp',
    'video/mp4', 'video/webm', 'video/x-msvideo', 'video/quicktime',
    'video/x-matroska',
    'audio/mpeg', 'audio/wav', 'audio/ogg', 'audio/aac',
    'application/zip', 'application/gzip', 'application/x-tar',
    'application/x-rar-compressed', 'application/x-7z-compressed',
    'application/octet-stream'
  ]
)
on conflict (id) do update set
  public = excluded.public,
  file_size_limit = excluded.file_size_limit,
  allowed_mime_types = excluded.allowed_mime_types;

drop policy if exists "course materials: authorized read" on storage.objects;
drop policy if exists "course materials: manager upload" on storage.objects;
drop policy if exists "course materials: manager update" on storage.objects;
drop policy if exists "course materials: manager delete" on storage.objects;

create policy "course materials: authorized read"
  on storage.objects for select to authenticated
  using (
    bucket_id = 'course_materials'
    and exists (
      select 1
      from public.courses as course
      where course.id::text = (storage.foldername(name))[1]
        and (select private.is_course_member(course.id))
    )
  );

create policy "course materials: manager upload"
  on storage.objects for insert to authenticated
  with check (
    bucket_id = 'course_materials'
    and exists (
      select 1
      from public.courses as course
      where course.id::text = (storage.foldername(name))[1]
        and (select private.can_manage_course(course.id))
    )
  );

create policy "course materials: manager update"
  on storage.objects for update to authenticated
  using (
    bucket_id = 'course_materials'
    and exists (
      select 1
      from public.courses as course
      where course.id::text = (storage.foldername(name))[1]
        and (select private.can_manage_course(course.id))
    )
  )
  with check (
    bucket_id = 'course_materials'
    and exists (
      select 1
      from public.courses as course
      where course.id::text = (storage.foldername(name))[1]
        and (select private.can_manage_course(course.id))
    )
  );

create policy "course materials: manager delete"
  on storage.objects for delete to authenticated
  using (
    bucket_id = 'course_materials'
    and exists (
      select 1
      from public.courses as course
      where course.id::text = (storage.foldername(name))[1]
        and (select private.can_manage_course(course.id))
    )
  );
