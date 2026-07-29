-- Repair one instructor account whose public profile role is still `student`.
-- Run this in the Supabase SQL Editor as a project administrator, after
-- harden_rls.sql. Replace the email below with the instructor's login email.

do $$
declare
  target_email text := 'logronio.zimri16@gmail.com';
updated_profile public.profiles;
begin
  if target_email = 'REPLACE_WITH_INSTRUCTOR_EMAIL' then
    raise exception 'Replace REPLACE_WITH_INSTRUCTOR_EMAIL before running this script.';
  end if;

  update public.profiles
  set role = 'instructor', updated_at = timezone('utc', now())
  where email = lower(trim(target_email))
  returning * into updated_profile;

  if not found then
    raise exception 'No profile exists for %.', target_email;
  end if;

  if updated_profile.role <> 'instructor'::public.user_role then
    raise exception 'Unable to set % as an instructor.', target_email;
  end if;

  raise notice 'Instructor profile repaired for % (user id: %).',
    updated_profile.email,
    updated_profile.id;
end;
$$;
