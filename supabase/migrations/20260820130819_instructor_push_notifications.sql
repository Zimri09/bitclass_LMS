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
