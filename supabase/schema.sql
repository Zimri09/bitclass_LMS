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
  avatar_url text,
  bio text,
  role user_role not null default 'student',
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now())
);

drop trigger if exists profiles_updated_at on public.profiles;
create trigger profiles_updated_at
before update on public.profiles
for each row execute function public.set_updated_at();

-- Auto-create a profile row when a new auth user signs up.
create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into public.profiles (id, email, display_name, role)
  values (
    new.id,
    new.email,
    coalesce(new.raw_user_meta_data->>'display_name', split_part(new.email, '@', 1)),
    coalesce((new.raw_user_meta_data->>'role')::user_role, 'student'::user_role)
  )
  on conflict (id) do update set
    email = excluded.email,
    display_name = coalesce(excluded.display_name, public.profiles.display_name),
    role = coalesce(excluded.role, public.profiles.role),
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
  thumbnail_url text,
  enrollment_count integer not null default 0,
  lesson_count integer not null default 0,
  is_published boolean not null default false,
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now())
);

drop trigger if exists courses_updated_at on public.courses;
create trigger courses_updated_at
before update on public.courses
for each row execute function public.set_updated_at();

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
  is_completed boolean not null default false,
  completed_at timestamptz,
  last_position numeric(10,2) not null default 0,
  time_spent_seconds integer not null default 0,
  unique (enrollment_id, lesson_id)
);

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

-- Helper function: get current user's role without hitting profiles RLS
create or replace function public.current_user_role()
returns text
language sql
stable
security definer
set search_path = public, auth
as $$
  select coalesce(
    (select role::text from public.profiles where id = auth.uid()),
    (select raw_user_meta_data->>'role' from auth.users where id = auth.uid()),
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

create trigger todos_updated_at
before update on public.todos
for each row execute function public.set_updated_at();

alter table public.todos enable row level security;

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

create policy "courses read published or own" on public.courses
  for select using (is_published or instructor_id = auth.uid() or exists (select 1 from public.profiles p where p.id = auth.uid() and p.role in ('instructor', 'admin')));
create policy "courses manage instructors" on public.courses
  for all using (instructor_id = auth.uid() or exists (select 1 from public.profiles p where p.id = auth.uid() and p.role = 'admin'))
  with check (instructor_id = auth.uid() or exists (select 1 from public.profiles p where p.id = auth.uid() and p.role = 'admin'));

create policy "modules access course members" on public.modules
  for select using (exists (select 1 from public.courses c where c.id = course_id and (c.is_published or c.instructor_id = auth.uid() or exists (select 1 from public.profiles p where p.id = auth.uid() and p.role = 'admin'))));

create policy "lessons access course members" on public.lessons
  for select using (exists (select 1 from public.courses c where c.id = course_id and (c.is_published or c.instructor_id = auth.uid() or exists (select 1 from public.profiles p where p.id = auth.uid() and p.role = 'admin'))));

create policy "enrollments read own or instructors" on public.enrollments
  for select using (user_id = auth.uid() or exists (select 1 from public.courses c where c.id = course_id and c.instructor_id = auth.uid()) or exists (select 1 from public.profiles p where p.id = auth.uid() and p.role = 'admin'));

create policy "lesson progress read own" on public.lesson_progress
  for select using (exists (select 1 from public.enrollments e where e.id = enrollment_id and e.user_id = auth.uid()) or exists (select 1 from public.courses c join public.enrollments e on e.course_id = c.id where e.id = enrollment_id and c.instructor_id = auth.uid()));

create policy "assignments read course members" on public.assignments
  for select using (exists (select 1 from public.courses c where c.id = course_id and (c.is_published or c.instructor_id = auth.uid() or exists (select 1 from public.profiles p where p.id = auth.uid() and p.role = 'admin'))));

create policy "submissions read own or course instructors" on public.submissions
  for select using (user_id = auth.uid() or exists (select 1 from public.courses c where c.id = course_id and c.instructor_id = auth.uid()) or exists (select 1 from public.profiles p where p.id = auth.uid() and p.role = 'admin'));

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
