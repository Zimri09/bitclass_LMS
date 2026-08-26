-- Keep answer keys and grading decisions on the server. Public wrappers are
-- SECURITY INVOKER functions; their privileged implementations live outside
-- the exposed API schema.

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
  target_show_correct_answers boolean;
  can_manage boolean;
  can_reveal_answers boolean;
begin
  if current_user_id is null then
    raise exception 'Authentication required';
  end if;

  select quiz.course_id, quiz.is_published, quiz.show_correct_answers
  into target_course_id, target_is_published, target_show_correct_answers
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

  can_reveal_answers := can_manage or (
    target_show_correct_answers
    and exists (
      select 1
      from public.quiz_attempts as attempt
      where attempt.quiz_id = p_quiz_id
        and attempt.user_id = current_user_id
        and attempt.status = 'graded'::public.attempt_status
    )
  );

  return query
  select
    question.id,
    question.quiz_id,
    question.question_type,
    question.prompt,
    question.points,
    case
      when can_reveal_answers then question.options
      else coalesce(
        (
          select jsonb_agg(option_value - 'isCorrect')
          from jsonb_array_elements(question.options) as option_row(option_value)
        ),
        '[]'::jsonb
      )
    end as options,
    case when can_reveal_answers then question.correct_answer end,
    case when can_reveal_answers then question.explanation end,
    question.question_code,
    question.code_language,
    question.hint,
    case
      when can_reveal_answers then question.test_cases
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

create or replace function public.get_quiz_questions(p_quiz_id uuid)
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
language sql
stable
security invoker
set search_path = pg_catalog, public, private
as $$
  select * from private.get_quiz_questions(p_quiz_id);
$$;

create or replace function private.start_quiz_attempt(
  p_quiz_id uuid,
  p_enrollment_id uuid default null
)
returns public.quiz_attempts
language plpgsql
security definer
set search_path = pg_catalog, public, private
as $$
declare
  current_user_id uuid := auth.uid();
  target_course_id uuid;
  target_enrollment_id uuid;
  target_max_attempts integer;
  target_is_published boolean;
  next_attempt_number integer;
  attempt_total_points integer;
  result public.quiz_attempts%rowtype;
begin
  if current_user_id is null then
    raise exception 'Authentication required';
  end if;

  select quiz.course_id, quiz.max_attempts, quiz.is_published
  into target_course_id, target_max_attempts, target_is_published
  from public.quizzes as quiz
  where quiz.id = p_quiz_id;

  if not found or not target_is_published then
    raise exception 'Quiz is not available';
  end if;

  if p_enrollment_id is null then
    select enrollment.id
    into target_enrollment_id
    from public.enrollments as enrollment
    where enrollment.course_id = target_course_id
      and enrollment.user_id = current_user_id
    order by enrollment.enrolled_at desc
    limit 1;
  else
    select enrollment.id
    into target_enrollment_id
    from public.enrollments as enrollment
    where enrollment.id = p_enrollment_id
      and enrollment.course_id = target_course_id
      and enrollment.user_id = current_user_id;
  end if;

  if target_enrollment_id is null then
    raise exception 'Course enrollment required';
  end if;

  perform pg_advisory_xact_lock(
    hashtextextended(current_user_id::text || ':' || p_quiz_id::text, 0)
  );

  select attempt.*
  into result
  from public.quiz_attempts as attempt
  where attempt.quiz_id = p_quiz_id
    and attempt.user_id = current_user_id
    and attempt.status = 'inProgress'::public.attempt_status
  order by attempt.started_at desc
  limit 1;

  if found then
    return result;
  end if;

  select coalesce(max(attempt.attempt_number), 0) + 1
  into next_attempt_number
  from public.quiz_attempts as attempt
  where attempt.quiz_id = p_quiz_id
    and attempt.user_id = current_user_id;

  if target_max_attempts > 0 and next_attempt_number > target_max_attempts then
    raise exception 'Maximum attempts reached';
  end if;

  select coalesce(sum(question.points), 0)::integer
  into attempt_total_points
  from public.questions as question
  where question.quiz_id = p_quiz_id;

  if attempt_total_points <= 0 then
    raise exception 'Quiz has no scorable questions';
  end if;

  insert into public.quiz_attempts (
    quiz_id,
    user_id,
    enrollment_id,
    status,
    attempt_number,
    total_points
  )
  values (
    p_quiz_id,
    current_user_id,
    target_enrollment_id,
    'inProgress'::public.attempt_status,
    next_attempt_number,
    attempt_total_points
  )
  returning * into result;

  return result;
end;
$$;

create or replace function public.start_quiz_attempt(
  p_quiz_id uuid,
  p_enrollment_id uuid default null
)
returns public.quiz_attempts
language sql
volatile
security invoker
set search_path = pg_catalog, public, private
as $$
  select private.start_quiz_attempt(p_quiz_id, p_enrollment_id);
$$;

create or replace function private.save_quiz_answer(
  p_attempt_id uuid,
  p_question_id uuid,
  p_selected_answers jsonb default '[]'::jsonb,
  p_text_answer text default null,
  p_code_answer text default null
)
returns public.quiz_attempts
language plpgsql
security definer
set search_path = pg_catalog, public, private
as $$
declare
  current_user_id uuid := auth.uid();
  current_attempt public.quiz_attempts%rowtype;
  question_points integer;
  answer_payload jsonb;
begin
  if current_user_id is null then
    raise exception 'Authentication required';
  end if;

  if jsonb_typeof(coalesce(p_selected_answers, '[]'::jsonb)) <> 'array'
    or jsonb_array_length(coalesce(p_selected_answers, '[]'::jsonb)) > 100 then
    raise exception 'Invalid selected answers';
  end if;

  if length(coalesce(p_text_answer, '')) > 10000
    or length(coalesce(p_code_answer, '')) > 100000 then
    raise exception 'Answer is too large';
  end if;

  select attempt.*
  into current_attempt
  from public.quiz_attempts as attempt
  where attempt.id = p_attempt_id
  for update;

  if not found
    or current_attempt.user_id <> current_user_id
    or current_attempt.status <> 'inProgress'::public.attempt_status then
    raise exception 'Active quiz attempt not found';
  end if;

  select question.points
  into question_points
  from public.questions as question
  where question.id = p_question_id
    and question.quiz_id = current_attempt.quiz_id;

  if not found then
    raise exception 'Question does not belong to this quiz';
  end if;

  answer_payload := jsonb_build_object(
    'questionId', p_question_id::text,
    'selectedAnswers', coalesce(p_selected_answers, '[]'::jsonb),
    'textAnswer', p_text_answer,
    'codeAnswer', p_code_answer,
    'isCorrect', false,
    'pointsEarned', 0,
    'maxPoints', question_points,
    'feedback', null,
    'answeredAt', clock_timestamp()
  );

  update public.quiz_attempts as attempt
  set answers = jsonb_set(
    coalesce(attempt.answers, '{}'::jsonb),
    array[p_question_id::text],
    answer_payload,
    true
  )
  where attempt.id = p_attempt_id
  returning attempt.* into current_attempt;

  return current_attempt;
end;
$$;

create or replace function public.save_quiz_answer(
  p_attempt_id uuid,
  p_question_id uuid,
  p_selected_answers jsonb default '[]'::jsonb,
  p_text_answer text default null,
  p_code_answer text default null
)
returns public.quiz_attempts
language sql
volatile
security invoker
set search_path = pg_catalog, public, private
as $$
  select private.save_quiz_answer(
    p_attempt_id,
    p_question_id,
    p_selected_answers,
    p_text_answer,
    p_code_answer
  );
$$;

create or replace function private.submit_quiz_attempt(p_attempt_id uuid)
returns public.quiz_attempts
language plpgsql
security definer
set search_path = pg_catalog, public, private
as $$
declare
  current_user_id uuid := auth.uid();
  current_attempt public.quiz_attempts%rowtype;
  target_quiz public.quizzes%rowtype;
  question record;
  raw_answer jsonb;
  graded_answer jsonb;
  graded_answers jsonb := '{}'::jsonb;
  selected_values text[];
  correct_values text[];
  answer_is_correct boolean;
  answer_feedback text;
  total_score integer := 0;
  calculated_total_points integer := 0;
  final_percentage numeric(6,2) := 0;
begin
  if current_user_id is null then
    raise exception 'Authentication required';
  end if;

  select attempt.*
  into current_attempt
  from public.quiz_attempts as attempt
  where attempt.id = p_attempt_id
  for update;

  if not found
    or current_attempt.user_id <> current_user_id
    or current_attempt.status <> 'inProgress'::public.attempt_status then
    raise exception 'Active quiz attempt not found';
  end if;

  select quiz.*
  into target_quiz
  from public.quizzes as quiz
  where quiz.id = current_attempt.quiz_id;

  if not found then
    raise exception 'Quiz not found';
  end if;

  for question in
    select item.*
    from public.questions as item
    where item.quiz_id = current_attempt.quiz_id
    order by item.sort_order
  loop
    calculated_total_points := calculated_total_points + question.points;
    raw_answer := coalesce(
      current_attempt.answers -> question.id::text,
      '{}'::jsonb
    );

    select coalesce(array_agg(value order by value), array[]::text[])
    into selected_values
    from jsonb_array_elements_text(
      case
        when jsonb_typeof(raw_answer -> 'selectedAnswers') = 'array'
          then raw_answer -> 'selectedAnswers'
        else '[]'::jsonb
      end
    ) as selected(value);

    select coalesce(array_agg(value order by value), array[]::text[])
    into correct_values
    from jsonb_array_elements_text(
      case
        when jsonb_typeof(question.correct_answer) = 'array'
          then question.correct_answer
        else '[]'::jsonb
      end
    ) as correct(value);

    answer_is_correct := case question.question_type
      when 'multipleChoice' then
        cardinality(selected_values) = 1
        and cardinality(correct_values) = 1
        and selected_values = correct_values
      when 'multiple_choice' then
        cardinality(selected_values) = 1
        and cardinality(correct_values) = 1
        and selected_values = correct_values
      when 'trueFalse' then
        cardinality(selected_values) = 1
        and cardinality(correct_values) = 1
        and selected_values = correct_values
      when 'true_false' then
        cardinality(selected_values) = 1
        and cardinality(correct_values) = 1
        and selected_values = correct_values
      when 'multipleSelect' then selected_values = correct_values
      when 'multiple_select' then selected_values = correct_values
      when 'shortAnswer' then exists (
        select 1
        from unnest(correct_values) as expected(value)
        where lower(trim(expected.value)) = lower(trim(coalesce(raw_answer ->> 'textAnswer', '')))
      )
      when 'short_answer' then exists (
        select 1
        from unnest(correct_values) as expected(value)
        where lower(trim(expected.value)) = lower(trim(coalesce(raw_answer ->> 'textAnswer', '')))
      )
      when 'coding' then exists (
        select 1
        from unnest(correct_values) as expected(value)
        where trim(expected.value) <> ''
          and position(
            trim(expected.value)
            in coalesce(raw_answer ->> 'codeAnswer', '')
          ) > 0
      )
      else false
    end;

    if answer_is_correct then
      answer_feedback := 'Correct!';
      total_score := total_score + question.points;
    elsif not target_quiz.show_correct_answers then
      answer_feedback := 'Incorrect.';
    elsif question.question_type in ('shortAnswer', 'short_answer') then
      answer_feedback := 'Incorrect. Expected: ' || coalesce(
        array_to_string(correct_values, ' or '),
        'an instructor-reviewed response'
      );
    elsif question.question_type in ('multipleSelect', 'multiple_select') then
      answer_feedback := 'Incorrect. You needed to select '
        || cardinality(correct_values)::text
        || ' option(s).'
        || case
          when nullif(trim(coalesce(question.explanation, '')), '') is null
            then ''
          else ' ' || question.explanation
        end;
    else
      answer_feedback := 'Incorrect.' || case
        when nullif(trim(coalesce(question.explanation, '')), '') is null
          then ''
        else ' ' || question.explanation
      end;
    end if;

    graded_answer := jsonb_build_object(
      'questionId', question.id::text,
      'selectedAnswers', coalesce(raw_answer -> 'selectedAnswers', '[]'::jsonb),
      'textAnswer', raw_answer ->> 'textAnswer',
      'codeAnswer', raw_answer ->> 'codeAnswer',
      'isCorrect', answer_is_correct,
      'pointsEarned', case when answer_is_correct then question.points else 0 end,
      'maxPoints', question.points,
      'feedback', answer_feedback,
      'answeredAt', coalesce(raw_answer -> 'answeredAt', to_jsonb(clock_timestamp()))
    );

    graded_answers := graded_answers || jsonb_build_object(
      question.id::text,
      graded_answer
    );
  end loop;

  if calculated_total_points <= 0 then
    raise exception 'Quiz has no scorable questions';
  end if;

  final_percentage := round(
    total_score::numeric * 100 / calculated_total_points,
    2
  );

  update public.quiz_attempts as attempt
  set
    status = 'graded'::public.attempt_status,
    submitted_at = clock_timestamp(),
    graded_at = clock_timestamp(),
    score = total_score,
    total_points = calculated_total_points,
    percentage = final_percentage,
    passed = final_percentage >= target_quiz.passing_score,
    time_spent_seconds = greatest(
      extract(epoch from (clock_timestamp() - attempt.started_at))::integer,
      0
    ),
    answers = graded_answers
  where attempt.id = p_attempt_id
  returning attempt.* into current_attempt;

  return current_attempt;
end;
$$;

create or replace function public.submit_quiz_attempt(p_attempt_id uuid)
returns public.quiz_attempts
language sql
volatile
security invoker
set search_path = pg_catalog, public, private
as $$
  select private.submit_quiz_attempt(p_attempt_id);
$$;

grant usage on schema private to authenticated, service_role;

revoke all on function private.get_quiz_questions(uuid)
  from public, anon, authenticated;
revoke all on function private.start_quiz_attempt(uuid, uuid)
  from public, anon, authenticated;
revoke all on function private.save_quiz_answer(uuid, uuid, jsonb, text, text)
  from public, anon, authenticated;
revoke all on function private.submit_quiz_attempt(uuid)
  from public, anon, authenticated;

grant execute on function private.get_quiz_questions(uuid)
  to authenticated, service_role;
grant execute on function private.start_quiz_attempt(uuid, uuid)
  to authenticated, service_role;
grant execute on function private.save_quiz_answer(uuid, uuid, jsonb, text, text)
  to authenticated, service_role;
grant execute on function private.submit_quiz_attempt(uuid)
  to authenticated, service_role;

revoke all on function public.get_quiz_questions(uuid)
  from public, anon;
revoke all on function public.start_quiz_attempt(uuid, uuid)
  from public, anon;
revoke all on function public.save_quiz_answer(uuid, uuid, jsonb, text, text)
  from public, anon;
revoke all on function public.submit_quiz_attempt(uuid)
  from public, anon;

grant execute on function public.get_quiz_questions(uuid)
  to authenticated, service_role;
grant execute on function public.start_quiz_attempt(uuid, uuid)
  to authenticated, service_role;
grant execute on function public.save_quiz_answer(uuid, uuid, jsonb, text, text)
  to authenticated, service_role;
grant execute on function public.submit_quiz_attempt(uuid)
  to authenticated, service_role;

-- Published quizzes are visible only to their course members. Answer-bearing
-- question rows remain directly readable only by course managers.
drop policy if exists "quizzes read course members" on public.quizzes;
create policy "quizzes read course members"
  on public.quizzes
  for select
  to authenticated
  using (
    (select private.can_manage_course(course_id))
    or (
      is_published
      and (select private.is_course_member(course_id))
    )
  );

drop policy if exists "quizzes manage instructors" on public.quizzes;
create policy "quizzes manage instructors"
  on public.quizzes
  for all
  to authenticated
  using ((select private.can_manage_course(course_id)))
  with check ((select private.can_manage_course(course_id)));

drop policy if exists "questions read quiz members" on public.questions;
drop policy if exists "questions manage instructors" on public.questions;
create policy "questions manage instructors"
  on public.questions
  for all
  to authenticated
  using (
    exists (
      select 1
      from public.quizzes as quiz
      where quiz.id = questions.quiz_id
        and (select private.can_manage_course(quiz.course_id))
    )
  )
  with check (
    exists (
      select 1
      from public.quizzes as quiz
      where quiz.id = questions.quiz_id
        and (select private.can_manage_course(quiz.course_id))
    )
  );

-- Attempts may be read by their owner or course manager. All student writes
-- now pass through the RPCs above, which ignore client-supplied grades.
drop policy if exists "quiz attempts read own" on public.quiz_attempts;
drop policy if exists "quiz attempts manage own" on public.quiz_attempts;
create policy "quiz attempts read own"
  on public.quiz_attempts
  for select
  to authenticated
  using (
    user_id = (select auth.uid())
    or exists (
      select 1
      from public.quizzes as quiz
      where quiz.id = quiz_attempts.quiz_id
        and (select private.can_manage_course(quiz.course_id))
    )
  );

drop policy if exists "quiz answers read own" on public.quiz_answers;
drop policy if exists "quiz answers manage own" on public.quiz_answers;
create policy "quiz answers read own"
  on public.quiz_answers
  for select
  to authenticated
  using (
    exists (
      select 1
      from public.quiz_attempts as attempt
      join public.quizzes as quiz on quiz.id = attempt.quiz_id
      where attempt.id = quiz_answers.attempt_id
        and (
          attempt.user_id = (select auth.uid())
          or (select private.can_manage_course(quiz.course_id))
        )
    )
  );
