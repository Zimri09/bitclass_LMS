create or replace function private.is_valid_activity_criterion_scores(
  criterion_scores jsonb,
  final_score numeric
)
returns boolean
language plpgsql
immutable
strict
set search_path = ''
as $function$
declare
  item jsonb;
  criterion_ids text[] := '{}';
  item_max numeric;
  item_score numeric;
  calculated_score numeric := 0;
begin
  if pg_catalog.jsonb_typeof(criterion_scores) <> 'array'
    or pg_catalog.jsonb_array_length(criterion_scores) = 0
    or pg_catalog.jsonb_array_length(criterion_scores) > 50
  then
    return false;
  end if;

  for item in
    select value from pg_catalog.jsonb_array_elements(criterion_scores)
  loop
    if pg_catalog.jsonb_typeof(item) <> 'object'
      or pg_catalog.jsonb_typeof(item -> 'criterionId') <> 'string'
      or pg_catalog.length(pg_catalog.btrim(item ->> 'criterionId')) = 0
      or pg_catalog.length(item ->> 'criterionId') > 64
      or pg_catalog.jsonb_typeof(item -> 'criterionName') <> 'string'
      or pg_catalog.length(pg_catalog.btrim(item ->> 'criterionName')) = 0
      or pg_catalog.length(item ->> 'criterionName') > 120
      or pg_catalog.jsonb_typeof(item -> 'maxPoints') <> 'number'
      or pg_catalog.jsonb_typeof(item -> 'score') <> 'number'
    then
      return false;
    end if;

    if (item ->> 'criterionId') = any(criterion_ids) then
      return false;
    end if;
    criterion_ids := pg_catalog.array_append(
      criterion_ids,
      item ->> 'criterionId'
    );

    item_max := (item ->> 'maxPoints')::numeric;
    item_score := (item ->> 'score')::numeric;
    if item_max <= 0
      or item_score < 0
      or item_score > item_max
      or pg_catalog.scale(item_max) > 4
      or pg_catalog.scale(item_score) > 2
    then
      return false;
    end if;
    calculated_score := calculated_score + item_score;
  end loop;

  return calculated_score = final_score;
exception
  when others then
    return false;
end;
$function$;

revoke all on function private.is_valid_activity_criterion_scores(jsonb, numeric)
from public;
grant execute on function private.is_valid_activity_criterion_scores(jsonb, numeric)
to authenticated, service_role;

drop policy if exists "submissions: authorized insert" on public.submissions;
drop policy if exists "submissions: authorized update" on public.submissions;
drop trigger if exists notify_assignment_graded on public.submissions;

alter table public.submissions
alter column score type numeric(10, 2) using score::numeric;

alter table public.submissions
add column if not exists criterion_scores jsonb not null default '[]'::jsonb;

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
        select 1 from public.assignments as assignment
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
                submissions.status::text <> 'done'
                or (
                  not assignment.requires_attachment
                  and assignment.language::text = 'plaintext'
                  and coalesce(trim(assignment.starter_code), '') = ''
                  and coalesce(trim(assignment.solution_code), '') = ''
                )
              )
              and (
                not assignment.requires_attachment
                or jsonb_array_length(submissions.attachments) > 0
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
        select 1 from public.assignments as assignment
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
                submissions.status::text <> 'done'
                or (
                  not assignment.requires_attachment
                  and assignment.language::text = 'plaintext'
                  and coalesce(trim(assignment.starter_code), '') = ''
                  and coalesce(trim(assignment.solution_code), '') = ''
                )
              )
              and (
                not assignment.requires_attachment
                or jsonb_array_length(submissions.attachments) > 0
              )
            )
          )
      )
    )
  );

do $migration$
begin
  if not exists (
    select 1
    from pg_catalog.pg_constraint
    where conrelid = 'public.submissions'::regclass
      and conname = 'submissions_criterion_scores_valid'
  ) then
    alter table public.submissions
    add constraint submissions_criterion_scores_valid
    check (
      criterion_scores = '[]'::jsonb
      or (
        score is not null
        and private.is_valid_activity_criterion_scores(criterion_scores, score)
      )
    );
  end if;
end;
$migration$;

comment on column public.submissions.criterion_scores is
  'Snapshot of per-criterion Activity scores. The final score equals their sum.';

create or replace function private.notify_assignment_graded()
returns trigger
language plpgsql
security definer
set search_path = pg_catalog, public
as $function$
declare
  assignment_title text;
begin
  if new.graded_at is not null
     and (
       tg_op = 'INSERT'
       or old.graded_at is null
       or old.score is distinct from new.score
       or old.criterion_scores is distinct from new.criterion_scores
     ) then
    select title into assignment_title
    from public.assignments
    where id = new.assignment_id;

    insert into public.notifications (
      user_id, type, title, body, data, course_id, action_url
    )
    values (
      new.user_id,
      'assignmentGraded',
      'Activity graded',
      coalesce(assignment_title, 'Your activity') || ' has been graded.',
      jsonb_build_object(
        'course_id', new.course_id,
        'assignment_id', new.assignment_id,
        'submission_id', new.id
      ),
      new.course_id,
      '/courses/' || new.course_id || '/assignments/' || new.assignment_id
    );
  end if;
  return new;
end;
$function$;

create trigger notify_assignment_graded
after insert or update of graded_at, score, criterion_scores on public.submissions
for each row execute function private.notify_assignment_graded();

create or replace function private.notify_assignment_submitted()
returns trigger
language plpgsql
security definer
set search_path = pg_catalog, public
as $function$
declare
  assignment_title text;
  course_instructor_id uuid;
begin
  if new.submitted_at is null
     or new.status::text not in ('submitted', 'done') then
    return new;
  end if;

  if tg_op = 'UPDATE'
     and old.status::text in ('submitted', 'done') then
    return new;
  end if;

  select assignments.title, courses.instructor_id
  into assignment_title, course_instructor_id
  from public.assignments
  join public.courses on courses.id = assignments.course_id
  where assignments.id = new.assignment_id;

  if course_instructor_id is null or course_instructor_id = new.user_id then
    return new;
  end if;

  insert into public.notifications (
    user_id, type, title, body, data, course_id, action_url
  )
  values (
    course_instructor_id,
    'assignmentSubmitted',
    'Activity submitted',
    coalesce(nullif(trim(new.user_display_name), ''), 'A student') ||
      ' submitted "' || coalesce(assignment_title, 'an activity') || '".',
    jsonb_build_object(
      'course_id', new.course_id,
      'assignment_id', new.assignment_id,
      'submission_id', new.id,
      'student_id', new.user_id
    ),
    new.course_id,
    '/courses/' || new.course_id || '/assignments/' ||
      new.assignment_id || '/grade'
  );

  return new;
end;
$function$;
