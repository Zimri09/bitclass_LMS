-- Free, application-level administrator audit history and account controls.
-- Supabase Platform Audit Logs are not required by this implementation.

alter table public.profiles
  add column if not exists is_suspended boolean not null default false,
  add column if not exists suspended_at timestamp with time zone,
  add column if not exists suspended_by uuid;

do $$
begin
  if not exists (
    select 1
    from pg_constraint
    where conname = 'profiles_suspended_by_fkey'
      and conrelid = 'public.profiles'::regclass
  ) then
    alter table public.profiles
      add constraint profiles_suspended_by_fkey
      foreign key (suspended_by)
      references public.profiles(id)
      on delete set null;
  end if;

  if not exists (
    select 1
    from pg_constraint
    where conname = 'profiles_suspension_state_check'
      and conrelid = 'public.profiles'::regclass
  ) then
    alter table public.profiles
      add constraint profiles_suspension_state_check
      check (
        (is_suspended and suspended_at is not null)
        or
        (not is_suspended and suspended_at is null and suspended_by is null)
      );
  end if;
end
$$;

create index if not exists profiles_suspended_by_idx
  on public.profiles (suspended_by)
  where suspended_by is not null;

create index if not exists profiles_is_suspended_idx
  on public.profiles (is_suspended)
  where is_suspended;

create table if not exists public.admin_audit_logs (
  id uuid primary key default gen_random_uuid(),
  actor_id uuid references public.profiles(id) on delete set null,
  actor_email text not null,
  action text not null,
  target_type text not null,
  target_id text,
  reason text,
  previous_values jsonb not null default '{}'::jsonb,
  new_values jsonb not null default '{}'::jsonb,
  created_at timestamp with time zone not null default timezone('utc', now())
);

create index if not exists admin_audit_logs_created_at_idx
  on public.admin_audit_logs (created_at desc);

create index if not exists admin_audit_logs_actor_created_idx
  on public.admin_audit_logs (actor_id, created_at desc);

create index if not exists admin_audit_logs_target_created_idx
  on public.admin_audit_logs (target_type, target_id, created_at desc);

alter table public.admin_audit_logs enable row level security;

drop policy if exists "admin audit logs: admins read" on public.admin_audit_logs;
create policy "admin audit logs: admins read"
on public.admin_audit_logs
for select
to authenticated
using ((select private.is_admin()));

revoke all on table public.admin_audit_logs from public, anon, authenticated;
grant select on table public.admin_audit_logs to authenticated;
grant all on table public.admin_audit_logs to service_role;

-- A normal signed-in user may only edit non-privileged profile fields.
-- Table-level UPDATE would otherwise allow new privileged columns to be
-- changed by the profile owner despite row-level security.
revoke update on table public.profiles from anon, authenticated;
grant update (
  display_name,
  avatar_url,
  bio,
  first_name,
  last_name,
  age,
  updated_at
) on table public.profiles to authenticated;

create or replace function private.is_admin()
returns boolean
language sql
stable
security definer
set search_path = pg_catalog, public, auth
as $$
  select exists (
    select 1
    from public.profiles
    where id = (select auth.uid())
      and role = 'admin'
      and not is_suspended
  );
$$;

create or replace function private.is_staff()
returns boolean
language sql
stable
security definer
set search_path = pg_catalog, public, auth
as $$
  select exists (
    select 1
    from public.profiles
    where id = (select auth.uid())
      and role in ('instructor', 'admin')
      and not is_suspended
  );
$$;

revoke all on function private.is_admin() from public, anon;
revoke all on function private.is_staff() from public, anon;
grant execute on function private.is_admin() to authenticated;
grant execute on function private.is_staff() to authenticated;

create or replace function private.audit_admin_course_change()
returns trigger
language plpgsql
security definer
set search_path = pg_catalog, public, auth
as $$
declare
  acting_user_id uuid := (select auth.uid());
  acting_user_email text;
  audit_action text;
  old_values jsonb := '{}'::jsonb;
  next_values jsonb := '{}'::jsonb;
begin
  if acting_user_id is null or not (select private.is_admin()) then
    return coalesce(new, old);
  end if;

  select email
  into acting_user_email
  from public.profiles
  where id = acting_user_id;

  if tg_op = 'INSERT' then
    audit_action := 'course.created';
    next_values := jsonb_build_object(
      'title', new.title,
      'is_published', new.is_published,
      'instructor_id', new.instructor_id
    );
  elsif tg_op = 'DELETE' then
    audit_action := 'course.deleted';
    old_values := jsonb_build_object(
      'title', old.title,
      'is_published', old.is_published,
      'instructor_id', old.instructor_id
    );
  else
    audit_action := case
      when old.is_published is distinct from new.is_published
        then case when new.is_published
          then 'course.published'
          else 'course.unpublished'
        end
      else 'course.updated'
    end;
    old_values := jsonb_build_object(
      'title', old.title,
      'is_published', old.is_published,
      'instructor_id', old.instructor_id
    );
    next_values := jsonb_build_object(
      'title', new.title,
      'is_published', new.is_published,
      'instructor_id', new.instructor_id
    );
  end if;

  insert into public.admin_audit_logs (
    actor_id,
    actor_email,
    action,
    target_type,
    target_id,
    previous_values,
    new_values
  ) values (
    acting_user_id,
    coalesce(acting_user_email, 'unknown-admin'),
    audit_action,
    'course',
    coalesce(new.id, old.id)::text,
    old_values,
    next_values
  );

  return coalesce(new, old);
end;
$$;

revoke all on function private.audit_admin_course_change()
  from public, anon, authenticated, service_role;

drop trigger if exists courses_audit_admin_change on public.courses;
create trigger courses_audit_admin_change
after insert or update or delete on public.courses
for each row execute function private.audit_admin_course_change();

