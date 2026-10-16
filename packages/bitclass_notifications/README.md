# BitClass notifications

Both the LMS and admin web app use this local package. Import
`package:bitclass_notifications/bitclass_notifications.dart` and call
`ScaffoldMessenger.of(context).showAppSnackBar(SnackBar(...))`.

The helper preserves content, styling, and action callbacks. It replaces the
visible snackbar immediately, clears queued messages, uses a two-second display
time with 150 ms entrance / 100 ms exit animations, and suppresses identical
messages while they are active without restarting their timeout. A message may
appear again after dismissal. Custom widget content can supply `notificationId`
for duplicate detection.

Floating snackbars respect scaffold navigation and floating action button
placement; surrounding margins do not intercept taps. Actionable messages remain
available when accessible navigation is enabled. New messages still replace them.

Use the helper instead of calling `showSnackBar`, `clearSnackBars`, or
`hideCurrentSnackBar` before displaying a notification. Tests are in the root
application at `test/shared/widgets/app_snackbar_test.dart`.
