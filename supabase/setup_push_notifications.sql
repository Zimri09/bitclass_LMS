-- FCM device registration, notification production, and async push dispatch.
-- The Edge Function secrets referenced by the dispatcher are documented in
-- docs/push_notifications.md and are never stored in source control.

create extension if not exists pg_net with schema extensions;
create extension if not exists supabase_vault with schema vault;
create schema if not exists private;

alter table public.device_tokens
  add column if not exists updated_at timestamptz not null
    default timezone('utc', now()),
  add column if not exists last_seen_at timestamptz not null
    default timezone('utc', now()),
  add column if not exists timezone_offset_minutes integer not null default 0;

alter table public.device_tokens
  drop constraint if exists device_tokens_platform_check;
alter table public.device_tokens
  add constraint device_tokens_platform_check
  check (platform in ('android', 'ios', 'web'));

alter table public.device_tokens
  drop constraint if exists device_tokens_timezone_offset_check;
alter table public.device_tokens
  add constraint device_tokens_timezone_offset_check
  check (timezone_offset_minutes between -840 and 840);

create index if not exists device_tokens_user_id_idx
  on public.device_tokens(user_id);
create index if not exists device_tokens_last_seen_at_idx
  on public.device_tokens(last_seen_at);

drop trigger if exists device_tokens_updated_at on public.device_tokens;
create trigger device_tokens_updated_at
before update on public.device_tokens
for each row execute function public.set_updated_at();

create or replace function private.register_device_token_impl(
  device_token text,
  device_platform text,
  timezone_offset integer default 0
)
returns uuid
language plpgsql
security definer
set search_path = pg_catalog, public, auth
as $$
declare
  current_user_id uuid := (select auth.uid());
  token_id uuid;
begin
  if current_user_id is null then
    raise exception 'Authentication is required';
  end if;
  if device_token is null or length(trim(device_token)) < 20 then
    raise exception 'Invalid device token';
  end if;
  if device_platform not in ('android', 'ios', 'web') then
    raise exception 'Unsupported device platform';
  end if;
  if timezone_offset not between -840 and 840 then
    raise exception 'Invalid timezone offset';
  end if;

  insert into public.device_tokens (
    user_id,
    token,
    platform,
    timezone_offset_minutes,
    created_at,
    updated_at,
    last_seen_at
  )
  values (
    current_user_id,
    trim(device_token),
    device_platform,
    timezone_offset,
    timezone('utc', now()),
    timezone('utc', now()),
    timezone('utc', now())
  )
  on conflict (token) do update
  set user_id = excluded.user_id,
      platform = excluded.platform,
      timezone_offset_minutes = excluded.timezone_offset_minutes,
      updated_at = timezone('utc', now()),
      last_seen_at = timezone('utc', now())
  returning id into token_id;

  return token_id;
end;
$$;

create or replace function public.register_device_token(
  device_token text,
  device_platform text,
  timezone_offset integer default 0
)
returns uuid
language sql
security invoker
set search_path = pg_catalog, private
as $$
  select private.register_device_token_impl(
    device_token,
    device_platform,
    timezone_offset
  );
$$;

create or replace function private.unregister_device_token_impl(
  device_token text
)
returns void
language plpgsql
security definer
set search_path = pg_catalog, public, auth
as $$
begin
  if (select auth.uid()) is null then
    raise exception 'Authentication is required';
  end if;
  delete from public.device_tokens
  where token = trim(device_token)
    and user_id = (select auth.uid());
end;
$$;

create or replace function public.unregister_device_token(device_token text)
returns void
language sql
security invoker
set search_path = pg_catalog, private
as $$
  select private.unregister_device_token_impl(device_token);
$$;

revoke all on function public.register_device_token(text, text, integer)
  from public, anon;
revoke all on function private.register_device_token_impl(text, text, integer)
  from public, anon;
revoke all on function public.unregister_device_token(text)
  from public, anon;
revoke all on function private.unregister_device_token_impl(text)
  from public, anon;
grant execute on function public.register_device_token(text, text, integer)
  to authenticated, service_role;
grant execute on function private.register_device_token_impl(text, text, integer)
  to authenticated, service_role;
grant execute on function public.unregister_device_token(text)
  to authenticated, service_role;
grant execute on function private.unregister_device_token_impl(text)
  to authenticated, service_role;

alter table public.device_tokens enable row level security;
drop policy if exists "device tokens manage own" on public.device_tokens;
drop policy if exists "device tokens read own" on public.device_tokens;
drop policy if exists "device tokens delete own" on public.device_tokens;
create policy "device tokens delete own"
  on public.device_tokens for delete to authenticated
  using (user_id = (select auth.uid()));

revoke all on public.device_tokens from anon;
revoke all on public.device_tokens from authenticated;
grant all on public.device_tokens to service_role;

-- Keep membership changes visible to the client-side topic reconciler.
do $$
begin
  if not exists (
    select 1
    from pg_publication_tables
    where pubname = 'supabase_realtime'
      and schemaname = 'public'
      and tablename = 'enrollments'
  ) then
    alter publication supabase_realtime add table public.enrollments;
  end if;
end;
$$;

-- Notification rows are the durable queue. Trigger functions below create
-- rows for common LMS activity; the async dispatcher sends them to FCM.
create or replace function private.notify_course_students(
  target_course_id uuid,
  notification_type text,
  notification_title text,
  notification_body text,
  notification_data jsonb,
  notification_action_url text,
  excluded_user_id uuid default null
)
returns void
language sql
security definer
set search_path = pg_catalog, public
as $$
  insert into public.notifications (
    user_id,
    type,
    title,
    body,
    data,
    course_id,
    action_url
  )
  select
    enrollments.user_id,
    notification_type,
    notification_title,
    notification_body,
    coalesce(notification_data, '{}'::jsonb),
    target_course_id,
    notification_action_url
  from public.enrollments
  where enrollments.course_id = target_course_id
    and (
      excluded_user_id is null
      or enrollments.user_id <> excluded_user_id
    );
$$;

create or replace function private.notify_enrollment_created()
returns trigger
language plpgsql
security definer
set search_path = pg_catalog, public
as $$
declare
  target_course public.courses%rowtype;
begin
  select * into target_course
  from public.courses
  where id = new.course_id;

  insert into public.notifications (
    user_id, type, title, body, data, course_id, action_url
  )
  values (
    new.user_id,
    'enrollment',
    'Welcome to ' || target_course.title,
    'You successfully enrolled in this course.',
    jsonb_build_object('course_id', new.course_id),
    new.course_id,
    '/courses/' || new.course_id
  );

  insert into public.notifications (
    user_id, type, title, body, data, course_id, action_url
  )
  values (
    target_course.instructor_id,
    'enrollment',
    'New student enrollment',
    coalesce(nullif(new.student_name, ''), 'A student') ||
      ' enrolled in ' || target_course.title || '.',
    jsonb_build_object(
      'course_id', new.course_id,
      'student_id', new.user_id
    ),
    new.course_id,
    '/courses/' || new.course_id || '/students'
  );
  return new;
end;
$$;

drop trigger if exists notify_enrollment_created on public.enrollments;
create trigger notify_enrollment_created
after insert on public.enrollments
for each row execute function private.notify_enrollment_created();

create or replace function private.notify_lesson_published()
returns trigger
language plpgsql
security definer
set search_path = pg_catalog, public, private
as $$
begin
  if new.is_published
     and (tg_op = 'INSERT' or not coalesce(old.is_published, false)) then
    perform private.notify_course_students(
      new.course_id,
      'newLesson',
      'New lesson available',
      new.title,
      jsonb_build_object('course_id', new.course_id, 'lesson_id', new.id),
      '/courses/' || new.course_id || '/lessons/' || new.id
    );
  end if;
  return new;
end;
$$;

drop trigger if exists notify_lesson_published on public.lessons;
create trigger notify_lesson_published
after insert or update of is_published on public.lessons
for each row execute function private.notify_lesson_published();

create or replace function private.notify_assignment_published()
returns trigger
language plpgsql
security definer
set search_path = pg_catalog, public, private
as $$
begin
  if new.is_published
     and (tg_op = 'INSERT' or not coalesce(old.is_published, false)) then
    perform private.notify_course_students(
      new.course_id,
      'newAssignment',
      'New assignment',
      new.title,
      jsonb_build_object(
        'course_id', new.course_id,
        'assignment_id', new.id
      ),
      '/courses/' || new.course_id || '/assignments/' || new.id
    );
  end if;
  return new;
end;
$$;

drop trigger if exists notify_assignment_published on public.assignments;
create trigger notify_assignment_published
after insert or update of is_published on public.assignments
for each row execute function private.notify_assignment_published();

create or replace function private.notify_quiz_published()
returns trigger
language plpgsql
security definer
set search_path = pg_catalog, public, private
as $$
begin
  if new.is_published
     and (tg_op = 'INSERT' or not coalesce(old.is_published, false)) then
    perform private.notify_course_students(
      new.course_id,
      'quizAvailable',
      'New quiz available',
      new.title,
      jsonb_build_object('course_id', new.course_id, 'quiz_id', new.id),
      '/courses/' || new.course_id || '/quizzes/' || new.id
    );
  end if;
  return new;
end;
$$;

drop trigger if exists notify_quiz_published on public.quizzes;
create trigger notify_quiz_published
after insert or update of is_published on public.quizzes
for each row execute function private.notify_quiz_published();

create or replace function private.notify_discussion_activity()
returns trigger
language plpgsql
security definer
set search_path = pg_catalog, public, private
as $$
declare
  target_thread public.threads%rowtype;
  parent_author_id uuid;
begin
  select * into target_thread
  from public.threads
  where id = new.thread_id;

  if target_thread.author_id <> new.author_id then
    insert into public.notifications (
      user_id, type, title, body, data, course_id, action_url
    )
    values (
      target_thread.author_id,
      'discussionReply',
      'New reply to your discussion',
      new.author_name || ' replied to "' || target_thread.title || '".',
      jsonb_build_object(
        'course_id', new.course_id,
        'channel_id', new.channel_id,
        'thread_id', new.thread_id,
        'reply_id', new.id
      ),
      new.course_id,
      '/courses/' || new.course_id || '/discussions/' ||
        new.channel_id || '/threads/' || new.thread_id
    );
  end if;

  if new.parent_reply_id is not null then
    select author_id into parent_author_id
    from public.replies
    where id = new.parent_reply_id;

    if parent_author_id is not null
       and parent_author_id <> new.author_id
       and parent_author_id <> target_thread.author_id then
      insert into public.notifications (
        user_id, type, title, body, data, course_id, action_url
      )
      values (
        parent_author_id,
        'discussionReply',
        'New reply to your comment',
        new.author_name || ' replied to your comment.',
        jsonb_build_object(
          'course_id', new.course_id,
          'channel_id', new.channel_id,
          'thread_id', new.thread_id,
          'reply_id', new.id
        ),
        new.course_id,
        '/courses/' || new.course_id || '/discussions/' ||
          new.channel_id || '/threads/' || new.thread_id
      );
    end if;
  end if;
  return new;
end;
$$;

drop trigger if exists notify_discussion_activity on public.replies;
create trigger notify_discussion_activity
after insert on public.replies
for each row execute function private.notify_discussion_activity();

create or replace function private.notify_announcement_created()
returns trigger
language plpgsql
security definer
set search_path = pg_catalog, public, private
as $$
declare
  announcement_channel boolean;
begin
  select is_announcement into announcement_channel
  from public.discussion_channels
  where id = new.channel_id;

  if coalesce(announcement_channel, false) then
    perform private.notify_course_students(
      new.course_id,
      'announcement',
      new.title,
      new.content,
      jsonb_build_object(
        'course_id', new.course_id,
        'channel_id', new.channel_id,
        'thread_id', new.id
      ),
      '/courses/' || new.course_id || '/discussions/' ||
        new.channel_id || '/threads/' || new.id,
      new.author_id
    );
  end if;
  return new;
end;
$$;

drop trigger if exists notify_announcement_created on public.threads;
create trigger notify_announcement_created
after insert on public.threads
for each row execute function private.notify_announcement_created();

create or replace function private.notify_assignment_graded()
returns trigger
language plpgsql
security definer
set search_path = pg_catalog, public
as $$
declare
  assignment_title text;
begin
  if new.graded_at is not null
     and (
       tg_op = 'INSERT'
       or old.graded_at is null
       or old.score is distinct from new.score
     ) then
    select title into assignment_title
    from public.assignments
    where id = new.assignment_id;

    insert into public.notifications (
      user_id, type, title, body, data, course_id, action_url
    )
    values (
      new.user_id,
      'assignmentGraded',
      'Assignment graded',
      coalesce(assignment_title, 'Your assignment') || ' has been graded.',
      jsonb_build_object(
        'course_id', new.course_id,
        'assignment_id', new.assignment_id,
        'submission_id', new.id
      ),
      new.course_id,
      '/courses/' || new.course_id || '/assignments/' || new.assignment_id
    );
  end if;
  return new;
end;
$$;

drop trigger if exists notify_assignment_graded on public.submissions;
create trigger notify_assignment_graded
after insert or update of graded_at, score on public.submissions
for each row execute function private.notify_assignment_graded();

-- Instructor-facing push events for student coursework and discussions.

create or replace function private.notify_assignment_submitted()
returns trigger
language plpgsql
security definer
set search_path = pg_catalog, public
as $$
declare
  assignment_title text;
  course_instructor_id uuid;
begin
  if new.submitted_at is null
     or new.status::text not in ('submitted', 'done') then
    return new;
  end if;

  if tg_op = 'UPDATE'
     and old.status::text in ('submitted', 'done') then
    return new;
  end if;

  select assignments.title, courses.instructor_id
  into assignment_title, course_instructor_id
  from public.assignments
  join public.courses on courses.id = assignments.course_id
  where assignments.id = new.assignment_id;

  if course_instructor_id is null or course_instructor_id = new.user_id then
    return new;
  end if;

  insert into public.notifications (
    user_id,
    type,
    title,
    body,
    data,
    course_id,
    action_url
  )
  values (
    course_instructor_id,
    'assignmentSubmitted',
    'Assignment submitted',
    coalesce(nullif(trim(new.user_display_name), ''), 'A student') ||
      ' submitted "' || coalesce(assignment_title, 'an assignment') || '".',
    jsonb_build_object(
      'course_id', new.course_id,
      'assignment_id', new.assignment_id,
      'submission_id', new.id,
      'student_id', new.user_id
    ),
    new.course_id,
    '/courses/' || new.course_id || '/assignments/' ||
      new.assignment_id || '/grade'
  );

  return new;
end;
$$;

drop trigger if exists notify_assignment_submitted on public.submissions;
create trigger notify_assignment_submitted
after insert or update of status, submitted_at on public.submissions
for each row execute function private.notify_assignment_submitted();

create or replace function private.notify_quiz_attempt_submitted()
returns trigger
language plpgsql
security definer
set search_path = pg_catalog, public
as $$
declare
  quiz_title text;
  target_course_id uuid;
  course_instructor_id uuid;
  student_name text;
begin
  if new.submitted_at is null
     or new.status::text not in ('submitted', 'graded', 'timedOut') then
    return new;
  end if;

  if tg_op = 'UPDATE' and old.submitted_at is not null then
    return new;
  end if;

  select
    quizzes.title,
    quizzes.course_id,
    courses.instructor_id,
    coalesce(
      nullif(trim(concat_ws(' ', profiles.first_name, profiles.last_name)), ''),
      nullif(trim(profiles.display_name), ''),
      'A student'
    )
  into
    quiz_title,
    target_course_id,
    course_instructor_id,
    student_name
  from public.quizzes
  join public.courses on courses.id = quizzes.course_id
  left join public.profiles on profiles.id = new.user_id
  where quizzes.id = new.quiz_id;

  if course_instructor_id is null or course_instructor_id = new.user_id then
    return new;
  end if;

  insert into public.notifications (
    user_id,
    type,
    title,
    body,
    data,
    course_id,
    action_url
  )
  values (
    course_instructor_id,
    'quizSubmitted',
    'Quiz attempt completed',
    student_name || ' completed "' || coalesce(quiz_title, 'a quiz') ||
      '" (attempt ' || new.attempt_number || ').',
    jsonb_build_object(
      'course_id', target_course_id,
      'quiz_id', new.quiz_id,
      'attempt_id', new.id,
      'student_id', new.user_id
    ),
    target_course_id,
    '/courses/' || target_course_id || '/quizzes/' || new.quiz_id
  );

  return new;
end;
$$;

drop trigger if exists notify_quiz_attempt_submitted on public.quiz_attempts;
create trigger notify_quiz_attempt_submitted
after insert or update of status, submitted_at on public.quiz_attempts
for each row execute function private.notify_quiz_attempt_submitted();

create or replace function private.notify_instructor_new_discussion()
returns trigger
language plpgsql
security definer
set search_path = pg_catalog, public
as $$
declare
  course_instructor_id uuid;
  announcement_channel boolean;
  student_name text;
begin
  select courses.instructor_id, discussion_channels.is_announcement
  into course_instructor_id, announcement_channel
  from public.courses
  join public.discussion_channels
    on discussion_channels.course_id = courses.id
  where courses.id = new.course_id
    and discussion_channels.id = new.channel_id;

  if course_instructor_id is null
     or course_instructor_id = new.author_id
     or coalesce(announcement_channel, false) then
    return new;
  end if;

  select coalesce(
    nullif(trim(concat_ws(' ', first_name, last_name)), ''),
    nullif(trim(display_name), ''),
    'A student'
  )
  into student_name
  from public.profiles
  where id = new.author_id;

  insert into public.notifications (
    user_id,
    type,
    title,
    body,
    data,
    course_id,
    action_url
  )
  values (
    course_instructor_id,
    'discussionActivity',
    'New student discussion',
    coalesce(student_name, 'A student') || ' posted "' || new.title || '".',
    jsonb_build_object(
      'course_id', new.course_id,
      'channel_id', new.channel_id,
      'thread_id', new.id,
      'student_id', new.author_id
    ),
    new.course_id,
    '/courses/' || new.course_id || '/discussions/' ||
      new.channel_id || '/threads/' || new.id
  );

  return new;
end;
$$;

drop trigger if exists notify_instructor_new_discussion on public.threads;
create trigger notify_instructor_new_discussion
after insert on public.threads
for each row execute function private.notify_instructor_new_discussion();

revoke all on function private.notify_assignment_submitted()
  from public, anon, authenticated;
revoke all on function private.notify_quiz_attempt_submitted()
  from public, anon, authenticated;
revoke all on function private.notify_instructor_new_discussion()
  from public, anon, authenticated;


-- The dispatcher is inert until both Vault entries exist. This keeps database
-- writes reliable while allowing credentials to be configured out of band.
create or replace function private.dispatch_push_notification()
returns trigger
language plpgsql
security definer
set search_path = pg_catalog, public, vault, net
as $$
declare
  push_url text;
  webhook_secret text;
begin
  select decrypted_secret into push_url
  from vault.decrypted_secrets
  where name = 'push_webhook_url'
  limit 1;

  select decrypted_secret into webhook_secret
  from vault.decrypted_secrets
  where name = 'push_webhook_secret'
  limit 1;

  if push_url is null or webhook_secret is null then
    return new;
  end if;

  perform net.http_post(
    url := push_url,
    headers := jsonb_build_object(
      'Content-Type', 'application/json',
      'x-bitclass-webhook-secret', webhook_secret
    ),
    body := jsonb_build_object(
      'type', 'INSERT',
      'schema', 'public',
      'table', 'notifications',
      'record', to_jsonb(new)
    ),
    timeout_milliseconds := 10000
  );
  return new;
end;
$$;

drop trigger if exists dispatch_push_notification on public.notifications;
create trigger dispatch_push_notification
after insert on public.notifications
for each row execute function private.dispatch_push_notification();

revoke all on function private.notify_course_students(
  uuid, text, text, text, jsonb, text, uuid
) from public, anon, authenticated;
revoke all on function private.notify_enrollment_created()
  from public, anon, authenticated;
revoke all on function private.notify_lesson_published()
  from public, anon, authenticated;
revoke all on function private.notify_assignment_published()
  from public, anon, authenticated;
revoke all on function private.notify_quiz_published()
  from public, anon, authenticated;
revoke all on function private.notify_discussion_activity()
  from public, anon, authenticated;
revoke all on function private.notify_announcement_created()
  from public, anon, authenticated;
revoke all on function private.notify_assignment_graded()
  from public, anon, authenticated;
revoke all on function private.dispatch_push_notification()
  from public, anon, authenticated;
