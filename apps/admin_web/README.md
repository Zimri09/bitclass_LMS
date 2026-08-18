# BitClass Admin

Web-only Flutter dashboard for administering the BitClass LMS. It connects to
the same Supabase project as the student/instructor application while keeping
its routing, UI, and deployment independent.

## Current scope

- Email/password administrator sign-in
- Database-backed `profiles.role = 'admin'` authorization guard
- Responsive desktop sidebar and mobile drawer
- Platform overview with users, courses, enrollments, and submission counts
- Searchable user directory with role filters
- Searchable published/draft course directory
- Verified-admin role changes and account suspension
- Immutable application audit history for sensitive admin and course actions

Account deletion, enrollment mutation, and broadcast notifications are not
exposed in this browser client. Role and suspension changes are handled by the
JWT-protected `admin-manage-user` Edge Function and recorded in
`admin_audit_logs`; the service key remains server-side.

## Run locally

The development defaults already use the same Supabase project and
frontend-safe public key as the learning app:

```powershell
cd apps/admin_web
flutter pub get
flutter run -d chrome
```

For another Supabase project or a deployment environment, override those
defaults at build time:

```powershell
flutter run -d chrome `
  --dart-define=SUPABASE_URL=https://YOUR_PROJECT.supabase.co `
  --dart-define=SUPABASE_PUBLISHABLE_KEY=YOUR_PUBLISHABLE_KEY
```

Do not pass a Supabase secret key or `service_role` key to this app. Flutter web
build values are visible to browser users; authorization is enforced by the
signed-in user's JWT and database RLS policies.

## Bootstrap the first administrator

Self-registration only creates student or instructor accounts. A project owner
must promote the first already-verified account through a privileged channel,
such as the Supabase SQL Editor:

```sql
select id, email, role
from public.profiles
order by created_at;

-- Replace the email deliberately. Never expose this operation in the browser.
update public.profiles
set role = 'admin'
where email = 'chosen-admin@example.com';
```

After promotion, sign out and back in before opening the admin dashboard.

## Free admin security backend

The migration and Edge Function used by the dashboard are included in this
repository:

```text
supabase/migrations/20260818133000_admin_user_management_and_audit.sql
supabase/functions/admin-manage-user/
```

The live BitClass project already has this migration and function deployed.
For another project, apply the migration and deploy `admin-manage-user` with
JWT verification enabled. This uses the Supabase Free plan's normal database
and Edge Function quotas; paid Platform Audit Logs are not required.

## Validate and build

```powershell
flutter analyze
flutter test
flutter build web --release
```

Configure the hosting provider to rewrite unknown routes to `index.html` so
direct links such as `/users` and `/courses` load correctly.

## Source layout

```text
lib/
├── core/
│   ├── auth/       # Session handling and database role verification
│   ├── config/     # Compile-time environment configuration
│   ├── router/     # Protected GoRouter routes
│   ├── theme/      # BitClass admin theme
│   └── widgets/    # Responsive shell and page primitives
└── features/
    ├── auth/
    ├── dashboard/
    ├── users/
    └── courses/
```
