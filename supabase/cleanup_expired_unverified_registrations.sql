-- Remove expired BitClass registrations so the email can be used again.
-- Keep this interval aligned with the hosted Email OTP expiration setting.

create extension if not exists pg_cron;

create schema if not exists private;
revoke all on schema private from public;

create or replace function private.cleanup_expired_unverified_registrations()
returns integer
language plpgsql
security definer
set search_path = ''
as $$
declare
  deleted_count integer;
begin
  with deleted_users as (
    delete from auth.users as auth_user
    where auth_user.email_confirmed_at is null
      and auth_user.email is not null
      and coalesce(
        auth_user.confirmation_sent_at,
        auth_user.created_at
      ) < now() - interval '10 minutes'
      and auth_user.raw_user_meta_data->>'role' in ('student', 'instructor')
    returning auth_user.id
  )
  select count(*)::integer
  into deleted_count
  from deleted_users;

  return deleted_count;
end;
$$;

revoke all on function private.cleanup_expired_unverified_registrations()
  from public;
revoke all on function private.cleanup_expired_unverified_registrations()
  from anon;
revoke all on function private.cleanup_expired_unverified_registrations()
  from authenticated;

select cron.schedule(
  'cleanup-expired-bitclass-registrations',
  '* * * * *',
  'select private.cleanup_expired_unverified_registrations();'
);
