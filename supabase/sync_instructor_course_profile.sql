-- =============================================================================
-- Keep instructor information on course banners synchronized with profiles.
-- Run once in the Supabase SQL Editor.
-- =============================================================================

-- These fields are used by the Flutter profile screen and may not exist in
-- projects created from an older BitClass schema.
alter table public.profiles
  add column if not exists first_name text,
  add column if not exists last_name text;

alter table public.courses
  add column if not exists instructor_avatar_url text;

create schema if not exists private;
revoke all on schema private from public;

create or replace function private.profile_display_name(profile_row public.profiles)
returns text
language sql
stable
set search_path = public, pg_temp
as $$
  select coalesce(
    nullif(trim(concat_ws(' ', profile_row.first_name, profile_row.last_name)), ''),
    nullif(trim(profile_row.display_name), ''),
    'Instructor'
  );
$$;

-- Never trust the client-provided instructor name or avatar during creation.
create or replace function private.set_course_instructor_profile()
returns trigger
language plpgsql
set search_path = public, private, pg_temp
as $$
declare
  instructor_profile public.profiles;
begin
  select * into instructor_profile
  from public.profiles
  where id = new.instructor_id;

  if not found then
    raise exception 'Instructor profile not found';
  end if;

  new.instructor_name := private.profile_display_name(instructor_profile);
  new.instructor_avatar_url := instructor_profile.avatar_url;
  return new;
end;
$$;

drop trigger if exists courses_set_instructor_profile on public.courses;
create trigger courses_set_instructor_profile
  before insert or update of instructor_id on public.courses
  for each row execute function private.set_course_instructor_profile();

-- Profile edits update every existing course owned by that instructor.
create or replace function private.sync_instructor_courses_from_profile()
returns trigger
language plpgsql
set search_path = public, private, pg_temp
as $$
begin
  update public.courses
  set
    instructor_name = private.profile_display_name(new),
    instructor_avatar_url = new.avatar_url,
    updated_at = timezone('utc', now())
  where instructor_id = new.id
    and (
      instructor_name is distinct from private.profile_display_name(new)
      or instructor_avatar_url is distinct from new.avatar_url
    );

  return new;
end;
$$;

drop trigger if exists profiles_sync_instructor_courses on public.profiles;
create trigger profiles_sync_instructor_courses
  after update of first_name, last_name, display_name, avatar_url on public.profiles
  for each row execute function private.sync_instructor_courses_from_profile();

-- Bring existing course banners in line with their instructors now.
update public.courses course_row
set
  instructor_name = private.profile_display_name(profile_row),
  instructor_avatar_url = profile_row.avatar_url,
  updated_at = timezone('utc', now())
from public.profiles profile_row
where profile_row.id = course_row.instructor_id
  and (
    course_row.instructor_name is distinct from
      private.profile_display_name(profile_row)
    or course_row.instructor_avatar_url is distinct from profile_row.avatar_url
  );

-- Flutter's stream() listens for these UPDATE events. Safe to run repeatedly.
do $$
begin
  if not exists (
    select 1
    from pg_publication_tables
    where pubname = 'supabase_realtime'
      and schemaname = 'public'
      and tablename = 'courses'
  ) then
    alter publication supabase_realtime add table public.courses;
  end if;
end;
$$;

-- Verify after updating an instructor profile:
-- select c.title, c.instructor_name, c.instructor_avatar_url
-- from public.courses c
-- where c.instructor_id = 'INSTRUCTOR_UUID';
