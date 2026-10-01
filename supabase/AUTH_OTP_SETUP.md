# Supabase Email OTP Setup

The database migration prevents a public profile from being created before
email verification. Complete these hosted Auth settings before testing signup.

## Email Provider

1. Open **Authentication > Providers > Email**.
2. Enable the Email provider.
3. Turn **Confirm email** on.
4. Set **Email OTP length** to `8` digits.
5. Set **Email OTP expiration** to `600` seconds.
6. Keep the resend/rate-limit interval at `60` seconds or longer.

The database cleanup job uses the same 10-minute period. It runs once per
minute and deletes only BitClass registrations that are still unverified.
Resending a code updates the registration deadline. Keep the hosted expiration
setting and `cleanup_expired_unverified_registrations.sql` interval aligned.
Keep the hosted OTP length aligned with `authEmailOtpLength` in the app.

## Confirm Signup Template

Open **Authentication > Email Templates > Confirm signup** and use a template
that includes the numeric token:

```html
<h2>Verify your BitClass account</h2>
<p>Your verification code is:</p>
<p style="font-size: 28px; font-weight: 700; letter-spacing: 6px;">
  {{ .Token }}
</p>
<p>This code expires in 10 minutes.</p>
```

## Reset Password Template

Open **Authentication > Email Templates > Reset Password** and include the
same token variable:

```html
<h2>Reset your BitClass password</h2>
<p>Your password recovery code is:</p>
<p style="font-size: 28px; font-weight: 700; letter-spacing: 6px;">
  {{ .Token }}
</p>
<p>This code expires in 10 minutes.</p>
```

The mobile app verifies this code with Supabase's `recovery` OTP type and asks
for the new password before exposing the authenticated application shell.

## Production Email

BitClass already sends signup and password-recovery OTPs through Supabase
Auth. Configure Resend as Supabase Auth's SMTP provider; do not put a Resend
API key in the Flutter app or in a client-side environment file.

### Configure Resend SMTP

1. In Resend, add and verify the sending domain. Use a dedicated authentication
   subdomain where possible (for example, `auth.example.com`), and create an
   API key for SMTP.
2. In Supabase, open **Project Settings > Authentication > SMTP Settings**,
   enable **Custom SMTP**, and enter:

   | Supabase field | Value |
   | --- | --- |
   | Host | `smtp.resend.com` |
   | Port | `465` |
   | Username | `resend` |
   | Password | The Resend SMTP API key (starts with `re_`) |
   | Sender email | A verified address, e.g. `security@auth.example.com` |
   | Sender name | `BitClass` |

   Port `465` uses an SSL/TLS connection. If the dashboard configuration uses
   STARTTLS instead, use port `587`.
3. Save the settings, then set the Auth email rate limit to a value that fits
   the expected signup and recovery traffic. The app enforces a 60-second
   resend cooldown, but the server-side limit is the authoritative protection.
4. Send a signup OTP to a real, non-team email address and confirm that the
   Resend delivery log shows it as delivered. Repeat once for password recovery.

The Resend free plan permits 3,000 transactional emails per month, capped at
100 per day. Its quota is shared by every Auth email (signup, recovery,
invitation, and email change), so enable a paid plan before expected demand
exceeds the daily cap.

Keep the Resend API key only in Supabase's SMTP settings. If it is ever pasted
into a repository, client build setting, or exposed log, revoke it immediately
and create a replacement key.
