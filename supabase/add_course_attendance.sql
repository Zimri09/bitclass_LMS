-- =============================================================================
-- Course attendance for BitClass LMS
-- Run after schema.sql and harden_rls.sql.
-- =============================================================================

create table if not exists public.attendance_sessions (
  id uuid primary key default gen_random_uuid(),
  course_id uuid not null references public.courses(id) on delete cascade,
  attendance_date date not null,
  opens_at timestamptz not null,
  late_at timestamptz not null,
  closes_at timestamptz not null,
  created_by uuid not null references public.profiles(id) on delete cascade,
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now()),
  constraint attendance_sessions_time_order check (
    opens_at < late_at
    and late_at < closes_at
  ),
  constraint attendance_sessions_course_date_unique
    unique (course_id, attendance_date)
);

create table if not exists public.attendance_records (
  id uuid primary key default gen_random_uuid(),
  course_id uuid not null references public.courses(id) on delete cascade,
  session_id uuid not null references public.attendance_sessions(id)
    on delete cascade,
  student_id uuid not null references public.profiles(id) on delete cascade,
  attendance_date date not null,
  check_in_at timestamptz,
  status text not null default 'absent' check (
    status in ('present', 'late', 'absent', 'excused')
  ),
  note text,
  created_by uuid not null references public.profiles(id) on delete cascade,
  last_modified_by uuid not null references public.profiles(id)
    on delete cascade,
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now()),
  constraint attendance_records_session_student_unique
    unique (session_id, student_id)
);

create table if not exists public.attendance_record_changes (
  id uuid primary key default gen_random_uuid(),
  record_id uuid not null references public.attendance_records(id)
    on delete cascade,
  course_id uuid not null references public.courses(id) on delete cascade,
  session_id uuid not null references public.attendance_sessions(id)
    on delete cascade,
  student_id uuid not null references public.profiles(id) on delete cascade,
  previous_status text not null check (
    previous_status in ('present', 'late', 'absent', 'excused')
  ),
  updated_status text not null check (
    updated_status in ('present', 'late', 'absent', 'excused')
  ),
  previous_note text,
  updated_note text,
  change_type text not null check (change_type in ('check_in', 'manual')),
  changed_by uuid not null references public.profiles(id) on delete cascade,
  changed_at timestamptz not null default timezone('utc', now())
);

create index if not exists attendance_sessions_course_date_idx
  on public.attendance_sessions (course_id, attendance_date desc);
create index if not exists attendance_sessions_created_by_idx
  on public.attendance_sessions (created_by);
create index if not exists attendance_records_course_session_idx
  on public.attendance_records (course_id, session_id);
create index if not exists attendance_records_session_idx
  on public.attendance_records (session_id);
create index if not exists attendance_records_student_date_idx
  on public.attendance_records (student_id, attendance_date desc);
create index if not exists attendance_records_created_by_idx
  on public.attendance_records (created_by);
create index if not exists attendance_records_modified_by_idx
  on public.attendance_records (last_modified_by);
create index if not exists attendance_changes_record_time_idx
  on public.attendance_record_changes (record_id, changed_at desc);
create index if not exists attendance_changes_course_idx
  on public.attendance_record_changes (course_id);
create index if not exists attendance_changes_session_idx
  on public.attendance_record_changes (session_id);
create index if not exists attendance_changes_student_idx
  on public.attendance_record_changes (student_id);
create index if not exists attendance_changes_changed_by_idx
  on public.attendance_record_changes (changed_by);

drop trigger if exists attendance_sessions_updated_at
  on public.attendance_sessions;
create trigger attendance_sessions_updated_at
before update on public.attendance_sessions
for each row execute function public.set_updated_at();

drop trigger if exists attendance_records_updated_at
  on public.attendance_records;
create trigger attendance_records_updated_at
before update on public.attendance_records
for each row execute function public.set_updated_at();

create or replace function private.audit_attendance_record_change()
returns trigger
language plpgsql
security definer
set search_path = pg_catalog, public, auth
as $$
declare
  actor_id uuid := coalesce((select auth.uid()), new.last_modified_by);
begin
  if old.status is distinct from new.status
     or old.note is distinct from new.note then
    insert into public.attendance_record_changes (
      record_id,
      course_id,
      session_id,
      student_id,
      previous_status,
      updated_status,
      previous_note,
      updated_note,
      change_type,
      changed_by
    ) values (
      new.id,
      new.course_id,
      new.session_id,
      new.student_id,
      old.status,
      new.status,
      old.note,
      new.note,
      case
        when old.check_in_at is null and new.check_in_at is not null
          then 'check_in'
        else 'manual'
      end,
      actor_id
    );
  end if;
  return new;
end;
$$;

revoke all on function private.audit_attendance_record_change() from public;

drop trigger if exists attendance_records_audit_change
  on public.attendance_records;
create trigger attendance_records_audit_change
after update of status, note, check_in_at on public.attendance_records
for each row execute function private.audit_attendance_record_change();

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

create or replace function public.update_attendance_record(
  target_record_id uuid,
  corrected_status text,
  correction_note text default null
)
returns void
language plpgsql
security definer
set search_path = pg_catalog, public, auth, private
as $$
declare
  actor_id uuid := (select auth.uid());
  target_course_id uuid;
begin
  if actor_id is null then
    raise exception 'You must be signed in to update attendance.';
  end if;

  if corrected_status not in ('present', 'late', 'absent', 'excused') then
    raise exception 'Invalid attendance status.';
  end if;

  select course_id into target_course_id
  from public.attendance_records
  where id = target_record_id;

  if target_course_id is null then
    raise exception 'Attendance record not found.';
  end if;

  if not (select private.can_manage_course(target_course_id)) then
    raise exception 'Only the course instructor can update attendance.';
  end if;

  update public.attendance_records
  set
    status = corrected_status,
    note = nullif(trim(correction_note), ''),
    last_modified_by = actor_id
  where id = target_record_id;
end;
$$;

create or replace function public.attendance_server_now()
returns timestamptz
language sql
volatile
security invoker
set search_path = pg_catalog
as $$
  select clock_timestamp();
$$;

-- Add students who enroll after an upcoming session was created.
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

revoke all on function private.add_new_enrollment_to_attendance() from public;

drop trigger if exists enrollments_add_to_upcoming_attendance
  on public.enrollments;
create trigger enrollments_add_to_upcoming_attendance
after insert on public.enrollments
for each row execute function private.add_new_enrollment_to_attendance();

alter table public.attendance_sessions enable row level security;
alter table public.attendance_records enable row level security;
alter table public.attendance_record_changes enable row level security;

drop policy if exists "attendance sessions: course members read"
  on public.attendance_sessions;
create policy "attendance sessions: course members read"
  on public.attendance_sessions for select to authenticated
  using ((select private.is_course_member(course_id)));

drop policy if exists "attendance records: self or manager read"
  on public.attendance_records;
create policy "attendance records: self or manager read"
  on public.attendance_records for select to authenticated
  using (
    student_id = (select auth.uid())
    or (select private.can_manage_course(course_id))
  );

drop policy if exists "attendance changes: self or manager read"
  on public.attendance_record_changes;
create policy "attendance changes: self or manager read"
  on public.attendance_record_changes for select to authenticated
  using (
    student_id = (select auth.uid())
    or (select private.can_manage_course(course_id))
  );

revoke all on table public.attendance_sessions from anon;
revoke all on table public.attendance_records from anon;
revoke all on table public.attendance_record_changes from anon;
revoke insert, update, delete on table public.attendance_sessions
  from authenticated;
revoke insert, update, delete on table public.attendance_records
  from authenticated;
revoke insert, update, delete on table public.attendance_record_changes
  from authenticated;
grant select on table public.attendance_sessions to authenticated;
grant select on table public.attendance_records to authenticated;
grant select on table public.attendance_record_changes to authenticated;

revoke all on function public.create_attendance_session(
  uuid, date, timestamptz, timestamptz, timestamptz
) from public, anon;
revoke all on function public.check_in_attendance(uuid) from public, anon;
revoke all on function public.update_attendance_record(uuid, text, text)
  from public, anon;
revoke all on function public.attendance_server_now() from public, anon;
grant execute on function public.create_attendance_session(
  uuid, date, timestamptz, timestamptz, timestamptz
) to authenticated;
grant execute on function public.check_in_attendance(uuid) to authenticated;
grant execute on function public.update_attendance_record(uuid, text, text)
  to authenticated;
grant execute on function public.attendance_server_now() to authenticated;

do $$
begin
  if not exists (
    select 1
    from pg_publication_tables
    where pubname = 'supabase_realtime'
      and schemaname = 'public'
      and tablename = 'attendance_sessions'
  ) then
    alter publication supabase_realtime
      add table public.attendance_sessions;
  end if;

  if not exists (
    select 1
    from pg_publication_tables
    where pubname = 'supabase_realtime'
      and schemaname = 'public'
      and tablename = 'attendance_records'
  ) then
    alter publication supabase_realtime
      add table public.attendance_records;
  end if;
end;
$$;
