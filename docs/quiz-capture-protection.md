# Quiz capture protections

Student attempts enable protections before showing questions. Submission, deadline closure,
errors that remove quiz content, and route disposal clear the protections. Instructor previews
never enable them. Browser and native listeners are removed at session end. Back navigation
asks for confirmation; backgrounding never submits or changes a grade.

| Platform | Behavior | Limit |
| --- | --- | --- |
| Android | Native FLAG_SECURE while attempting a quiz | OS/device support applies; no reliable blocked-attempt notification |
| iOS | Native capture-state observer shields recording/mirroring; shields inactive app snapshots; logs screenshot notifications | Screenshots are reported AFTER capture, not blocked; capture detection may expose initial frames |
| Web, including mobile browsers | Copy/cut/context-menu/drag deterrents outside answer inputs, print shortcut suppression and blank print output; visibility/blur/unload observations | Cannot block OS screenshots, external capture/recording, cameras, developer tools, or modified clients |
| Other Flutter hosts | Lifecycle observations, explicit unavailable notice | No native capture prevention implemented |

Answer inputs retain selection, copy/paste, keyboard editing and accessibility. Questions are
ordinary non-selectable Flutter text. No clipboard polling, answer logging, screenshot image
collection, or automated cheating penalties are used. A student notice describes logging.

## Storage and rollout

Apply `supabase/migrations/20261025054927_quiz_security_events.sql` before releasing clients.
Students can append only to their own in-progress attempts; server time is assigned by default.
Clients cannot set timestamps, read events, update, or delete them. Course managers use the
existing `private.can_manage_course` authorization helper to read events. Instructor quiz
overviews contain **Quiz activity review**, showing up to 500 recent events with student UUID,
attempt number, platform and local time. Refresh reloads the data. Capability entries distinguish
unsupported capture protection from a capture or focus event.

Telemetry is advisory and best effort. Repeated identical events are suppressed for three seconds.
Network failures do not interrupt the quiz. Offline activity, abrupt termination, browser unload,
and attempts to submit at the same instant as an event can lose events. No offline retry queue
or guaranteed delivery is claimed. A modified client can suppress or fabricate its own events.
A blank log does not prove the student stayed in the quiz.

## Verification

Automated coverage: native method-channel enable/disable and missing/error fallbacks; session
background deduplication and leave-during-enable cleanup; Chrome DOM copy/print/input and listener
cleanup; existing student submission, instructor preview, and quiz RPC tests.

Before production, run the following on physical Android and iOS devices (not yet verified in
this Windows environment):

1. Take a screenshot/record before starting: normal behavior.
2. Start a student quiz: Android screenshot/recording hides quiz; iOS recording/mirroring shields
   content, including recording started before the quiz. iOS screenshots remain possible and
   create a post-capture event. Test app-switcher previews, rotation and multiwindow.
3. Type a long answer, select/edit text, navigate questions, wait through timer ticks, autosave,
   background and resume. Confirm no answer/caret reset and elapsed time still counts.
4. Try back/close, cancel, then confirm. Verify the event and that normal capture returns on the
   next screen. Repeat with submit, deadline expiry, network error, rapid exit/re-entry and preview.
5. Web: test Chrome, Edge, Firefox, Safari and mobile browsers, including browser menu print,
   copy outside fields, input copy/paste, tab switch, refresh/back and OS screenshots. OS captures
   must never be described as blocked. Check editing/copy/printing outside the quiz after exit.
6. On a disposable migrated database verify own in-progress insert succeeds; another student's,
   completed-attempt, unauthenticated, forged timestamp, update/delete and student read fail.
   Verify assigned instructor read succeeds and unrelated instructor read returns no rows.

Native iOS compilation/device testing requires macOS/Xcode. No connected mobile device/emulator
or local PostgreSQL/Docker test runtime was available here; migration policies need execution
against a disposable database before production deployment.

Platform references: [Android secure windows](https://developer.android.com/security/fraud-prevention/activities),
[Apple capture state](https://developer.apple.com/documentation/uikit/uiscreen/iscaptured),
[Apple screenshot notifications](https://developer.apple.com/documentation/uikit/uiapplication/userdidtakescreenshotnotification),
[Browser visibility](https://developer.mozilla.org/en-US/docs/Web/API/Document/visibilitychange_event).

## Results from this implementation

- Passed: `flutter analyze lib/features/quizzes` plus new protection test analysis.
- Passed: eight targeted native-channel/session/student submission/instructor preview/RPC tests.
- Passed: standalone headless Chrome smoke test in `tool/quiz_security/browser_smoke.dart`.
  Compile with `dart compile js tool/quiz_security/browser_smoke.dart -o build/quiz_security/smoke.js`
  and load it from a minimal HTML page in Chrome. The page reports PASS or FAIL.
- Passed: `flutter build apk --debug --no-pub` and `flutter build web --no-pub`.
- Flutter's Chrome test harness stalled at loading (both JS and Wasm); those runs were stopped.
  The standalone Chrome test exercises the actual browser protection implementation without
  Flutter's test harness. Other browser engines and real-device behavior are still pending.
- The full quiz suite also surfaced quiz editor ListTile/DecoratedBox rendering assertions
  outside this change. Targeted changed-flow tests pass.
- `web/index.html` already has global context-menu/DevTools deterrents. They remain unchanged;
  stopping a quiz removes the new listeners, but those pre-existing site-wide restrictions persist.
