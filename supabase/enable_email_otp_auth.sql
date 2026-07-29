-- Enforce email OTP verification before a public profile can exist.
-- Apply this once, then complete the dashboard steps in AUTH_OTP_SETUP.md.

begin;

drop trigger if exists on_auth_user_created_before on auth.users;
drop function if exists public.auto_confirm_user();

drop trigger if exists on_auth_user_created on auth.users;
drop trigger if exists on_auth_user_email_verified on auth.users;

create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  requested_role text := new.raw_user_meta_data->>'role';
  given_name text := nullif(trim(new.raw_user_meta_data->>'first_name'), '');
  family_name text := nullif(trim(new.raw_user_meta_data->>'last_name'), '');
begin
  if new.email_confirmed_at is null then
    return new;
  end if;

  if given_name is null or family_name is null then
    raise exception 'Registration requires first_name and last_name metadata';
  end if;

  if requested_role not in ('student', 'instructor') then
    raise exception 'Registration role must be student or instructor';
  end if;

  insert into public.profiles (
    id,
    email,
    display_name,
    first_name,
    last_name,
    role
  )
  values (
    new.id,
    lower(new.email),
    concat_ws(' ', given_name, family_name),
    given_name,
    family_name,
    requested_role::public.user_role
  )
  on conflict (id) do update set
    email = excluded.email,
    display_name = excluded.display_name,
    first_name = excluded.first_name,
    last_name = excluded.last_name,
    updated_at = timezone('utc', now());

  return new;
end;
$$;

revoke all on function public.handle_new_user() from public;
revoke all on function public.handle_new_user() from anon;
revoke all on function public.handle_new_user() from authenticated;

create trigger on_auth_user_email_verified
  after update of email_confirmed_at on auth.users
  for each row
  when (
    old.email_confirmed_at is null
    and new.email_confirmed_at is not null
  )
  execute function public.handle_new_user();

drop policy if exists "profiles: self insert" on public.profiles;
drop policy if exists "profiles write own" on public.profiles;

-- Remove partial profiles left by an older profile-on-signup trigger.
delete from public.profiles profile
using auth.users auth_user
where profile.id = auth_user.id
  and auth_user.email_confirmed_at is null;

commit;
