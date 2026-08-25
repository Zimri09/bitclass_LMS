-- Keep privileged implementations outside the exposed API schema. Public RPCs
-- remain SECURITY INVOKER wrappers with the same names and argument contracts.

alter function public.check_in_attendance(uuid) set schema private;
alter function public.create_attendance_session(
  uuid, date, timestamptz, timestamptz, timestamptz
) set schema private;
alter function public.delete_current_user_account() set schema private;
alter function public.get_course_roster(uuid) set schema private;
alter function public.join_course_by_code(text) set schema private;
alter function public.unsubmit_assignment(uuid) set schema private;
alter function public.update_attendance_record(uuid, text, text)
  set schema private;

create function public.check_in_attendance(target_session_id uuid)
returns table (
  record_id uuid,
  attendance_status text,
  checked_in_at timestamptz,
  server_time timestamptz
)
language sql
security invoker
set search_path = pg_catalog, public, private
as $$
  select * from private.check_in_attendance(target_session_id);
$$;

create function public.create_attendance_session(
  target_course_id uuid,
  target_attendance_date date,
  target_opens_at timestamptz,
  target_late_at timestamptz,
  target_closes_at timestamptz
)
returns uuid
language sql
security invoker
set search_path = pg_catalog, public, private
as $$
  select private.create_attendance_session(
    target_course_id,
    target_attendance_date,
    target_opens_at,
    target_late_at,
    target_closes_at
  );
$$;

create function public.delete_current_user_account()
returns void
language sql
security invoker
set search_path = pg_catalog, public, private
as $$
  select private.delete_current_user_account();
$$;

create function public.get_course_roster(target_course_id uuid)
returns table (user_id uuid, display_name text, avatar_url text)
language sql
stable
security invoker
set search_path = pg_catalog, public, private
as $$
  select * from private.get_course_roster(target_course_id);
$$;

create function public.join_course_by_code(join_code text)
returns table (course_id uuid, enrollment_id uuid)
language sql
security invoker
set search_path = pg_catalog, public, private
as $$
  select * from private.join_course_by_code(join_code);
$$;

create function public.unsubmit_assignment(p_assignment_id uuid)
returns public.submissions
language sql
security invoker
set search_path = pg_catalog, public, private
as $$
  select private.unsubmit_assignment(p_assignment_id);
$$;

create function public.update_attendance_record(
  target_record_id uuid,
  corrected_status text,
  correction_note text default null
)
returns void
language sql
security invoker
set search_path = pg_catalog, public, private
as $$
  select private.update_attendance_record(
    target_record_id,
    corrected_status,
    correction_note
  );
$$;

grant usage on schema private to authenticated, service_role;

revoke all on function private.check_in_attendance(uuid)
  from public, anon, authenticated, service_role;
revoke all on function private.create_attendance_session(
  uuid, date, timestamptz, timestamptz, timestamptz
) from public, anon, authenticated, service_role;
revoke all on function private.delete_current_user_account()
  from public, anon, authenticated, service_role;
revoke all on function private.get_course_roster(uuid)
  from public, anon, authenticated, service_role;
revoke all on function private.join_course_by_code(text)
  from public, anon, authenticated, service_role;
revoke all on function private.unsubmit_assignment(uuid)
  from public, anon, authenticated, service_role;
revoke all on function private.update_attendance_record(uuid, text, text)
  from public, anon, authenticated, service_role;

grant execute on function private.check_in_attendance(uuid)
  to authenticated, service_role;
grant execute on function private.create_attendance_session(
  uuid, date, timestamptz, timestamptz, timestamptz
) to authenticated, service_role;
grant execute on function private.delete_current_user_account()
  to authenticated, service_role;
grant execute on function private.get_course_roster(uuid)
  to authenticated, service_role;
grant execute on function private.join_course_by_code(text)
  to authenticated, service_role;
grant execute on function private.unsubmit_assignment(uuid)
  to authenticated, service_role;
grant execute on function private.update_attendance_record(uuid, text, text)
  to authenticated, service_role;

revoke all on function public.check_in_attendance(uuid) from public, anon;
revoke all on function public.create_attendance_session(
  uuid, date, timestamptz, timestamptz, timestamptz
) from public, anon;
revoke all on function public.delete_current_user_account() from public, anon;
revoke all on function public.get_course_roster(uuid) from public, anon;
revoke all on function public.join_course_by_code(text) from public, anon;
revoke all on function public.unsubmit_assignment(uuid) from public, anon;
revoke all on function public.update_attendance_record(uuid, text, text)
  from public, anon;

grant execute on function public.check_in_attendance(uuid) to authenticated;
grant execute on function public.create_attendance_session(
  uuid, date, timestamptz, timestamptz, timestamptz
) to authenticated;
grant execute on function public.delete_current_user_account()
  to authenticated;
grant execute on function public.get_course_roster(uuid) to authenticated;
grant execute on function public.join_course_by_code(text) to authenticated;
grant execute on function public.unsubmit_assignment(uuid) to authenticated;
grant execute on function public.update_attendance_record(uuid, text, text)
  to authenticated;
