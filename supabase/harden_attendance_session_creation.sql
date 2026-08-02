-- =============================================================================
-- Harden attendance session creation with server-time and overlap validation.
-- Follow-up patch only: requires add_course_attendance.sql and harden_rls.sql.
-- Existing hosted projects should not rerun an already-recorded migration.
-- =============================================================================

alter table public.attendance_sessions
  drop constraint if exists attendance_sessions_time_order;

alter table public.attendance_sessions
  add constraint attendance_sessions_time_order check (
    opens_at < late_at
    and late_at < closes_at
  );

create or replace function public.create_attendance_session(
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

revoke all on function public.create_attendance_session(
  uuid, date, timestamptz, timestamptz, timestamptz
) from public, anon;

grant execute on function public.create_attendance_session(
  uuid, date, timestamptz, timestamptz, timestamptz
) to authenticated;
