-- Cover every foreign key reported by the database advisor. Besides faster
-- joins, these indexes avoid full-table scans when referenced rows are updated
-- or deleted.
create index if not exists courses_instructor_id_idx
  on public.courses (instructor_id);
create index if not exists discussion_channels_course_id_idx
  on public.discussion_channels (course_id);
create index if not exists discussion_channels_created_by_idx
  on public.discussion_channels (created_by);
create index if not exists enrollments_user_id_idx
  on public.enrollments (user_id);
create index if not exists lesson_progress_lesson_id_idx
  on public.lesson_progress (lesson_id);
create index if not exists lessons_module_id_idx
  on public.lessons (module_id);
create index if not exists notifications_course_id_idx
  on public.notifications (course_id);
create index if not exists notifications_user_id_idx
  on public.notifications (user_id);
create index if not exists questions_quiz_id_idx
  on public.questions (quiz_id);
create index if not exists quiz_answers_attempt_id_idx
  on public.quiz_answers (attempt_id);
create index if not exists quiz_answers_question_id_idx
  on public.quiz_answers (question_id);
create index if not exists quiz_attempts_enrollment_id_idx
  on public.quiz_attempts (enrollment_id);
create index if not exists quiz_attempts_user_id_idx
  on public.quiz_attempts (user_id);
create index if not exists quizzes_course_id_idx
  on public.quizzes (course_id);
create index if not exists quizzes_lesson_id_idx
  on public.quizzes (lesson_id);
create index if not exists replies_author_id_idx
  on public.replies (author_id);
create index if not exists replies_channel_id_idx
  on public.replies (channel_id);
create index if not exists replies_course_id_idx
  on public.replies (course_id);
create index if not exists replies_parent_reply_id_idx
  on public.replies (parent_reply_id);
create index if not exists replies_thread_id_idx
  on public.replies (thread_id);
create index if not exists reply_reactions_user_id_idx
  on public.reply_reactions (user_id);
create index if not exists thread_likes_user_id_idx
  on public.thread_likes (user_id);
create index if not exists thread_reactions_user_id_idx
  on public.thread_reactions (user_id);
create index if not exists threads_author_id_idx
  on public.threads (author_id);
create index if not exists threads_channel_id_idx
  on public.threads (channel_id);
create index if not exists threads_course_id_idx
  on public.threads (course_id);
create index if not exists todos_user_id_idx
  on public.todos (user_id);

-- Evaluate auth.uid() once per statement instead of once for every candidate
-- row. The access rules are unchanged.
alter policy "notification settings read own"
  on public.notification_settings
  using (user_id = (select auth.uid()));

alter policy "notification settings write own"
  on public.notification_settings
  using (user_id = (select auth.uid()))
  with check (user_id = (select auth.uid()));

alter policy "notifications read own"
  on public.notifications
  using (user_id = (select auth.uid()));

alter policy "notifications write own"
  on public.notifications
  using (user_id = (select auth.uid()))
  with check (user_id = (select auth.uid()));

alter policy "thread likes read own"
  on public.thread_likes
  using (user_id = (select auth.uid()));

alter policy "thread likes manage own"
  on public.thread_likes
  using (user_id = (select auth.uid()))
  with check (user_id = (select auth.uid()));

alter policy "todos read own"
  on public.todos
  using (user_id = (select auth.uid()));

alter policy "todos update own"
  on public.todos
  using (user_id = (select auth.uid()))
  with check (user_id = (select auth.uid()));

alter policy "todos insert own"
  on public.todos
  with check (user_id = (select auth.uid()));

alter policy "todos delete own"
  on public.todos
  using (user_id = (select auth.uid()));
