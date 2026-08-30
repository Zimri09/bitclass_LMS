-- Quiz deadlines are mandatory. Existing quizzes receive a one-year grace
-- deadline so they remain available until the instructor sets a specific date.
alter table public.quizzes
  add column if not exists due_date timestamptz;

update public.quizzes
set due_date = clock_timestamp() + interval '1 year'
where due_date is null;

alter table public.quizzes
  alter column due_date set not null;

comment on column public.quizzes.due_date is
  'Server-enforced deadline for starting, answering, and submitting a quiz.';

create index if not exists quizzes_course_published_due_date_idx
  on public.quizzes (course_id, is_published, due_date);

-- Return the database clock with the quiz status so the client can disable
-- its action before an RPC is attempted. The actual security enforcement is
-- also performed by the start RPC and the attempt trigger below.
create or replace function public.get_quiz_availability(p_quiz_id uuid)
returns table (
  server_now timestamptz,
  due_date timestamptz,
  is_closed boolean
)
language sql
volatile
security invoker
set search_path = pg_catalog, public
as $$
  select
    clock_timestamp() as server_now,
    quiz.due_date,
    clock_timestamp() >= quiz.due_date as is_closed
  from public.quizzes as quiz
  where quiz.id = p_quiz_id;
$$;

revoke all on function public.get_quiz_availability(uuid)
  from public, anon;
grant execute on function public.get_quiz_availability(uuid)
  to authenticated, service_role;

-- Do not return an existing in-progress attempt after the deadline. This
-- wrapper uses Postgres server time, never the device clock.
create or replace function public.start_quiz_attempt(
  p_quiz_id uuid,
  p_enrollment_id uuid default null
)
returns public.quiz_attempts
language plpgsql
volatile
security invoker
set search_path = pg_catalog, public, private
as $$
declare
  quiz_due_date timestamptz;
begin
  select due_date
  into quiz_due_date
  from public.quizzes
  where id = p_quiz_id;

  if quiz_due_date is null or clock_timestamp() >= quiz_due_date then
    raise exception 'Quiz deadline has passed';
  end if;

  return private.start_quiz_attempt(p_quiz_id, p_enrollment_id);
end;
$$;

-- Enforce the cutoff on all student attempt writes. This protects answer
-- saving and final submission even if a modified client bypasses Flutter UI.
create or replace function private.enforce_quiz_deadline()
returns trigger
language plpgsql
security definer
set search_path = pg_catalog, public
as $$
declare
  quiz_due_date timestamptz;
  should_enforce boolean := false;
begin
  if tg_op = 'INSERT' then
    if auth.uid() is distinct from new.user_id then
      return new;
    end if;
    should_enforce := new.status = 'inProgress'::public.attempt_status;
  else
    if auth.uid() is distinct from old.user_id then
      return new;
    end if;
    should_enforce := old.status = 'inProgress'::public.attempt_status
      and (
        new.status is distinct from old.status
        or new.answers is distinct from old.answers
      );
  end if;

  if not should_enforce then
    return new;
  end if;

  select due_date
  into quiz_due_date
  from public.quizzes
  where id = new.quiz_id;

  if quiz_due_date is null or clock_timestamp() >= quiz_due_date then
    raise exception 'Quiz deadline has passed';
  end if;

  return new;
end;
$$;

revoke all on function private.enforce_quiz_deadline() from public;

drop trigger if exists quiz_attempts_enforce_deadline on public.quiz_attempts;
create trigger quiz_attempts_enforce_deadline
before insert or update of status, answers on public.quiz_attempts
for each row execute function private.enforce_quiz_deadline();

-- A code Activity is submitted with non-empty editor code, not an attachment.
-- Preserve the required file/link rule for every non-code Activity.
drop policy if exists "submissions: authorized insert"
  on public.submissions;
drop policy if exists "submissions: authorized update"
  on public.submissions;

create policy "submissions: authorized insert"
  on public.submissions for insert to authenticated
  with check (
    (select private.can_manage_course(course_id))
    or (
      user_id = (select auth.uid())
      and status::text in ('draft', 'submitted', 'done')
      and score is null
      and criterion_scores = '[]'::jsonb
      and feedback is null
      and graded_by is null
      and graded_at is null
      and exists (
        select 1
        from public.assignments as assignment
        where assignment.id = submissions.assignment_id
          and assignment.course_id = submissions.course_id
          and assignment.is_published
          and (select private.is_course_member(assignment.course_id))
          and (
            (
              submissions.status::text = 'draft'
              and submissions.submitted_at is null
              and not submissions.is_late
            )
            or (
              submissions.status::text in ('submitted', 'done')
              and submissions.submitted_at is not null
              and (
                assignment.allow_late_submission
                or assignment.due_date is null
                or now() <= assignment.due_date
              )
              and submissions.is_late = (
                assignment.due_date is not null
                and now() > assignment.due_date
              )
              and (
                submissions.status::text = 'done'
                or (
                  submissions.status::text = 'submitted'
                  and (
                    (
                      (
                        assignment.language::text <> 'plaintext'
                        or coalesce(trim(assignment.starter_code), '') <> ''
                        or coalesce(trim(assignment.solution_code), '') <> ''
                      )
                      and nullif(trim(submissions.code), '') is not null
                    )
                    or (
                      assignment.language::text = 'plaintext'
                      and coalesce(trim(assignment.starter_code), '') = ''
                      and coalesce(trim(assignment.solution_code), '') = ''
                      and (
                        not assignment.requires_attachment
                        or jsonb_array_length(submissions.attachments) > 0
                      )
                    )
                  )
                )
              )
            )
          )
      )
    )
  );

create policy "submissions: authorized update"
  on public.submissions for update to authenticated
  using (
    (select private.can_manage_course(course_id))
    or (user_id = (select auth.uid()) and status::text = 'draft')
  )
  with check (
    (select private.can_manage_course(course_id))
    or (
      user_id = (select auth.uid())
      and status::text in ('draft', 'submitted', 'done')
      and score is null
      and criterion_scores = '[]'::jsonb
      and feedback is null
      and graded_by is null
      and graded_at is null
      and exists (
        select 1
        from public.assignments as assignment
        where assignment.id = submissions.assignment_id
          and assignment.course_id = submissions.course_id
          and assignment.is_published
          and (select private.is_course_member(assignment.course_id))
          and (
            (
              submissions.status::text = 'draft'
              and submissions.submitted_at is null
              and not submissions.is_late
            )
            or (
              submissions.status::text in ('submitted', 'done')
              and submissions.submitted_at is not null
              and (
                assignment.allow_late_submission
                or assignment.due_date is null
                or now() <= assignment.due_date
              )
              and submissions.is_late = (
                assignment.due_date is not null
                and now() > assignment.due_date
              )
              and (
                submissions.status::text = 'done'
                or (
                  submissions.status::text = 'submitted'
                  and (
                    (
                      (
                        assignment.language::text <> 'plaintext'
                        or coalesce(trim(assignment.starter_code), '') <> ''
                        or coalesce(trim(assignment.solution_code), '') <> ''
                      )
                      and nullif(trim(submissions.code), '') is not null
                    )
                    or (
                      assignment.language::text = 'plaintext'
                      and coalesce(trim(assignment.starter_code), '') = ''
                      and coalesce(trim(assignment.solution_code), '') = ''
                      and (
                        not assignment.requires_attachment
                        or jsonb_array_length(submissions.attachments) > 0
                      )
                    )
                  )
                )
              )
            )
          )
      )
    )
  );

comment on policy "submissions: authorized insert" on public.submissions is
  'Students may submit code Activities with code only, or attach work for non-code Activities.';
comment on policy "submissions: authorized update" on public.submissions is
  'Students may submit code Activities with code only, or attach work for non-code Activities.';
