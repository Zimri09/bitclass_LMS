# BitClass Push Notification Setup

The Flutter and Supabase implementations are complete, but FCM cannot send
production notifications until the private Firebase credentials are supplied.
No service-account key or webhook secret belongs in this repository or in the
mobile application.

## Implemented

- Android notification permission, FCM token retrieval, token refresh, and
  foreground notification display.
- Background and terminated-state delivery and notification-tap routing.
- Token removal and topic cleanup on logout.
- Role, course-membership, and notification-type topic synchronization.
- Supabase RLS-protected device registrations with last-seen timestamps.
- Durable notification rows for enrollment, published lessons, assignments,
  quizzes, announcements, discussion replies, and assignment grades.
- An FCM HTTP v1 Edge Function that applies push preferences and quiet hours,
  sends to every active user device, and removes invalid FCM tokens.

## Required Production Secrets

1. In Firebase Console, open **Project settings > Service accounts** and create
   a service-account key for the `bitclass-lms` Firebase project. Enable the
   Firebase Cloud Messaging HTTP v1 API and grant only the permissions required
   to send FCM messages.
2. Generate a long random value for `PUSH_WEBHOOK_SECRET`.
3. Set these Supabase Edge Function secrets:

   ```powershell
   supabase secrets set --project-ref ksrverpyybrwpoocbvqx `
     FIREBASE_SERVICE_ACCOUNT_JSON='<the complete one-line service account JSON>' `
     PUSH_WEBHOOK_SECRET='<the random shared secret>'
   ```

4. Add the dispatcher URL and the same shared secret to Supabase Vault from the
   SQL Editor:

   ```sql
   select vault.create_secret(
     'https://ksrverpyybrwpoocbvqx.supabase.co/functions/v1/send-push-notification',
     'push_webhook_url'
   );

   select vault.create_secret(
     '<the same random shared secret>',
     'push_webhook_secret'
   );
   ```

The database dispatcher remains safely inactive when either Vault value is
missing. Notification rows are still saved, so in-app notifications continue
to work and no database transaction fails because FCM is unavailable.

## Platform Status

### Android

`android/app/google-services.json`, the Google Services Gradle plugin, Android
13 notification permission, and the high-priority `bitclass_updates` channel
are configured. Validate on a physical device or an emulator image containing
Google Play services.

### iOS

iOS code paths are implemented, but the repository does not currently contain
`ios/Runner/GoogleService-Info.plist`. Before building for iOS:

1. Register bundle ID `com.example.flutterApplication1` in Firebase and add the
   downloaded `GoogleService-Info.plist` to the Runner target.
2. In Xcode, enable **Push Notifications** and **Background Modes > Remote
   notifications** for Runner.
3. Upload an APNs authentication key or certificate in Firebase Console.
4. Test on a physical Apple device. The iOS simulator is not a production push
   delivery test.

### Web, Windows, macOS, and Linux

Push initialization is intentionally disabled on these targets because the
project has no Firebase web configuration/service worker or desktop Firebase
registration. There are no no-op push methods: unsupported targets report push
as unavailable while in-app notifications remain usable.

## Verification

After configuring secrets:

1. Sign in and accept notification permission.
2. Confirm one row appears in `public.device_tokens` for the user.
3. Publish a lesson or create an announcement from another account.
4. Confirm a row is created in `public.notifications`.
5. Confirm foreground delivery shows a local notification.
6. Background the app and repeat to verify system-tray delivery.
7. Tap the notification and verify BitClass opens the linked course item.
8. Disable one notification type and verify that type no longer delivers.
9. Enroll and unenroll, then verify the corresponding `course_<uuid>` topic is
   reconciled on the next Realtime event or app resume.

FCM client topics are routing conveniences, not authorization boundaries.
BitClass sends user-specific notification content to RLS-selected device tokens
from the Edge Function rather than trusting topic names to protect course data.
