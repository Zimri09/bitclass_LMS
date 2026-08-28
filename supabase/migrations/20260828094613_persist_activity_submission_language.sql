alter type public.assignment_language add value if not exists 'c';

alter table public.submissions
add column if not exists language public.assignment_language
not null default 'plaintext';

update public.submissions as submission
set language = assignment.language
from public.assignments as assignment
where assignment.id = submission.assignment_id
  and assignment.course_id = submission.course_id
  and submission.language is distinct from assignment.language;

create or replace function private.set_submission_language()
returns trigger
language plpgsql
set search_path = pg_catalog
as $$
begin
  if tg_op = 'INSERT' then
    select assignment.language
    into new.language
    from public.assignments as assignment
    where assignment.id = new.assignment_id
      and assignment.course_id = new.course_id;
  elsif old.status = 'draft'::public.submission_status then
    select assignment.language
    into new.language
    from public.assignments as assignment
    where assignment.id = new.assignment_id
      and assignment.course_id = new.course_id;
  else
    new.language = old.language;
  end if;

  return new;
end;
$$;

revoke all on function private.set_submission_language()
from public, anon, authenticated;

drop trigger if exists submissions_set_language on public.submissions;
create trigger submissions_set_language
before insert or update of assignment_id, course_id, language, status
on public.submissions
for each row execute function private.set_submission_language();

comment on column public.submissions.language is
  'Programming language captured when the student submits the activity.';
