-- Students receive grading status only. Course managers retain the complete
-- question key through the same role-aware RPC.

alter table public.quizzes
  alter column show_correct_answers set default false;

update public.quizzes
set show_correct_answers = false
where show_correct_answers;

create or replace function private.get_quiz_questions(p_quiz_id uuid)
returns table (
  id uuid,
  quiz_id uuid,
  question_type text,
  prompt text,
  points integer,
  options jsonb,
  correct_answer jsonb,
  explanation text,
  question_code text,
  code_language text,
  hint text,
  test_cases jsonb,
  sort_order integer
)
language plpgsql
stable
security definer
set search_path = pg_catalog, public, private
as $$
declare
  current_user_id uuid := auth.uid();
  target_course_id uuid;
  target_is_published boolean;
  can_manage boolean;
begin
  if current_user_id is null then
    raise exception 'Authentication required';
  end if;

  select quiz.course_id, quiz.is_published
  into target_course_id, target_is_published
  from public.quizzes as quiz
  where quiz.id = p_quiz_id;

  if not found then
    raise exception 'Quiz not found';
  end if;

  can_manage := private.can_manage_course(target_course_id);
  if not can_manage and (
    not target_is_published
    or not private.is_course_member(target_course_id)
  ) then
    raise exception 'Quiz access denied';
  end if;

  return query
  select
    question.id,
    question.quiz_id,
    question.question_type,
    question.prompt,
    question.points,
    case
      when can_manage then question.options
      else coalesce(
        (
          select jsonb_agg(option_value - 'isCorrect')
          from jsonb_array_elements(question.options) as option_row(option_value)
        ),
        '[]'::jsonb
      )
    end as options,
    case when can_manage then question.correct_answer end,
    case when can_manage then question.explanation end,
    question.question_code,
    question.code_language,
    question.hint,
    case
      when can_manage then question.test_cases
      else coalesce(
        (
          select jsonb_agg(test_case_value)
          from jsonb_array_elements(
            coalesce(question.test_cases, '[]'::jsonb)
          ) as test_case_row(test_case_value)
          where not coalesce(
            (test_case_value ->> 'isHidden')::boolean,
            false
          )
        ),
        '[]'::jsonb
      )
    end as test_cases,
    question.sort_order
  from public.questions as question
  where question.quiz_id = p_quiz_id
  order by question.sort_order;
end;
$$;

-- Keep student-authored responses for instructor grading, but never persist
-- explanations or expected answers in the feedback visible on owned attempts.
create or replace function private.protect_quiz_attempt_feedback()
returns trigger
language plpgsql
security invoker
set search_path = pg_catalog, public, private
as $$
begin
  if new.status = 'graded'::public.attempt_status
    and jsonb_typeof(new.answers) = 'object'
  then
    select coalesce(
      jsonb_object_agg(
        answer_entry.key,
        jsonb_set(
          answer_entry.value,
          '{feedback}',
          to_jsonb(
            case
              when coalesce(
                (answer_entry.value ->> 'isCorrect')::boolean,
                false
              ) then 'Correct!'
              else 'Incorrect.'
            end
          ),
          true
        )
      ),
      '{}'::jsonb
    )
    into new.answers
    from jsonb_each(new.answers) as answer_entry(key, value);
  end if;

  return new;
end;
$$;

revoke all on function private.protect_quiz_attempt_feedback()
  from public, anon, authenticated;

drop trigger if exists protect_quiz_attempt_feedback
  on public.quiz_attempts;
create trigger protect_quiz_attempt_feedback
before insert or update of status, answers
on public.quiz_attempts
for each row
execute function private.protect_quiz_attempt_feedback();

-- Scrub answer-bearing feedback from attempts graded before this migration.
update public.quiz_attempts
set answers = answers
where status = 'graded'::public.attempt_status
  and jsonb_typeof(answers) = 'object';
