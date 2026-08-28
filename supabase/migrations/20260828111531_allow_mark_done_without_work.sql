-- Let a student mark any published Activity as Done without turning in work.
-- A real submission remains a separate path and still enforces attachments.

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
                    not assignment.requires_attachment
                    or jsonb_array_length(submissions.attachments) > 0
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
                    not assignment.requires_attachment
                    or jsonb_array_length(submissions.attachments) > 0
                  )
                )
              )
            )
          )
      )
    )
  );

comment on policy "submissions: authorized insert" on public.submissions is
  'Students may save drafts, submit required work, or mark any Activity Done.';
comment on policy "submissions: authorized update" on public.submissions is
  'Students may complete drafts as Submitted or Done; instructors retain grading access.';
