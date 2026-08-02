# BitClass Supabase SQL

The SQL files in this directory are not an alphabetical installation bundle.
They include the original schema, optional setup scripts, and historical patches
that were added as the application evolved. Running every file, or rerunning the
original schema on an existing project, can fail because objects and RLS policies
already exist or because a prerequisite table has not been created yet.

## Existing hosted project

Do not rerun SQL files that already appear in
`supabase_migrations.schema_migrations`. The migration history in the hosted
project is the source of truth. Apply only a new migration required by a new
application change.

The attendance migrations already installed on the BitClass project are:

1. `add_course_attendance`
2. `optimize_course_attendance_indexes`
3. `harden_attendance_session_creation`
4. `add_attendance_closing_time`

`harden_attendance_session_creation.sql` and
`add_attendance_closing_time.sql` are follow-up patches. They require the
attendance tables from `add_course_attendance.sql` and the authorization helpers
from `harden_rls.sql`. Do not run them by themselves on an empty database.

## Fresh database

Use timestamped files in `supabase/migrations/` and apply them in order. For an
existing remote-first project, pull a baseline migration from the hosted schema
before adding new migrations. Do not use the flat patch files as a replacement
for an ordered migration chain.

At minimum, dependencies must be created in this order:

1. Core tables and functions from `schema.sql`
2. Storage metadata from `setup_storage.sql`
3. RLS helpers and policies from `harden_rls.sql`
4. Feature schemas, such as `add_course_attendance.sql`
5. Feature follow-up patches, such as `harden_attendance_session_creation.sql`

## Common errors

- `relation ... does not exist`: a feature patch was run before its base schema.
- `policy ... already exists`: an installation or hardening script was rerun.
- `function private.can_manage_course(...) does not exist`: `harden_rls.sql` has
  not been applied yet.
- `permission denied`: the SQL executed successfully, but the current API role
  was not granted access or the request no longer has an authenticated session.
- Red editor diagnostics for `auth`, `storage`, or PL/pgSQL do not necessarily
  indicate a server error; verify using the Supabase SQL editor or migrations.

Never reset or replay the full schema against the production project to resolve
one feature error. Capture the exact database error and apply a focused,
timestamped migration instead.
