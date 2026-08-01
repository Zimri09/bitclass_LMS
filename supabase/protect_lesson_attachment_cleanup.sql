-- Prevent lesson deletion from silently detaching file metadata while leaving
-- the corresponding object in Supabase Storage. The app removes Storage
-- objects through the Storage API before deleting these rows and the lesson.

begin;

alter table public.files
  drop constraint if exists files_lesson_id_fkey;

alter table public.files
  add constraint files_lesson_id_fkey
  foreign key (lesson_id)
  references public.lessons(id)
  on delete restrict;

commit;

-- Verification query:
-- select conname, pg_get_constraintdef(oid)
-- from pg_constraint
-- where conrelid = 'public.files'::regclass
--   and conname = 'files_lesson_id_fkey';
