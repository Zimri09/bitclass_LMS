# BitClass LMS — 30-Day Thesis Presentation Workflow

**Target:** finish with a stable, demonstrable Flutter LMS, evidence of testing and evaluation, a submitted thesis package, and a rehearsed presentation.

**Project baseline (28 July 2026):** BitClass is a Flutter LMS using Supabase, Bloc/Cubit, GoRouter, Hive, and a dark developer-focused interface. The repository includes authentication, courses/enrolment, lessons, quizzes, assignments/submissions/grading, discussions, files, grades, todos, profile, notifications, and settings. Treat the README feature list as a *claim to verify* during Week 1—not as proof that every flow works end to end.

## Non-negotiable scope

The thesis demo should tell one coherent story instead of showing every screen:

1. An **instructor** signs in, creates/publishes a course, adds a lesson, creates an assignment/quiz, and reviews a submission.
2. A **student** signs in, discovers/enrols in the course, studies a lesson, submits work, attempts a quiz, discusses a question, and sees a grade.
3. The system persists the important actions in **Supabase** with appropriate role-based permissions and stores course material in **Storage**.

Keep a feature in the final demo only when it supports that story and has passed its acceptance check. Todos, profile, settings, and notifications are supporting features; do not let them delay the learning cycle above.

## Working rules for the whole month

- Use one task board with the columns **Backlog → This week → In progress → Verify → Done**. A task reaches Done only with evidence: commit, screenshot/video, test result, or reviewer sign-off.
- Work in a feature branch per logical change, commit small verified changes, and keep `main` runnable.
- Start every day with 10 minutes: check the board, choose one deliverable, and write the expected proof. End with 10 minutes: commit/push, update the board, record blockers.
- Protect the final seven days: only fix defects, improve documentation, collect evidence, and rehearse. Do not introduce optional features then.
- Maintain `docs/evidence/` locally (or another private folder) for dated screenshots, test logs, consent forms, evaluation sheets, and demo recordings. Never commit real student data, Supabase secrets, or anonymous keys intended to be private.

## Definition of ready

Before the presentation, all of the following must be true:

- Two realistic accounts exist: `Instructor Demo` and `Student Demo`; neither uses personal data.
- One polished sample course contains a thumbnail, 2–3 lessons, one quiz, one assignment, a file, a discussion channel/thread, a submission, and a graded result.
- The core instructor and student flows work against the intended presentation environment, not only mock data.
- Tests and static analysis have a dated record; all known critical/major defects are fixed or explicitly disclosed as limitations.
- The thesis has consistent problem, objectives, methods, architecture, implementation, results, conclusion, references, and appendices.
- Slides, a timed demo script, screenshots, and an offline backup are ready; the full defense has been rehearsed at least twice.

---

## Week 1 — Stabilize the product and lock the thesis direction

**Week outcome:** a verified baseline, a frozen minimum viable thesis scope, and an approved evaluation plan.

### Day 1 — Project audit and scope lock

1. Run `flutter pub get`, `flutter analyze`, and `flutter test`; save terminal output with date in the evidence folder.
2. Build/run on the intended demo device or web browser. Record Flutter/Dart versions and device/browser details.
3. Make a feature verification table: feature, user role, route, data source, manual test status, automated test status, blocker, demo priority.
4. Mark features **Core**, **Support**, or **Out of scope**. Core should be authentication, course/enrolment, lessons, assignment submission/grading, quiz, and grades.
5. Write a one-paragraph project statement: problem, target users, proposed solution, and expected benefit.

**Evidence:** baseline command logs, initial issue list, signed-off scope statement.

### Day 2 — Thesis framework and requirements

1. Draft Chapter 1: background, problem statement, objectives, scope/limitations, and significance.
2. Turn every objective into measurable requirements. Example: “Students can submit programming assignments” maps to create assignment, view details, submit code, instructor grade, student view grade.
3. Create a requirements traceability matrix: Objective → Functional requirement → Screen/API/table → Test case → Screenshot/result.
4. Identify stakeholders and evaluation participants (for example, 1 instructor/teacher and 5–10 student users, subject to adviser approval).

**Evidence:** Chapter 1 draft and traceability matrix v1.

### Day 3 — Backend and data security verification

1. Review `supabase/schema.sql`, storage setup, and any follow-up migrations. List every table and its ownership/role rule.
2. In a non-production Supabase project, apply the required schema/storage scripts in order and document the exact deployment sequence.
3. Test as student and instructor: unauthenticated access denied; students cannot edit other students’ submissions/grades; instructors can only manage their own course data; uploads respect permissions.
4. Move any credentials out of source-controlled files and confirm the presentation build can obtain its configuration safely.
5. Seed only synthetic demo data and make a database reset/reseed procedure.

**Evidence:** ERD, RLS/Storage authorization test table, deployment and reset procedure.

### Day 4 — Core student journey

Verify in sequence, using the Student Demo account:

1. Register/sign in and recover password if included in scope.
2. Browse catalog, open course, enrol, and see the course under enrolled courses.
3. Open a lesson; verify markdown and code snippets render correctly.
4. Open and submit an assignment; verify validation/error states and persisted submission.
5. Complete a quiz; verify result/score handling.
6. Post a discussion thread/reply and open/download a course file.
7. Open grades and confirm the student view is correct before and after grading.

Log each failure with reproduction steps, expected versus actual behaviour, screenshot, severity, and owner.

**Evidence:** student acceptance checklist and screenshots for each successful core step.

### Day 5 — Core instructor journey

Verify in sequence, using the Instructor Demo account:

1. Sign in and create/edit/publish a course.
2. Add/edit a lesson and confirm the student can view it.
3. Create/edit an assignment and a quiz; verify deadlines, points, question/answer validation, and visibility.
4. Upload a course file and create/manage a discussion channel.
5. View a student submission, grade it with feedback, and confirm the student sees the result.
6. Confirm student users are blocked from instructor-only create/edit/grade screens and actions.

**Evidence:** instructor acceptance checklist, role-guard test result, prioritized defect backlog.

### Day 6 — Fix critical path and add targeted tests

1. Fix all blockers that prevent the two core journeys. Do not redesign unrelated screens.
2. Replace the placeholder widget test with a meaningful smoke test when practical.
3. Add unit tests for highest-risk models/repositories and widget tests for authentication state, role-aware navigation, course enrolment state, assignment submission validation, and grade visibility.
4. For each bug fixed, add a regression test when it is feasible and valuable.

**Evidence:** commits linked to defects; passing targeted test output.

### Day 7 — Week 1 gate and adviser checkpoint

1. Re-run analysis/tests and the full manual core journeys.
2. Decide whether each non-core feature remains in scope. Defer anything not working reliably.
3. Show adviser/supervisor: problem/objectives, architecture draft, requirements matrix, and a 3–5 minute core-flow demo.
4. Record feedback as actions with owner and due date.

**Gate:** continue only with a stable end-to-end core path. If it is not stable, allocate Week 2 to reliability—not new features.

---

## Week 2 — Complete validation, test quality, and thesis implementation chapters

**Week outcome:** demonstrable core functionality, credible quality evidence, and drafts of Chapters 2–3.

### Day 8 — Architecture and design artifacts

1. Draw a system context diagram: Student/Instructor → Flutter app → Supabase Auth/Postgres/Storage.
2. Create an ERD from the actual Supabase schema; include primary keys, foreign keys, and role-sensitive relationships.
3. Draw one sequence diagram for assignment submission and grading.
4. Draw use-case diagrams for Student and Instructor. Keep names aligned with actual implemented features.
5. Document the application layers: presentation (screens/Bloc/Cubit), data (repositories/models), and backend.

**Evidence:** versioned diagrams and Chapter 3 architecture section.

### Day 9 — UX, accessibility, and error handling

1. Walk all core screens on the presentation device size. Fix clipped text, unreadable contrast, oversized dialogs, broken back navigation, and missing loading/empty/error states.
2. Test slow/no network, empty course data, invalid form inputs, expired/no session, duplicate submission attempts, and failed upload.
3. Standardize user-facing errors: plain language, recovery action, no raw exception text.
4. Capture before/after screenshots for material UX improvements.

**Evidence:** UX test checklist and resolved defect list.

### Day 10 — Automated test and code-quality day

1. Add tests to cover all core model serialization and repository success/failure paths where testable.
2. Add widget tests for the highest-value screens; do not inflate counts with trivial assertions.
3. Run formatter, analyzer, and full tests. Resolve warnings that affect maintainability, null safety, or user flows.
4. Create a testing table for the thesis: ID, requirement, test steps/input, expected result, actual result, status.

**Evidence:** dated quality report with command outputs and test matrix.

### Day 11 — Functional acceptance testing

1. Execute the complete test matrix on the same platform planned for the defense.
2. Test both roles and cross-role synchronization: instructor publishes/grades, student immediately observes allowable changes.
3. Confirm authorization by attempting prohibited direct navigation and prohibited data actions.
4. Classify every failure: blocker, major, minor, cosmetic. Fix blockers/majors first.

**Evidence:** signed test matrix and issue tracker export/screenshot.

### Day 12 — Chapter 2 (related literature/system comparison)

1. Gather adviser-approved academic sources on LMS usability, mobile learning, programming education, assessment, and role-based access.
2. Write a synthesis, not a catalog: compare what existing work/platforms provide, their gaps for the target setting, and how BitClass addresses a defined gap.
3. Make a comparison table with only defensible criteria: roles, mobile access, code-oriented assignments, quizzes, discussions, grading, and deployment model.
4. Cite every claim consistently in the required style.

**Evidence:** Chapter 2 draft and reference library.

### Day 13 — Chapter 3 (method and development process)

1. State the development approach actually followed (for example, iterative/agile) and show the month plan as the final iteration plan.
2. Explain participant selection, evaluation instrument, task scenarios, consent/privacy handling, and analysis method—pending adviser/ethics requirements.
3. Include requirements, use cases, architecture, ERD, and test approach.
4. Ensure methodology describes what you can genuinely perform; do not claim an unrun study.

**Evidence:** Chapter 3 draft ready for review.

### Day 14 — Week 2 gate and pilot evaluation

1. Run a 10–15 minute pilot with one representative user if permitted.
2. Give a fixed task script: enrol, open lesson, submit assignment, attempt quiz, find grade; instructor creates/grades.
3. Record task completion, errors, time, comments, and consent using anonymous IDs.
4. Fix recurring usability blockers, then freeze the core feature set.

**Gate:** all core workflows pass manual acceptance; thesis Chapters 1–3 are coherent with the app.

---

## Week 3 — Evaluate, package results, and build the presentation

**Week outcome:** defensible results, near-final thesis, presentation deck, and a rehearsable demo.

### Day 15 — Evaluation setup

1. Finalize participant instructions, consent, and short questionnaire with adviser approval.
2. Prepare the demo database, accounts, course content, task scripts, and a data-capture sheet.
3. Define success metrics before collecting data: task completion rate, critical errors, average satisfaction/usability scores, and qualitative themes.
4. Schedule evaluations and reserve time for data cleaning.

**Evidence:** approved instrument, participant pack, and evaluation plan.

### Days 16–17 — Conduct evaluation

1. Brief each participant, obtain consent, and assign an anonymous code.
2. Observe without coaching except when the protocol allows it.
3. Record task success/failure, important errors, time (if used), comments, and survey response.
4. Back up raw anonymized responses and maintain a participant log separately from identifying data.

**Evidence:** anonymized raw results and completed task sheets.

### Day 18 — Analyze results

1. Calculate only the statistics your sample supports (counts, percentages, means/medians, and short item summaries).
2. Make 2–4 clean charts/tables: participant profile if appropriate, task completion, survey summary, and top feedback themes.
3. Separate findings from interpretation. Report limitations: sample size, demo environment, platform coverage, and unfinished/non-core features.
4. Link each result to an objective and requirement.

**Evidence:** reproducible results tables/charts and results narrative.

### Day 19 — Write Chapters 4 and 5

1. Chapter 4: present implementation highlights, test results, evaluation results, and objective-by-objective discussion.
2. Chapter 5: conclusion, contributions, limitations, and specific future work.
3. Do not describe a feature as completed unless it was verified. Do not claim broad effectiveness from a small pilot.
4. Update abstract only after the final results are stable.

**Evidence:** full thesis draft v1.

### Day 20 — Build the defense deck

Use 10–14 slides unless your institution specifies otherwise:

1. Title and team
2. Problem/context
3. Objectives and scope
4. Related gap / proposed solution
5. Methodology and development process
6. System architecture and technology stack
7. Key workflows / use cases
8. Data model and security/RLS approach
9. Key implementation screens
10. Testing and quality evidence
11. Evaluation results
12. Conclusion, limitations, future work
13. Live demo transition (optional)
14. Questions

Use screenshots and diagrams, not dense paragraphs. Ensure every number matches the thesis.

**Evidence:** slides v1 and speaker notes.

### Day 21 — Record demo and rehearsal #1

1. Write a 5–7 minute demo script with exact taps/clicks, account to use, expected screen, and one sentence explaining the value of each step.
2. Record a clean backup video showing instructor setup followed by student learning/submission and instructor grading/grade visibility.
3. Rehearse the full presentation with a timer. Mark unclear transitions, jargon, and overlong sections.
4. Prepare likely panel questions: why Flutter/Supabase, privacy/RLS, data model, test coverage, evaluation validity, limitations, scalability, and future work.

**Gate:** thesis results, slides, and demo tell the same verified story.

---

## Week 4 — Final verification, submission, and defense readiness

**Week outcome:** a polished thesis package and a reliable, practiced presentation.

### Day 22 — Defect triage and release candidate

1. Re-test the exact demo script from a clean app launch/session.
2. Fix only blockers and high-impact demo defects. Defer cosmetic or risky changes.
3. Tag the presentation-ready code version (for example, `v1.0-thesis`) and record the commit hash in the thesis appendix.
4. Export/build the intended platform and validate that build, not only debug mode.

**Evidence:** release candidate build, release notes, known limitations list.

### Day 23 — Final screenshots and appendices

1. Capture consistent high-resolution screenshots of the key student/instructor screens with synthetic data.
2. Add appendices: user guide, test cases/results, selected code snippets only where required, database schema/ERD, questionnaire, anonymized summary, and deployment instructions.
3. Caption every figure/table and reference it from the text.
4. Verify screenshots never expose keys, emails, or identifiable participant data.

**Evidence:** complete appendix pack and figure inventory.

### Day 24 — Thesis edit pass

1. Check objective/requirement terminology is consistent across Chapters 1–5, figures, slides, and demo narration.
2. Check citations, bibliography, pagination, headings, list of figures/tables, spelling, and required template rules.
3. Ask one peer to read for clarity and one technical reviewer/adviser to inspect accuracy if available.
4. Resolve feedback and archive a PDF snapshot.

**Evidence:** thesis v2 PDF and reviewer action list.

### Day 25 — Rehearsal #2 and Q&A drill

1. Present to a mock audience without reading slides; target the allotted time minus 10%.
2. Run the live demo and then deliberately use the backup recording once, so the transition is practiced.
3. Answer at least 15 anticipated questions in one-minute responses. Ground answers in actual implementation/evaluation evidence.
4. Improve only presentation clarity, demo reliability, and factual precision.

**Evidence:** timing sheet and question bank with prepared answers.

### Day 26 — Reliability and backup day

1. Run the demo with the actual network/device/cables/adapter if known.
2. Prepare two independent backups: local demo video and PDF slides on a USB drive/cloud location; keep code export and build artifact separately.
3. Prepare a reset script/checklist for demo accounts and data. Test it once.
4. Print or save a one-page presenter card: opening, demo steps, results numbers, limitations, and closing statement.

**Evidence:** verified backup checklist.

### Day 27 — Final validation and submission packaging

1. Run formatter, analyzer, tests, and one complete manual smoke test. Save final results.
2. Confirm repository is clean except for intended thesis/evidence materials; document the final commit/tag.
3. Package files using required names/formats: thesis PDF/source, slides PDF/PPTX, source code or repository link, build/app artifact, appendices, and demo video if requested.
4. Submit early where permitted and retain proof of submission.

**Evidence:** final validation log and submission receipt.

### Day 28 — Light rehearsal and rest

1. Give one final calm run-through; do not make code changes after it unless a true blocker appears.
2. Confirm travel/room/online meeting logistics, charging, adapters, logins, and attire.
3. Sleep; clarity and confidence matter more than last-minute features.

### Days 29–30 — Presentation buffer / defense day

1. Use the live demo only if the environment is working; switch immediately to the recorded demo if it is not.
2. State limitations plainly, then redirect to validated results and planned future work.
3. After defense, record panel feedback, archive the final release, and create a short post-defense improvement list.

---

## Daily core-flow acceptance checklist

Run this checklist at least on Days 7, 14, 22, and 27:

| ID | Scenario | Pass condition |
|---|---|---|
| CF-01 | Authentication | Student and instructor can sign in; unauthorized users are redirected safely. |
| CF-02 | Course lifecycle | Instructor creates/publishes a course; student can discover and enrol. |
| CF-03 | Learning content | Student reads lesson content and code blocks render clearly. |
| CF-04 | Assessment | Student submits assignment and attempts quiz; data persists. |
| CF-05 | Grading | Instructor grades with feedback; student sees correct grade. |
| CF-06 | Collaboration | Student can participate in course discussion. |
| CF-07 | Materials | Authorized user can upload/list/download appropriate course files. |
| CF-08 | Access control | Student cannot create/edit/grade instructor resources or access another student’s private work. |
| CF-09 | Resilience | Loading, empty, invalid-input, and failed-network states give recoverable feedback. |

## Presentation demo script (6 minutes)

| Time | Action | Message to panel |
|---|---|---|
| 0:00–0:30 | State problem and user roles. | BitClass centralizes programming-course learning, assessment, and feedback for students and instructors. |
| 0:30–1:30 | Instructor opens/publishes a prepared course and assignment. | Instructor tools create structured content and assessments. |
| 1:30–3:00 | Student enrols, opens lesson, submits code, and completes a quiz. | The student journey is focused on learning and demonstrable progress. |
| 3:00–4:00 | Show discussion/file access. | Supporting collaboration and materials are tied to the course. |
| 4:00–5:00 | Instructor grades; student views grade/feedback. | This closes the assessment loop and demonstrates role-aware data access. |
| 5:00–6:00 | Show test/evaluation result slide and acknowledge limitations. | Claims are supported by defined tests and the stated evaluation scope. |

## Risk triggers and immediate response

| Trigger | Response |
|---|---|
| A core flow fails by Day 7 | Stop feature expansion; fix/re-scope until the instructor–student assessment loop works. |
| Supabase access/RLS is unreliable | Use a separate demo project, retest policies, and keep a reset/seed procedure; never bypass security merely for the demo. |
| Evaluation recruitment is delayed | Ask adviser for an approved smaller pilot or alternative validation method; document the limitation. |
| Test suite is slow/flaky | Isolate the failing test, record the issue, run reliable targeted tests plus manual acceptance; do not hide failures. |
| Live demo network fails | Switch to the rehearsed local recording and continue with screenshots/results. |
| Writing falls behind | Freeze product changes and finish objective-linked chapters before polishing optional sections. |

## Final handoff checklist

- [ ] Final source commit/tag and repository link recorded
- [ ] Reproducible Supabase schema/storage setup and synthetic seed procedure
- [ ] Final analyzer/test/manual-acceptance evidence
- [ ] Thesis PDF, editable source, citations, figures, and appendices verified
- [ ] Slides and speaker notes synchronized with thesis results
- [ ] Live build, demo accounts, reset checklist, video, USB/cloud backups verified
- [ ] Q&A sheet includes security, architecture, testing, evaluation, limitations, and future-work answers

