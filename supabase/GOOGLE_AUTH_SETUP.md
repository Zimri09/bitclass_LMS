# BISU Google authentication setup

The Flutter code and database policy are included in the repository. Google
still requires an OAuth client ID and secret, which must be configured outside
the app and must never be committed.

## Google Auth Platform

1. Create a Web application OAuth client in Google Auth Platform.
2. Add this authorized redirect URI:
   `https://ksrverpyybrwpoocbvqx.supabase.co/auth/v1/callback`
3. Configure the `openid`, email, and profile scopes.
4. Copy the client ID and client secret.

## Supabase

1. Open Authentication > Providers > Google.
2. Enable Google and enter the OAuth client ID and secret.
3. Open Authentication > URL Configuration and add
   `io.bitclass.app://login-callback/` to Redirect URLs.
4. Open Authentication > Hooks and enable **Before User Created** using the
   Postgres function `public.hook_restrict_google_signup_to_bisu`.

The database profile trigger also enforces the exact `bisu.edu.ph` domain, so a
missed hook configuration cannot create a non-BISU Google profile. Email and OTP
registration remain available for instructors and other approved account flows.
