-- Repair one instructor account whose public profile role is still `student`.
-- Run this in the Supabase SQL Editor as a project administrator.
-- Replace the email below with the email used to sign in as the instructor.

begin;

update public.profiles
set role = 'instructor'
where email = 'REPLACE_WITH_INSTRUCTOR_EMAIL'
  and role = 'student';

-- Confirm exactly the intended account is now an instructor before committing.
select id, email, display_name, role
from public.profiles
where email = 'REPLACE_WITH_INSTRUCTOR_EMAIL';

commit;
