-- Simplify attendance to Opening -> Late -> Closing.
-- Existing sessions keep their original present window by using the former
-- present deadline as the new late boundary.

drop function if exists public.create_attendance_session(
  uuid, date, timestamptz, timestamptz, timestamptz, timestamptz
);

alter table public.attendance_sessions
  drop constraint if exists attendance_sessions_deadline_order;

alter table public.attendance_sessions
  add column if not exists late_at timestamptz;

update public.attendance_sessions
set late_at = present_deadline
where late_at is null;

alter table public.attendance_sessions
  alter column late_at set not null,
  drop column present_deadline,
  drop column late_deadline;

alter table public.attendance_sessions
  add constraint attendance_sessions_time_order check (
    opens_at < late_at
    and late_at < closes_at
  );

create function public.create_attendance_session(
  target_course_id uuid,
  target_attendance_date date,
  target_opens_at timestamptz,
  target_late_at timestamptz,
  target_closes_at timestamptz
)
returns uuid
language plpgsql
security definer
set search_path = pg_catalog, public, auth, private
as $$
declare
  actor_id uuid := (select auth.uid());
  created_session_id uuid;
  server_now timestamptz := clock_timestamp();
  server_date date := (server_now at time zone 'Asia/Manila')::date;
begin
  if actor_id is null then
    raise exception 'You must be signed in to create attendance.';
  end if;

  if not (select private.can_manage_course(target_course_id)) then
    raise exception 'Only the course instructor can create attendance.';
  end if;

  -- Serialize creation per course so concurrent requests cannot overlap.
  perform 1
  from public.courses
  where id = target_course_id
  for update;

  if not found then
    raise exception 'Course not found.';
  end if;

  if target_attendance_date is null
     or target_opens_at is null
     or target_late_at is null
     or target_closes_at is null then
    raise exception 'Attendance date and all session times are required.';
  end if;

  if target_attendance_date < server_date then
    raise exception 'Attendance date cannot be in the past.';
  end if;

  if target_attendance_date <>
     (target_opens_at at time zone 'Asia/Manila')::date then
    raise exception 'Opening time must be on the attendance date.';
  end if;

  if target_opens_at < server_now then
    raise exception 'Opening time cannot be in the past.';
  end if;

  if target_late_at <= target_opens_at then
    raise exception 'Late time must be after the opening time.';
  end if;

  if target_closes_at <= target_late_at then
    raise exception 'Closing time must be after the Late time.';
  end if;

  if exists (
    select 1
    from public.attendance_sessions
    where course_id = target_course_id
      and attendance_date = target_attendance_date
  ) then
    raise exception 'An attendance session already exists for this date.';
  end if;

  if exists (
    select 1
    from public.attendance_sessions
    where course_id = target_course_id
      and tstzrange(opens_at, closes_at, '[)') &&
          tstzrange(target_opens_at, target_closes_at, '[)')
  ) then
    raise exception 'This attendance window overlaps an existing session.';
  end if;

  insert into public.attendance_sessions (
    course_id,
    attendance_date,
    opens_at,
    late_at,
    closes_at,
    created_by
  ) values (
    target_course_id,
    target_attendance_date,
    target_opens_at,
    target_late_at,
    target_closes_at,
    actor_id
  )
  returning id into created_session_id;

  insert into public.attendance_records (
    course_id,
    session_id,
    student_id,
    attendance_date,
    status,
    created_by,
    last_modified_by
  )
  select
    target_course_id,
    created_session_id,
    enrollment.user_id,
    target_attendance_date,
    'absent',
    actor_id,
    actor_id
  from public.enrollments as enrollment
  where enrollment.course_id = target_course_id
  on conflict (session_id, student_id) do nothing;

  return created_session_id;
end;
$$;

create or replace function public.check_in_attendance(target_session_id uuid)
returns table (
  record_id uuid,
  attendance_status text,
  checked_in_at timestamptz,
  server_time timestamptz
)
language plpgsql
security definer
set search_path = pg_catalog, public, auth
as $$
declare
  actor_id uuid := (select auth.uid());
  session_row public.attendance_sessions;
  record_row public.attendance_records;
  server_now timestamptz := clock_timestamp();
  computed_status text;
begin
  if actor_id is null then
    raise exception 'You must be signed in to check in.';
  end if;

  select * into session_row
  from public.attendance_sessions
  where id = target_session_id;

  if not found then
    raise exception 'Attendance session not found.';
  end if;

  if not exists (
    select 1
    from public.enrollments
    where course_id = session_row.course_id
      and user_id = actor_id
  ) then
    raise exception 'You are not enrolled in this course.';
  end if;

  if server_now < session_row.opens_at then
    raise exception 'Attendance is not open yet.';
  end if;

  if server_now >= session_row.closes_at then
    raise exception 'Attendance session is closed.';
  end if;

  insert into public.attendance_records (
    course_id,
    session_id,
    student_id,
    attendance_date,
    status,
    created_by,
    last_modified_by
  ) values (
    session_row.course_id,
    session_row.id,
    actor_id,
    session_row.attendance_date,
    'absent',
    session_row.created_by,
    actor_id
  )
  on conflict (session_id, student_id) do nothing;

  select * into record_row
  from public.attendance_records
  where session_id = target_session_id
    and student_id = actor_id
  for update;

  if record_row.check_in_at is not null then
    raise exception 'You have already checked in for this session.';
  end if;

  computed_status := case
    when server_now < session_row.late_at then 'present'
    else 'late'
  end;

  update public.attendance_records
  set
    check_in_at = server_now,
    status = computed_status,
    last_modified_by = actor_id
  where id = record_row.id;

  return query
  select record_row.id, computed_status, server_now, server_now;
end;
$$;

create or replace function private.add_new_enrollment_to_attendance()
returns trigger
language plpgsql
security definer
set search_path = pg_catalog, public
as $$
begin
  insert into public.attendance_records (
    course_id,
    session_id,
    student_id,
    attendance_date,
    status,
    created_by,
    last_modified_by
  )
  select
    new.course_id,
    session.id,
    new.user_id,
    session.attendance_date,
    'absent',
    session.created_by,
    session.created_by
  from public.attendance_sessions as session
  where session.course_id = new.course_id
    and session.closes_at > clock_timestamp()
  on conflict (session_id, student_id) do nothing;
  return new;
end;
$$;

revoke all on function public.create_attendance_session(
  uuid, date, timestamptz, timestamptz, timestamptz
) from public, anon;
revoke all on function public.check_in_attendance(uuid) from public, anon;
revoke all on function private.add_new_enrollment_to_attendance() from public;

grant execute on function public.create_attendance_session(
  uuid, date, timestamptz, timestamptz, timestamptz
) to authenticated;
grant execute on function public.check_in_attendance(uuid) to authenticated;
