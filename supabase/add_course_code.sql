-- Add the course code used by course creation and join-by-code flows.
-- Safe to run on existing projects.

alter table public.courses
  add column if not exists course_code text;

create unique index if not exists courses_course_code_unique_idx
  on public.courses (course_code)
  where course_code is not null;

-- Existing courses do not need a code until an instructor assigns one.
-- New courses receive a generated uppercase code from CourseRepository.
