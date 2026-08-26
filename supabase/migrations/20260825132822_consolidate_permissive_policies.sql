-- Keep one permissive policy per role/action. This preserves the existing
-- access predicates while avoiding duplicate policy evaluation on every row.

drop policy if exists "assignments: course managers write"
  on public.assignments;
create policy "assignments: course managers insert"
  on public.assignments for insert to authenticated
  with check ((select private.can_manage_course(course_id)));
create policy "assignments: course managers update"
  on public.assignments for update to authenticated
  using ((select private.can_manage_course(course_id)))
  with check ((select private.can_manage_course(course_id)));
create policy "assignments: course managers delete"
  on public.assignments for delete to authenticated
  using ((select private.can_manage_course(course_id)));

drop policy if exists "courses: owner or admin manage" on public.courses;
create policy "courses: owner or admin update"
  on public.courses for update to authenticated
  using ((select private.can_manage_course(id)))
  with check (
    (instructor_id = (select auth.uid()) and (select private.is_staff()))
    or (select private.is_admin())
  );
create policy "courses: owner or admin delete"
  on public.courses for delete to authenticated
  using ((select private.can_manage_course(id)));

drop policy if exists "channels: course managers write"
  on public.discussion_channels;
create policy "channels: course managers insert"
  on public.discussion_channels for insert to authenticated
  with check ((select private.can_manage_course(course_id)));
create policy "channels: course managers update"
  on public.discussion_channels for update to authenticated
  using ((select private.can_manage_course(course_id)))
  with check ((select private.can_manage_course(course_id)));
create policy "channels: course managers delete"
  on public.discussion_channels for delete to authenticated
  using ((select private.can_manage_course(course_id)));

drop policy if exists "files: course managers write metadata" on public.files;
create policy "files: course managers insert metadata"
  on public.files for insert to authenticated
  with check ((select private.can_manage_course(course_id)));
create policy "files: course managers update metadata"
  on public.files for update to authenticated
  using ((select private.can_manage_course(course_id)))
  with check ((select private.can_manage_course(course_id)));
create policy "files: course managers delete metadata"
  on public.files for delete to authenticated
  using ((select private.can_manage_course(course_id)));

drop policy if exists "lesson progress: valid enrollment write"
  on public.lesson_progress;
create policy "lesson progress: valid enrollment insert"
  on public.lesson_progress for insert to authenticated
  with check (
    user_id = (select auth.uid())
    and exists (
      select 1
      from public.enrollments
      join public.lessons
        on lessons.course_id = enrollments.course_id
      where enrollments.id = lesson_progress.enrollment_id
        and enrollments.user_id = (select auth.uid())
        and lessons.id = lesson_progress.lesson_id
    )
  );
create policy "lesson progress: valid enrollment update"
  on public.lesson_progress for update to authenticated
  using (
    user_id = (select auth.uid())
    and exists (
      select 1
      from public.enrollments
      join public.lessons
        on lessons.course_id = enrollments.course_id
      where enrollments.id = lesson_progress.enrollment_id
        and enrollments.user_id = (select auth.uid())
        and lessons.id = lesson_progress.lesson_id
    )
  )
  with check (
    user_id = (select auth.uid())
    and exists (
      select 1
      from public.enrollments
      join public.lessons
        on lessons.course_id = enrollments.course_id
      where enrollments.id = lesson_progress.enrollment_id
        and enrollments.user_id = (select auth.uid())
        and lessons.id = lesson_progress.lesson_id
    )
  );
create policy "lesson progress: valid enrollment delete"
  on public.lesson_progress for delete to authenticated
  using (
    user_id = (select auth.uid())
    and exists (
      select 1
      from public.enrollments
      join public.lessons
        on lessons.course_id = enrollments.course_id
      where enrollments.id = lesson_progress.enrollment_id
        and enrollments.user_id = (select auth.uid())
        and lessons.id = lesson_progress.lesson_id
    )
  );

drop policy if exists "lessons: course managers write" on public.lessons;
create policy "lessons: course managers insert"
  on public.lessons for insert to authenticated
  with check ((select private.can_manage_course(course_id)));
create policy "lessons: course managers update"
  on public.lessons for update to authenticated
  using ((select private.can_manage_course(course_id)))
  with check ((select private.can_manage_course(course_id)));
create policy "lessons: course managers delete"
  on public.lessons for delete to authenticated
  using ((select private.can_manage_course(course_id)));

drop policy if exists "modules: course managers write" on public.modules;
create policy "modules: course managers insert"
  on public.modules for insert to authenticated
  with check ((select private.can_manage_course(course_id)));
create policy "modules: course managers update"
  on public.modules for update to authenticated
  using ((select private.can_manage_course(course_id)))
  with check ((select private.can_manage_course(course_id)));
create policy "modules: course managers delete"
  on public.modules for delete to authenticated
  using ((select private.can_manage_course(course_id)));

drop policy if exists "notification settings write own"
  on public.notification_settings;
create policy "notification settings insert own"
  on public.notification_settings for insert to authenticated
  with check (user_id = (select auth.uid()));
create policy "notification settings update own"
  on public.notification_settings for update to authenticated
  using (user_id = (select auth.uid()))
  with check (user_id = (select auth.uid()));
create policy "notification settings delete own"
  on public.notification_settings for delete to authenticated
  using (user_id = (select auth.uid()));

drop policy if exists "notifications write own" on public.notifications;
create policy "notifications insert own"
  on public.notifications for insert to authenticated
  with check (user_id = (select auth.uid()));
create policy "notifications update own"
  on public.notifications for update to authenticated
  using (user_id = (select auth.uid()))
  with check (user_id = (select auth.uid()));
create policy "notifications delete own"
  on public.notifications for delete to authenticated
  using (user_id = (select auth.uid()));

drop policy if exists "quizzes manage instructors" on public.quizzes;
create policy "quizzes: course managers insert"
  on public.quizzes for insert to authenticated
  with check ((select private.can_manage_course(course_id)));
create policy "quizzes: course managers update"
  on public.quizzes for update to authenticated
  using ((select private.can_manage_course(course_id)))
  with check ((select private.can_manage_course(course_id)));
create policy "quizzes: course managers delete"
  on public.quizzes for delete to authenticated
  using ((select private.can_manage_course(course_id)));

drop policy if exists "submissions: course managers manage"
  on public.submissions;
drop policy if exists "submissions: students create valid work"
  on public.submissions;
drop policy if exists "submissions: students read own, managers read course"
  on public.submissions;
drop policy if exists "submissions: students update valid work"
  on public.submissions;

create policy "submissions: authorized read"
  on public.submissions for select to authenticated
  using (
    user_id = (select auth.uid())
    or (select private.can_manage_course(course_id))
  );

create policy "submissions: authorized insert"
  on public.submissions for insert to authenticated
  with check (
    (select private.can_manage_course(course_id))
    or (
      user_id = (select auth.uid())
      and status::text in ('draft', 'submitted', 'done')
      and score is null
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

create policy "submissions: course managers delete"
  on public.submissions for delete to authenticated
  using ((select private.can_manage_course(course_id)));

drop policy if exists "thread likes manage own" on public.thread_likes;
create policy "thread likes insert own"
  on public.thread_likes for insert to authenticated
  with check (user_id = (select auth.uid()));
create policy "thread likes update own"
  on public.thread_likes for update to authenticated
  using (user_id = (select auth.uid()))
  with check (user_id = (select auth.uid()));
create policy "thread likes delete own"
  on public.thread_likes for delete to authenticated
  using (user_id = (select auth.uid()));
