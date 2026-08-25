-- Allow Google OAuth only for BISU student accounts and create their profiles.
create or replace function public.hook_restrict_google_signup_to_bisu(event jsonb)
returns jsonb
language plpgsql
stable
set search_path = ''
as $$
declare
  signup_provider text := lower(coalesce(
    event->'user'->'app_metadata'->>'provider',
    ''
  ));
  signup_email text := lower(trim(coalesce(event->'user'->>'email', '')));
begin
  if signup_provider <> 'google' then
    return '{}'::jsonb;
  end if;

  if split_part(signup_email, '@', 1) = ''
     or split_part(signup_email, '@', 2) <> 'bisu.edu.ph' then
    return jsonb_build_object(
      'error', jsonb_build_object(
        'message', 'Use your verified @bisu.edu.ph Google account.',
        'http_code', 403
      )
    );
  end if;

  return '{}'::jsonb;
end;
$$;

grant usage on schema public to supabase_auth_admin;
grant execute on function public.hook_restrict_google_signup_to_bisu(jsonb)
  to supabase_auth_admin;
revoke execute on function public.hook_restrict_google_signup_to_bisu(jsonb)
  from public, anon, authenticated;

create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  requested_role text := new.raw_user_meta_data->>'role';
  auth_provider text := lower(coalesce(new.raw_app_meta_data->>'provider', ''));
  is_google boolean := auth_provider = 'google'
    or coalesce(new.raw_app_meta_data->'providers', '[]'::jsonb) ? 'google';
  normalized_email text := lower(trim(coalesce(new.email, '')));
  full_name text := nullif(trim(coalesce(
    new.raw_user_meta_data->>'full_name',
    new.raw_user_meta_data->>'name',
    ''
  )), '');
  given_name text := nullif(trim(coalesce(
    new.raw_user_meta_data->>'first_name',
    new.raw_user_meta_data->>'given_name',
    ''
  )), '');
  family_name text := nullif(trim(coalesce(
    new.raw_user_meta_data->>'last_name',
    new.raw_user_meta_data->>'family_name',
    ''
  )), '');
  profile_avatar_url text := nullif(trim(coalesce(
    new.raw_user_meta_data->>'avatar_url',
    new.raw_user_meta_data->>'picture',
    ''
  )), '');
  resolved_display_name text;
begin
  if new.email_confirmed_at is null then
    return new;
  end if;

  if is_google then
    if split_part(normalized_email, '@', 1) = ''
       or split_part(normalized_email, '@', 2) <> 'bisu.edu.ph' then
      raise exception 'Google signup requires a verified @bisu.edu.ph account';
    end if;

    requested_role := 'student';
    given_name := coalesce(
      given_name,
      nullif(split_part(full_name, ' ', 1), ''),
      nullif(split_part(normalized_email, '@', 1), '')
    );
    if family_name is null
       and full_name is not null
       and position(' ' in full_name) > 0 then
      family_name := nullif(trim(substr(
        full_name,
        position(' ' in full_name) + 1
      )), '');
    end if;
  else
    if given_name is null or family_name is null then
      raise exception 'Registration requires first_name and last_name metadata';
    end if;

    if requested_role not in ('student', 'instructor') then
      raise exception 'Registration role must be student or instructor';
    end if;
  end if;

  resolved_display_name := coalesce(
    full_name,
    nullif(trim(concat_ws(' ', given_name, family_name)), ''),
    split_part(normalized_email, '@', 1)
  );

  insert into public.profiles (
    id,
    email,
    display_name,
    first_name,
    last_name,
    avatar_url,
    role
  )
  values (
    new.id,
    normalized_email,
    resolved_display_name,
    given_name,
    family_name,
    profile_avatar_url,
    requested_role::public.user_role
  )
  on conflict (id) do update set
    email = excluded.email,
    display_name = excluded.display_name,
    first_name = excluded.first_name,
    last_name = excluded.last_name,
    avatar_url = coalesce(public.profiles.avatar_url, excluded.avatar_url),
    updated_at = timezone('utc', now());
  return new;
end;
$$;

revoke all on function public.handle_new_user() from public;
revoke all on function public.handle_new_user() from anon;
revoke all on function public.handle_new_user() from authenticated;

drop trigger if exists on_auth_user_created_confirmed on auth.users;
create trigger on_auth_user_created_confirmed
  after insert on auth.users
  for each row
  when (new.email_confirmed_at is not null)
  execute function public.handle_new_user();

drop trigger if exists on_auth_user_email_verified on auth.users;
create trigger on_auth_user_email_verified
  after update of email_confirmed_at on auth.users
  for each row
  when (
    old.email_confirmed_at is null
    and new.email_confirmed_at is not null
  )
  execute function public.handle_new_user();
