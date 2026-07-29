# Supabase Email OTP Setup

The database migration prevents a public profile from being created before
email verification. Complete these hosted Auth settings before testing signup.

## Email Provider

1. Open **Authentication > Providers > Email**.
2. Enable the Email provider.
3. Turn **Confirm email** on.
4. Set **Email OTP expiration** to `600` seconds.
5. Keep the resend/rate-limit interval at `60` seconds or longer.

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

Configure a custom SMTP provider before production use. Supabase's default
email service is intended for limited testing and applies restrictive delivery
and rate limits.
