# BitClass LMS Feature Verification Checklist

Use this checklist with two fresh accounts: one `student` and one `instructor`.
Run every backend item against the active development Supabase project, not only
demo data. Record the build, device, account role, evidence link, and result
(`Pass`, `Fail`, or `Blocked`) for each item.

## Audit Snapshot

- The application exposes the expected LMS feature areas: authentication,
  courses, lessons, assignments, quizzes, discussions, files, grades,
  notifications, todos, profile, and settings.
- The active configuration is `Environment.development`, pointing to a real
  Supabase project. Production credentials are placeholders, so this build is
  not production-ready without production configuration and verification.
- `flutter analyze`, the complete test suite, and one targeted model test did
  not finish within the audit time limit. Treat the automated quality gate as
  blocked until it completes cleanly in a known-good local/CI environment.
- Current automated coverage is model-focused. The widget test is explicitly a
  placeholder, and no end-to-end role or backend workflow tests were found.

## Release Gates

- [ ] `flutter pub get` completes from a clean checkout.
- [ ] `flutter analyze` completes with no errors; review every warning.
- [ ] `flutter test` completes with no failures or timeouts.
- [ ] Build and smoke-test Android, iOS, web, Windows, macOS, and Linux only
      for the platforms intended to ship.
- [ ] Confirm the selected environment, Supabase URL, storage bucket, app
      version, and redirect URLs are correct for the release target.
- [ ] Confirm database schema, RLS policies, storage bucket, and all required
      migrations have been applied to the target Supabase project.

## Authentication And Profiles

- [ ] Student can register with valid email, name, password, and student role.
- [ ] Instructor can register with valid email, name, password, and instructor role.
- [ ] Invalid email, weak password, duplicate email, and wrong password show a
      clear error without creating a partial profile.
- [ ] Email-confirmation-required flow keeps the user out until confirmation.
- [ ] Login restores the correct profile and role after app restart.
- [ ] Forgot-password email arrives and its redirect completes password reset.
- [ ] Sign-out clears the session and protected deep links return to login.
- [ ] Profile edits persist after restart and are visible only as allowed by RLS.
- [ ] Avatar upload and delete either work with Supabase Storage or are hidden:
      the current implementation is a simulated demo action.
- [ ] Account deletion has a documented retention/cascade behavior and removes
      or anonymizes dependent data as intended.

## Roles, Routing, And Data Access

- [ ] Unauthenticated users cannot open any dashboard, course, file, or grade URL.
- [ ] Student cannot create or edit courses, lessons, quizzes, assignments, or files.
- [ ] Student cannot open or use enrolled-student and submission-grading URLs.
- [ ] Student cannot change another user's profile, enrollment, submission,
      notification settings, or device token through UI or direct API calls.
- [ ] Instructor can manage only courses they own; attempt the same actions on
      another instructor's course.
- [ ] Admin behavior is explicitly implemented and tested, or the admin role is
      removed from the supported-role claim.
- [ ] A non-enrolled student cannot read lessons, assignments, quizzes, files,
      discussion channels, threads, or replies for a course that should be private.
- [ ] A student cannot write course content, grade work, or mark another
      student's quiz/submission data.
- [ ] RLS tests run directly against Supabase for `select`, `insert`, `update`,
      and `delete`; do not rely only on hidden buttons or GoRouter redirects.

## Courses And Enrollment

- [ ] Catalog shows only the intended published courses, with loading, empty,
      and network-error states.
- [ ] Student can view course details and enroll once; duplicate enrollment is prevented.
- [ ] Student's enrolled-course list and dashboard update after enrollment.
- [ ] Instructor can create, edit, publish/unpublish, and view only their courses.
- [ ] Course validation rejects missing required fields and invalid dates/values.
- [ ] Instructor's enrolled-student list matches database enrollments.
- [ ] Course deletion/archive behavior and cascades for modules, content, files,
      enrollments, grades, and discussions are intentional and verified.

## Lessons And Progress

- [ ] Instructor can create, edit, order, publish, and unpublish modules and lessons.
- [ ] Lesson text/Markdown, code blocks, video URLs, and navigation render correctly.
- [ ] Student can access only lessons permitted by course/enrollment/publish status.
- [ ] Completing a lesson creates or updates progress using the student's real
      enrollment ID, and shows a recoverable error when enrollment cannot be confirmed.
- [ ] Completion, last-accessed state, and syllabus progress persist after restart.
- [ ] Large lesson content loads without jank, excessive memory use, or broken Markdown.

## Assignments And Grades

- [ ] Instructor can create, edit, publish, and delete assignments with language,
      starter code, due date, points, late policy, and validation.
- [ ] Student can open an assignment, edit code, save draft, submit, and see the
      correct due/late status after restart.
- [ ] Student cannot submit after the deadline when late submissions are disabled.
- [ ] Instructor can view only submissions for owned courses, assign points and
      feedback, and change status to graded/returned.
- [ ] Student sees only their own submission, feedback, and grade.
- [ ] Grade overview and course/overall calculations match graded quiz attempts
      and assignment submissions, including zero, partial, and late cases.

## Quizzes

- [ ] Instructor can create, edit, publish, and delete quizzes and questions.
- [ ] Question choices, code snippets, correct answers, point values, and order
      persist correctly.
- [ ] Student can start an allowed attempt, save answers, resume safely, submit,
      and view the result.
- [ ] Maximum attempts, pass threshold, timing, auto-grading, and best-attempt
      logic behave correctly at boundaries.
- [ ] Student cannot read answer keys or alter another user's attempt/answers via API.
- [ ] Quiz results flow correctly into the grades screen.

## Discussions, Files, And Notifications

- [ ] Instructor can create/manage course discussion channels; permitted users
      can create, edit, and delete their own threads and replies.
- [ ] Likes, resolved state, and accepted instructor answer persist and cannot
      be changed by unauthorized users.
- [ ] File list supports empty, search/filter, download/open, and error states.
- [ ] Instructor can upload allowed files up to 50 MB; rejected type/size and
      interrupted upload show useful recovery messages.
- [ ] Students can download only files they are authorized to read.
- [ ] File update/delete removes both metadata and storage object as intended.
- [ ] Notification list supports read, mark-all-read, delete, clear, and settings persistence.
- [ ] Push notifications are either fully integrated or described as unavailable:
      FCM token retrieval, permission requests, and topic subscribe/unsubscribe
      are currently stubbed.

## Todos, Settings, And UX

- [ ] Todos create/toggle/delete behavior persists per user and handles empty/error states.
- [ ] Theme, settings, and notification preferences persist after restart.
- [ ] Desktop, tablet, and mobile navigation exposes the correct role-specific items.
- [ ] Keyboard navigation, screen-reader labels, contrast, text scaling, and
      responsive overflow are checked on core screens.
- [ ] Loading, empty, offline, permission-denied, and backend-error states are
      clear and recoverable across every feature.

## Findings To Resolve Before Claiming Full Verification

- [ ] Restore a reliable analyzer/test run. During this audit, `flutter analyze`
      and `flutter test` timed out, including a targeted model test.
- [x] Lesson completion resolves the authenticated student's real enrollment ID
      before creating progress.
- [x] Demo-only profile-avatar controls are hidden outside demo mode.
- [x] Push-delivery controls are disabled outside demo mode until a platform
      integration exists.
- [ ] Implement push-notification platform integration before enabling device
      delivery in development or production.
- [ ] Add widget/integration tests for authentication, role restrictions,
      enrollment, lesson progress, submission/grading, quiz attempts, files,
      and RLS-denied requests.
- [ ] Review RLS policy intent: several course-content read policies permit any
      authenticated user to read published-course data, and the replies policy
      does not check enrollment or course publication.
- [x] Add `harden_rls.sql` to require enrollment for protected course-content,
      discussion, file-metadata, and lesson-progress access. Deployment and
      live RLS verification are still required.
- [ ] Move file downloads from public URLs to signed URLs before making the
      storage bucket private.
- [ ] Separate quiz question prompts from answer keys before allowing students
      to read quiz questions through the client API.
- [x] Add explicit router guards for instructor-only grading and student-list
      URLs; database RLS remains the authoritative protection.
