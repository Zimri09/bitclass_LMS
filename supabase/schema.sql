create extension if not exists pgcrypto;

create or replace function public.set_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at = timezone('utc', now());
  return new;
end;
$$;

create or replace function public.delete_current_user_account()
returns void
language plpgsql
security definer
set search_path = public, auth
as $$
declare
  current_user_id uuid := auth.uid();
begin
  if current_user_id is null then
    raise exception 'Not authenticated';
  end if;

  delete from public.device_tokens where user_id = current_user_id;
  delete from public.notification_settings where user_id = current_user_id;
  delete from public.notifications where user_id = current_user_id;
  delete from public.quiz_answers qa
  using public.quiz_attempts a
  where qa.attempt_id = a.id and a.user_id = current_user_id;
  delete from public.quiz_attempts where user_id = current_user_id;
  delete from public.submissions where user_id = current_user_id;
  delete from public.lesson_progress lp
  using public.enrollments e
  where lp.enrollment_id = e.id and e.user_id = current_user_id;
  delete from public.enrollments where user_id = current_user_id;
  delete from public.thread_likes where user_id = current_user_id;
  delete from public.replies where author_id = current_user_id;
  delete from public.threads where author_id = current_user_id;
  delete from public.files where uploader_id = current_user_id;
  delete from public.profiles where id = current_user_id;
  delete from auth.users where id = current_user_id;
end;
$$;

do $$ begin
  create type user_role as enum ('student', 'instructor', 'admin');
exception
  when duplicate_object then null;
end $$;

do $$ begin
  create type lesson_type as enum ('text', 'video', 'code', 'quiz');
exception
  when duplicate_object then null;
end $$;

do $$ begin
  create type file_type as enum ('document', 'image', 'video', 'audio', 'code', 'archive', 'other');
exception
  when duplicate_object then null;
end $$;

do $$ begin
  create type assignment_language as enum ('dart', 'python', 'javascript', 'java', 'cpp', 'csharp', 'go', 'rust', 'typescript', 'sql', 'html', 'css', 'plaintext');
exception
  when duplicate_object then null;
end $$;

do $$ begin
  create type submission_status as enum ('draft', 'submitted', 'grading', 'graded', 'returned');
exception
  when duplicate_object then null;
end $$;

do $$ begin
  create type attempt_status as enum ('inProgress', 'submitted', 'graded', 'timedOut');
exception
  when duplicate_object then null;
end $$;

create table if not exists public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  email text not null unique,
  display_name text,
  first_name text,
  last_name text,
  avatar_url text,
  bio text,
  role user_role not null default 'student',
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now())
);

alter table public.profiles
  add column if not exists first_name text,
  add column if not exists last_name text;

drop trigger if exists profiles_updated_at on public.profiles;
create trigger profiles_updated_at
before update on public.profiles
for each row execute function public.set_updated_at();

create schema if not exists private;
revoke all on schema private from public;

-- Authenticated clients may update their profile, but not elevate their role.
create or replace function private.prevent_client_role_change()
returns trigger
language plpgsql
set search_path = pg_catalog, auth
as $$
begin
  if (select auth.uid()) is not null
     and new.role is distinct from old.role then
    raise exception 'Profile roles can only be changed by a privileged server action';
  end if;
  return new;
end;
$$;

drop trigger if exists profiles_role_immutable on public.profiles;
create trigger profiles_role_immutable
  before update of role on public.profiles
  for each row execute function private.prevent_client_role_change();

-- Auto-create a profile row when a new auth user signs up.
create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into public.profiles (
    id, email, display_name, first_name, last_name, role
  )
  values (
    new.id,
    new.email,
    coalesce(
      new.raw_user_meta_data->>'display_name',
      nullif(
        trim(concat_ws(
          ' ',
          new.raw_user_meta_data->>'first_name',
          new.raw_user_meta_data->>'last_name'
        )),
        ''
      ),
      split_part(new.email, '@', 1)
    ),
    new.raw_user_meta_data->>'first_name',
    new.raw_user_meta_data->>'last_name',
    case
      when new.raw_user_meta_data->>'role' = 'instructor'
        then 'instructor'::user_role
      else 'student'::user_role
    end
  )
  on conflict (id) do update set
    email = excluded.email,
    display_name = coalesce(excluded.display_name, public.profiles.display_name),
    first_name = coalesce(excluded.first_name, public.profiles.first_name),
    last_name = coalesce(excluded.last_name, public.profiles.last_name),
    updated_at = timezone('utc', now());
  return new;
end;
$$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();

create table if not exists public.courses (
  id uuid primary key default gen_random_uuid(),
  title text not null,
  description text not null,
  category text not null,
  instructor_id uuid not null references public.profiles(id) on delete cascade,
  instructor_name text not null,
  instructor_avatar_url text,
  thumbnail_url text,
  course_code text,
  enrollment_count integer not null default 0,
  lesson_count integer not null default 0,
  is_published boolean not null default false,
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now())
);

-- Existing projects created before course-code support need this too.
alter table public.courses
  add column if not exists course_code text,
  add column if not exists instructor_avatar_url text;

create unique index if not exists courses_course_code_unique_idx
  on public.courses (course_code)
  where course_code is not null;

drop trigger if exists courses_updated_at on public.courses;
create trigger courses_updated_at
before update on public.courses
for each row execute function public.set_updated_at();

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

create table if not exists public.modules (
  id uuid primary key default gen_random_uuid(),
  course_id uuid not null references public.courses(id) on delete cascade,
  title text not null,
  description text,
  sort_order integer not null default 0,
  is_published boolean not null default false,
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now())
);

create index if not exists modules_course_order_idx on public.modules (course_id, sort_order);

drop trigger if exists modules_updated_at on public.modules;
create trigger modules_updated_at
before update on public.modules
for each row execute function public.set_updated_at();

create table if not exists public.lessons (
  id uuid primary key default gen_random_uuid(),
  course_id uuid not null references public.courses(id) on delete cascade,
  module_id uuid not null references public.modules(id) on delete cascade,
  title text not null,
  description text,
  sort_order integer not null default 0,
  lesson_type lesson_type not null default 'text',
  content text,
  video_url text,
  duration_minutes integer not null default 5,
  is_published boolean not null default false,
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now())
);

create index if not exists lessons_course_module_order_idx on public.lessons (course_id, module_id, sort_order);

drop trigger if exists lessons_updated_at on public.lessons;
create trigger lessons_updated_at
before update on public.lessons
for each row execute function public.set_updated_at();

create or replace function public.sync_course_lesson_count()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  affected_course_id uuid;
begin
  if tg_op = 'DELETE' then
    affected_course_id := old.course_id;
  else
    affected_course_id := new.course_id;
  end if;

  update public.courses
  set lesson_count = (
        select count(*)
        from public.lessons
        where course_id = affected_course_id
      ),
      updated_at = timezone('utc', now())
  where id = affected_course_id;

  if tg_op = 'UPDATE' and old.course_id is distinct from new.course_id then
    update public.courses
    set lesson_count = (
          select count(*)
          from public.lessons
          where course_id = old.course_id
        ),
        updated_at = timezone('utc', now())
    where id = old.course_id;
  end if;

  if tg_op = 'DELETE' then
    return old;
  end if;
  return new;
end;
$$;

drop trigger if exists lessons_sync_course_lesson_count on public.lessons;
create trigger lessons_sync_course_lesson_count
after insert or delete or update of course_id on public.lessons
for each row execute function public.sync_course_lesson_count();

create table if not exists public.enrollments (
  id uuid primary key default gen_random_uuid(),
  course_id uuid not null references public.courses(id) on delete cascade,
  user_id uuid not null references public.profiles(id) on delete cascade,
  student_name text,
  student_email text,
  progress numeric(5,2) not null default 0,
  completed_lessons integer not null default 0,
  total_lessons integer not null default 0,
  enrolled_at timestamptz not null default timezone('utc', now()),
  completed_at timestamptz,
  last_accessed_at timestamptz,
  unique (course_id, user_id)
);

create index if not exists enrollments_course_user_idx on public.enrollments (course_id, user_id);

create table if not exists public.lesson_progress (
  id uuid primary key default gen_random_uuid(),
  enrollment_id uuid not null references public.enrollments(id) on delete cascade,
  lesson_id uuid not null references public.lessons(id) on delete cascade,
  user_id uuid not null references public.profiles(id) on delete cascade,
  is_completed boolean not null default false,
  completed_at timestamptz,
  last_accessed_at timestamptz,
  saved_state jsonb,
  unique (enrollment_id, lesson_id)
);

create index if not exists lesson_progress_user_idx on public.lesson_progress (user_id);

create table if not exists public.assignments (
  id uuid primary key default gen_random_uuid(),
  course_id uuid not null references public.courses(id) on delete cascade,
  lesson_id uuid references public.lessons(id) on delete set null,
  title text not null,
  description text not null,
  instructions text,
  language assignment_language not null default 'plaintext',
  starter_code text,
  solution_code text,
  max_points integer not null default 100,
  due_date timestamptz,
  allow_late_submission boolean not null default true,
  late_penalty_percent integer not null default 10,
  is_published boolean not null default false,
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now())
);

drop trigger if exists assignments_updated_at on public.assignments;
create trigger assignments_updated_at
before update on public.assignments
for each row execute function public.set_updated_at();

create table if not exists public.submissions (
  id uuid primary key default gen_random_uuid(),
  assignment_id uuid not null references public.assignments(id) on delete cascade,
  course_id uuid not null references public.courses(id) on delete cascade,
  user_id uuid not null references public.profiles(id) on delete cascade,
  user_display_name text not null,
  code text not null default '',
  status submission_status not null default 'draft',
  score integer,
  feedback text,
  graded_by uuid references public.profiles(id) on delete set null,
  graded_at timestamptz,
  is_late boolean not null default false,
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now()),
  submitted_at timestamptz,
  unique (assignment_id, user_id)
);

drop trigger if exists submissions_updated_at on public.submissions;
create trigger submissions_updated_at
before update on public.submissions
for each row execute function public.set_updated_at();

create table if not exists public.quizzes (
  id uuid primary key default gen_random_uuid(),
  course_id uuid not null references public.courses(id) on delete cascade,
  lesson_id uuid references public.lessons(id) on delete set null,
  title text not null,
  description text,
  time_limit_minutes integer not null default 0,
  passing_score integer not null default 70,
  total_points integer not null default 0,
  question_count integer not null default 0,
  shuffle_questions boolean not null default false,
  shuffle_answers boolean not null default true,
  show_correct_answers boolean not null default true,
  allow_retakes boolean not null default true,
  max_attempts integer not null default 0,
  is_published boolean not null default false,
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now())
);

drop trigger if exists quizzes_updated_at on public.quizzes;
create trigger quizzes_updated_at
before update on public.quizzes
for each row execute function public.set_updated_at();

create table if not exists public.questions (
  id uuid primary key default gen_random_uuid(),
  quiz_id uuid not null references public.quizzes(id) on delete cascade,
  question_type text not null default 'multiple_choice',
  prompt text not null,
  points integer not null default 1,
  options jsonb not null default '[]'::jsonb,
  correct_answer jsonb,
  explanation text,
  question_code text,
  code_language text,
  hint text,
  test_cases jsonb,
  sort_order integer not null default 0
);

create table if not exists public.quiz_attempts (
  id uuid primary key default gen_random_uuid(),
  quiz_id uuid not null references public.quizzes(id) on delete cascade,
  user_id uuid not null references public.profiles(id) on delete cascade,
  enrollment_id uuid references public.enrollments(id) on delete set null,
  status attempt_status not null default 'inProgress',
  attempt_number integer not null default 1,
  started_at timestamptz not null default timezone('utc', now()),
  submitted_at timestamptz,
  graded_at timestamptz,
  score integer not null default 0,
  total_points integer not null default 0,
  percentage numeric(6,2) not null default 0,
  passed boolean not null default false,
  time_spent_seconds integer not null default 0,
  answers jsonb not null default '{}'::jsonb,
  unique (quiz_id, user_id, attempt_number)
);

create table if not exists public.quiz_answers (
  id uuid primary key default gen_random_uuid(),
  attempt_id uuid not null references public.quiz_attempts(id) on delete cascade,
  question_id uuid not null references public.questions(id) on delete cascade,
  selected_answers jsonb not null default '[]'::jsonb,
  text_answer text,
  code_answer text,
  is_correct boolean not null default false,
  points_earned integer not null default 0,
  max_points integer not null default 0,
  feedback text,
  answered_at timestamptz not null default timezone('utc', now())
);

create table if not exists public.discussion_channels (
  id uuid primary key default gen_random_uuid(),
  course_id uuid not null references public.courses(id) on delete cascade,
  title text not null,
  description text,
  is_private boolean not null default false,
  is_published boolean not null default false,
  icon text,
  is_default boolean not null default false,
  is_announcement boolean not null default false,
  thread_count integer not null default 0,
  last_activity_at timestamptz,
  created_by uuid references public.profiles(id) on delete set null,
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now())
);

drop trigger if exists discussion_channels_updated_at on public.discussion_channels;
create trigger discussion_channels_updated_at
before update on public.discussion_channels
for each row execute function public.set_updated_at();

-- Every course has an instructor announcement space and a shared discussion.
create or replace function public.create_default_course_discussion_channels()
returns trigger
language plpgsql
security definer
set search_path = pg_catalog, public
as $$
begin
  insert into public.discussion_channels (
    course_id, title, description, is_default, is_announcement,
    is_published, created_by
  )
  values
    (new.id, 'Announcements', 'Official updates from the instructor.', true,
      true, true, new.instructor_id),
    (new.id, 'General discussion', 'Questions and class conversations.', true,
      false, true, new.instructor_id);
  return new;
end;
$$;

revoke all on function public.create_default_course_discussion_channels()
  from public;

drop trigger if exists courses_create_default_discussion_channels
  on public.courses;
create trigger courses_create_default_discussion_channels
after insert on public.courses
for each row execute function public.create_default_course_discussion_channels();

create table if not exists public.threads (
  id uuid primary key default gen_random_uuid(),
  channel_id uuid not null references public.discussion_channels(id) on delete cascade,
  course_id uuid not null references public.courses(id) on delete cascade,
  title text not null,
  content text not null,
  author_id uuid not null references public.profiles(id) on delete cascade,
  author_name text not null,
  author_avatar_url text,
  is_pinned boolean not null default false,
  is_locked boolean not null default false,
  is_resolved boolean not null default false,
  reply_count integer not null default 0,
  like_count integer not null default 0,
  liked_by jsonb not null default '[]'::jsonb,
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now()),
  last_reply_at timestamptz
);

drop trigger if exists threads_updated_at on public.threads;
create trigger threads_updated_at
before update on public.threads
for each row execute function public.set_updated_at();

create table if not exists public.thread_likes (
  id uuid primary key default gen_random_uuid(),
  thread_id uuid not null references public.threads(id) on delete cascade,
  user_id uuid not null references public.profiles(id) on delete cascade,
  created_at timestamptz not null default timezone('utc', now()),
  unique (thread_id, user_id)
);

create table if not exists public.replies (
  id uuid primary key default gen_random_uuid(),
  thread_id uuid not null references public.threads(id) on delete cascade,
  channel_id uuid not null references public.discussion_channels(id) on delete cascade,
  course_id uuid not null references public.courses(id) on delete cascade,
  parent_reply_id uuid references public.replies(id) on delete cascade,
  author_id uuid not null references public.profiles(id) on delete cascade,
  author_name text not null,
  author_avatar_url text,
  content text not null,
  is_instructor_answer boolean not null default false,
  is_accepted_answer boolean not null default false,
  like_count integer not null default 0,
  liked_by jsonb not null default '[]'::jsonb,
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now())
);

drop trigger if exists replies_updated_at on public.replies;
create trigger replies_updated_at
before update on public.replies
for each row execute function public.set_updated_at();

-- Keep discussion activity counters server-owned so students can create posts
-- without needing write access to channel or other-thread metadata.
create or replace function public.sync_discussion_thread_count()
returns trigger
language plpgsql
security definer
set search_path = pg_catalog, public
as $$
begin
  if tg_op = 'INSERT' then
    update public.discussion_channels
    set thread_count = thread_count + 1, last_activity_at = new.created_at
    where id = new.channel_id;
    return new;
  end if;

  update public.discussion_channels
  set thread_count = greatest(thread_count - 1, 0)
  where id = old.channel_id;
  return old;
end;
$$;

create or replace function public.sync_discussion_reply_count()
returns trigger
language plpgsql
security definer
set search_path = pg_catalog, public
as $$
begin
  if tg_op = 'INSERT' then
    update public.threads
    set reply_count = reply_count + 1, last_reply_at = new.created_at
    where id = new.thread_id;
    update public.discussion_channels
    set last_activity_at = new.created_at
    where id = new.channel_id;
    return new;
  end if;

  update public.threads
  set reply_count = greatest(reply_count - 1, 0)
  where id = old.thread_id;
  return old;
end;
$$;

revoke all on function public.sync_discussion_thread_count() from public;
revoke all on function public.sync_discussion_reply_count() from public;

drop trigger if exists threads_sync_channel_count on public.threads;
create trigger threads_sync_channel_count
after insert or delete on public.threads
for each row execute function public.sync_discussion_thread_count();

drop trigger if exists replies_sync_thread_count on public.replies;
create trigger replies_sync_thread_count
after insert or delete on public.replies
for each row execute function public.sync_discussion_reply_count();

create table if not exists public.files (
  id text primary key,
  course_id uuid not null references public.courses(id) on delete cascade,
  lesson_id uuid references public.lessons(id) on delete set null,
  uploader_id uuid not null references public.profiles(id) on delete cascade,
  uploader_name text not null,
  name text not null,
  description text not null default '',
  bucket text not null default 'bitclass_storage',
  storage_path text not null,
  public_url text not null,
  thumbnail_url text,
  file_type file_type not null default 'other',
  mime_type text not null,
  size_bytes bigint not null,
  download_count integer not null default 0,
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now())
);

drop trigger if exists files_updated_at on public.files;
create trigger files_updated_at
before update on public.files
for each row execute function public.set_updated_at();

create table if not exists public.notifications (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  type text not null,
  title text not null,
  body text not null,
  image_url text,
  data jsonb not null default '{}'::jsonb,
  course_id uuid references public.courses(id) on delete set null,
  action_url text,
  is_read boolean not null default false,
  created_at timestamptz not null default timezone('utc', now())
);

create table if not exists public.notification_settings (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade unique,
  email_enabled boolean not null default true,
  push_enabled boolean not null default true,
  in_app_enabled boolean not null default true,
  type_settings jsonb not null default '{}'::jsonb,
  quiet_hours_enabled boolean not null default false,
  quiet_hours_start integer not null default 22,
  quiet_hours_end integer not null default 8,
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now())
);

create table if not exists public.device_tokens (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  token text not null unique,
  platform text not null,
  created_at timestamptz not null default timezone('utc', now())
);

drop trigger if exists notification_settings_updated_at on public.notification_settings;
create trigger notification_settings_updated_at
before update on public.notification_settings
for each row execute function public.set_updated_at();

-- Helper function: get the stored role without hitting profiles RLS.
-- Authorization must not trust user-editable auth metadata.
create or replace function public.current_user_role()
returns text
language sql
stable
security definer
set search_path = public, auth
as $$
  select coalesce(
    (select role::text from public.profiles where id = auth.uid()),
    'student'
  );
$$;

alter table public.profiles enable row level security;
alter table public.courses enable row level security;
alter table public.modules enable row level security;
alter table public.lessons enable row level security;
alter table public.enrollments enable row level security;
alter table public.lesson_progress enable row level security;
alter table public.assignments enable row level security;
alter table public.submissions enable row level security;
alter table public.quizzes enable row level security;
alter table public.questions enable row level security;
alter table public.quiz_attempts enable row level security;
alter table public.quiz_answers enable row level security;
alter table public.discussion_channels enable row level security;
alter table public.threads enable row level security;
alter table public.thread_likes enable row level security;
alter table public.replies enable row level security;
alter table public.files enable row level security;
alter table public.notifications enable row level security;
alter table public.notification_settings enable row level security;
alter table public.device_tokens enable row level security;

-- Todos
create table if not exists public.todos (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  name text not null,
  is_completed boolean not null default false,
  due_at timestamptz,
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now())
);

drop trigger if exists todos_updated_at on public.todos;
create trigger todos_updated_at
before update on public.todos
for each row execute function public.set_updated_at();

alter table public.todos enable row level security;

-- Drop all existing policies on public tables to avoid duplicate policy errors when re-running
do $$
declare
  r record;
begin
  for r in (
    select policyname, tablename, schemaname
    from pg_policies
    where schemaname = 'public'
  ) loop
    execute format('drop policy if exists %I on %I.%I', r.policyname, r.schemaname, r.tablename);
  end loop;
end $$;

create policy "todos read own" on public.todos
  for select using (user_id = auth.uid());

create policy "todos update own" on public.todos
  for update using (user_id = auth.uid())
  with check (user_id = auth.uid());


create policy "profiles read own" on public.profiles
  for select using (auth.uid() = id or public.current_user_role() in ('instructor', 'admin'));
create policy "profiles write own" on public.profiles
  for insert with check (auth.uid() = id);
create policy "profiles update own" on public.profiles
  for update using (auth.uid() = id);

create policy "courses read enrolled or own" on public.courses
  for select using (
    instructor_id = auth.uid()
    or public.current_user_role() = 'admin'
    or (
      is_published
      and exists (
        select 1
        from public.enrollments e
        where e.course_id = courses.id and e.user_id = auth.uid()
      )
    )
  );
create policy "courses manage instructors" on public.courses
  for all using (instructor_id = auth.uid() or exists (select 1 from public.profiles p where p.id = auth.uid() and p.role = 'admin'))
  with check (instructor_id = auth.uid() or exists (select 1 from public.profiles p where p.id = auth.uid() and p.role = 'admin'));

create policy "modules access course members" on public.modules
  for select using (exists (select 1 from public.courses c where c.id = course_id and (c.is_published or c.instructor_id = auth.uid() or exists (select 1 from public.profiles p where p.id = auth.uid() and p.role = 'admin'))));
create policy "modules manage instructors" on public.modules
  for all using (exists (select 1 from public.courses c where c.id = course_id and (c.instructor_id = auth.uid() or exists (select 1 from public.profiles p where p.id = auth.uid() and p.role = 'admin'))))
  with check (exists (select 1 from public.courses c where c.id = course_id and (c.instructor_id = auth.uid() or exists (select 1 from public.profiles p where p.id = auth.uid() and p.role = 'admin'))));

create policy "lessons access course members" on public.lessons
  for select using (exists (select 1 from public.courses c where c.id = course_id and (c.is_published or c.instructor_id = auth.uid() or exists (select 1 from public.profiles p where p.id = auth.uid() and p.role = 'admin'))));
create policy "lessons manage instructors" on public.lessons
  for all using (exists (select 1 from public.courses c where c.id = course_id and (c.instructor_id = auth.uid() or exists (select 1 from public.profiles p where p.id = auth.uid() and p.role = 'admin'))))
  with check (exists (select 1 from public.courses c where c.id = course_id and (c.instructor_id = auth.uid() or exists (select 1 from public.profiles p where p.id = auth.uid() and p.role = 'admin'))));

create policy "enrollments read own or instructors" on public.enrollments
  for select using (user_id = auth.uid() or exists (select 1 from public.courses c where c.id = course_id and c.instructor_id = auth.uid()) or exists (select 1 from public.profiles p where p.id = auth.uid() and p.role = 'admin'));
create policy "enrollments update own" on public.enrollments
  for update using (user_id = auth.uid())
  with check (user_id = auth.uid());
create policy "enrollments delete own" on public.enrollments
  for delete using (user_id = auth.uid());

create policy "lesson progress read own" on public.lesson_progress
  for select using (user_id = auth.uid() or exists (select 1 from public.courses c join public.enrollments e on e.course_id = c.id where e.id = enrollment_id and c.instructor_id = auth.uid()));
create policy "lesson progress manage own" on public.lesson_progress
  for all using (user_id = auth.uid())
  with check (user_id = auth.uid());

create policy "assignments read course members" on public.assignments
  for select using (exists (select 1 from public.courses c where c.id = course_id and (c.is_published or c.instructor_id = auth.uid() or exists (select 1 from public.profiles p where p.id = auth.uid() and p.role = 'admin'))));
create policy "assignments manage instructors" on public.assignments
  for all using (exists (select 1 from public.courses c where c.id = course_id and (c.instructor_id = auth.uid() or exists (select 1 from public.profiles p where p.id = auth.uid() and p.role = 'admin'))))
  with check (exists (select 1 from public.courses c where c.id = course_id and (c.instructor_id = auth.uid() or exists (select 1 from public.profiles p where p.id = auth.uid() and p.role = 'admin'))));

create policy "submissions read own or course instructors" on public.submissions
  for select using (user_id = auth.uid() or exists (select 1 from public.courses c where c.id = course_id and c.instructor_id = auth.uid()) or exists (select 1 from public.profiles p where p.id = auth.uid() and p.role = 'admin'));
create policy "submissions manage own" on public.submissions
  for all using (user_id = auth.uid())
  with check (user_id = auth.uid());

create policy "quizzes read course members" on public.quizzes
  for select using (exists (select 1 from public.courses c where c.id = course_id and (c.is_published or c.instructor_id = auth.uid() or exists (select 1 from public.profiles p where p.id = auth.uid() and p.role = 'admin'))));
create policy "quizzes manage instructors" on public.quizzes
  for all using (exists (select 1 from public.courses c where c.id = course_id and (c.instructor_id = auth.uid() or exists (select 1 from public.profiles p where p.id = auth.uid() and p.role = 'admin'))))
  with check (exists (select 1 from public.courses c where c.id = course_id and (c.instructor_id = auth.uid() or exists (select 1 from public.profiles p where p.id = auth.uid() and p.role = 'admin'))));

create policy "questions read quiz members" on public.questions
  for select using (exists (select 1 from public.quizzes q join public.courses c on c.id = q.course_id where q.id = quiz_id and (c.is_published or c.instructor_id = auth.uid() or exists (select 1 from public.profiles p where p.id = auth.uid() and p.role = 'admin'))));
create policy "questions manage instructors" on public.questions
  for all using (exists (select 1 from public.quizzes q join public.courses c on c.id = q.course_id where q.id = quiz_id and (c.instructor_id = auth.uid() or exists (select 1 from public.profiles p where p.id = auth.uid() and p.role = 'admin'))))
  with check (exists (select 1 from public.quizzes q join public.courses c on c.id = q.course_id where q.id = quiz_id and (c.instructor_id = auth.uid() or exists (select 1 from public.profiles p where p.id = auth.uid() and p.role = 'admin'))));

create policy "quiz attempts read own" on public.quiz_attempts
  for select using (user_id = auth.uid() or exists (select 1 from public.quizzes q join public.courses c on c.id = q.course_id where q.id = quiz_id and c.instructor_id = auth.uid()) or exists (select 1 from public.profiles p where p.id = auth.uid() and p.role = 'admin'));
create policy "quiz attempts manage own" on public.quiz_attempts
  for all using (user_id = auth.uid() or exists (select 1 from public.quizzes q join public.courses c on c.id = q.course_id where q.id = quiz_id and c.instructor_id = auth.uid()) or exists (select 1 from public.profiles p where p.id = auth.uid() and p.role = 'admin'))
  with check (user_id = auth.uid() or exists (select 1 from public.quizzes q join public.courses c on c.id = q.course_id where q.id = quiz_id and c.instructor_id = auth.uid()) or exists (select 1 from public.profiles p where p.id = auth.uid() and p.role = 'admin'));

create policy "quiz answers read own" on public.quiz_answers
  for select using (exists (select 1 from public.quiz_attempts a where a.id = attempt_id and a.user_id = auth.uid()) or exists (select 1 from public.quiz_attempts a join public.quizzes q on q.id = a.quiz_id join public.courses c on c.id = q.course_id where a.id = attempt_id and c.instructor_id = auth.uid()));
create policy "quiz answers manage own" on public.quiz_answers
  for all using (exists (select 1 from public.quiz_attempts a where a.id = attempt_id and a.user_id = auth.uid()) or exists (select 1 from public.quiz_attempts a join public.quizzes q on q.id = a.quiz_id join public.courses c on c.id = q.course_id where a.id = attempt_id and c.instructor_id = auth.uid()))
  with check (exists (select 1 from public.quiz_attempts a where a.id = attempt_id and a.user_id = auth.uid()) or exists (select 1 from public.quiz_attempts a join public.quizzes q on q.id = a.quiz_id join public.courses c on c.id = q.course_id where a.id = attempt_id and c.instructor_id = auth.uid()));

create policy "discussion channels read course members" on public.discussion_channels
  for select using (exists (select 1 from public.courses c where c.id = course_id and (c.is_published or c.instructor_id = auth.uid() or exists (select 1 from public.profiles p where p.id = auth.uid() and p.role = 'admin'))));
create policy "discussion channels manage instructors" on public.discussion_channels
  for all using (exists (select 1 from public.courses c where c.id = course_id and (c.instructor_id = auth.uid() or exists (select 1 from public.profiles p where p.id = auth.uid() and p.role = 'admin'))))
  with check (exists (select 1 from public.courses c where c.id = course_id and (c.instructor_id = auth.uid() or exists (select 1 from public.profiles p where p.id = auth.uid() and p.role = 'admin'))));

create policy "threads read course members" on public.threads
  for select using (exists (select 1 from public.courses c where c.id = course_id and (c.is_published or c.instructor_id = auth.uid() or exists (select 1 from public.profiles p where p.id = auth.uid() and p.role = 'admin'))));
create policy "threads manage instructors and authors" on public.threads
  for all using (author_id = auth.uid() or exists (select 1 from public.courses c where c.id = course_id and (c.instructor_id = auth.uid() or exists (select 1 from public.profiles p where p.id = auth.uid() and p.role = 'admin'))))
  with check (author_id = auth.uid() or exists (select 1 from public.courses c where c.id = course_id and (c.instructor_id = auth.uid() or exists (select 1 from public.profiles p where p.id = auth.uid() and p.role = 'admin'))));

create policy "thread likes read own" on public.thread_likes
  for select using (user_id = auth.uid());
create policy "thread likes manage own" on public.thread_likes
  for all using (user_id = auth.uid()) with check (user_id = auth.uid());

create policy "replies read course members" on public.replies
  for select using (exists (select 1 from public.threads t where t.id = thread_id and (t.course_id is not null)));
create policy "replies manage authors and instructors" on public.replies
  for all using (author_id = auth.uid() or exists (select 1 from public.threads t join public.courses c on c.id = t.course_id where t.id = thread_id and (c.instructor_id = auth.uid() or exists (select 1 from public.profiles p where p.id = auth.uid() and p.role = 'admin'))))
  with check (author_id = auth.uid() or exists (select 1 from public.threads t join public.courses c on c.id = t.course_id where t.id = thread_id and (c.instructor_id = auth.uid() or exists (select 1 from public.profiles p where p.id = auth.uid() and p.role = 'admin'))));

create policy "files read course members" on public.files
  for select using (exists (select 1 from public.courses c where c.id = course_id and (c.is_published or c.instructor_id = auth.uid() or exists (select 1 from public.profiles p where p.id = auth.uid() and p.role = 'admin'))));
create policy "files manage course instructors" on public.files
  for all using (exists (select 1 from public.courses c where c.id = course_id and (c.instructor_id = auth.uid() or exists (select 1 from public.profiles p where p.id = auth.uid() and p.role = 'admin'))))
  with check (exists (select 1 from public.courses c where c.id = course_id and (c.instructor_id = auth.uid() or exists (select 1 from public.profiles p where p.id = auth.uid() and p.role = 'admin'))));

create policy "notifications read own" on public.notifications
  for select using (user_id = auth.uid());
create policy "notifications write own" on public.notifications
  for all using (user_id = auth.uid()) with check (user_id = auth.uid());

create policy "notification settings read own" on public.notification_settings
  for select using (user_id = auth.uid());
create policy "notification settings write own" on public.notification_settings
  for all using (user_id = auth.uid()) with check (user_id = auth.uid());

create policy "device tokens manage own" on public.device_tokens
  for all using (user_id = auth.uid()) with check (user_id = auth.uid());

-- Students can discover a course only by supplying its code. The function
-- performs lookup, enrollment, and count maintenance as one server operation.
create or replace function public.join_course_by_code(join_code text)
returns table (course_id uuid, enrollment_id uuid)
language plpgsql
security definer
set search_path = pg_catalog, public, auth
as $$
declare
  authenticated_user_id uuid := (select auth.uid());
  normalized_code text := upper(trim(join_code));
  target_course_id uuid;
  target_lesson_count integer;
  created_enrollment_id uuid;
begin
  if authenticated_user_id is null then
    raise exception 'Authentication is required';
  end if;

  if normalized_code !~ '^[A-Z0-9]{6}$' then
    raise exception 'Invalid course code. Please check and try again.';
  end if;

  if public.current_user_role() <> 'student' then
    raise exception 'Only student accounts can join courses.';
  end if;

  select id, lesson_count
  into target_course_id, target_lesson_count
  from public.courses
  where course_code = normalized_code and is_published;

  if target_course_id is null then
    raise exception 'Invalid course code. Please check and try again.';
  end if;

  insert into public.enrollments (
    course_id,
    user_id,
    student_name,
    student_email,
    progress,
    completed_lessons,
    total_lessons
  )
  select
    target_course_id,
    id,
    display_name,
    email,
    0,
    0,
    target_lesson_count
  from public.profiles
  where id = authenticated_user_id
  on conflict (course_id, user_id) do nothing
  returning id into created_enrollment_id;

  if created_enrollment_id is null then
    raise exception 'You are already enrolled in this course.';
  end if;

  update public.courses
  set enrollment_count = enrollment_count + 1
  where id = target_course_id;

  return query select target_course_id, created_enrollment_id;
end;
$$;

revoke all on function public.join_course_by_code(text) from public;
grant execute on function public.join_course_by_code(text) to authenticated;

create or replace function public.unenroll_from_course(target_course_id uuid)
returns void
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if (select auth.uid()) is null then
    raise exception 'You must be signed in to unenroll.';
  end if;

  delete from public.enrollments
  where course_id = target_course_id
    and user_id = (select auth.uid());

  if not found then
    raise exception 'You are not enrolled in this class.';
  end if;

  update public.courses
  set
    enrollment_count = greatest(enrollment_count - 1, 0),
    updated_at = timezone('utc', now())
  where id = target_course_id;
end;
$$;

revoke all on function public.unenroll_from_course(uuid) from public;
grant execute on function public.unenroll_from_course(uuid) to authenticated;
