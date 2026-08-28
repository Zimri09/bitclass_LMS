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

## Why Gmail often shows no code

The default Confirm signup email only contains a **Confirm your mail** link.
Gmail users then see no 8-digit OTP. Gmail also prefetches that confirmation
link, which consumes the token so a typed code fails.

Use OTP-only templates: include `{{ .Token }}`, put the code in the **Subject**
so Gmail's inbox preview shows it, and **do not** include
`{{ .ConfirmationURL }}`.

If a saved template has invalid Go template syntax, Auth silently falls back
to the default link email. Check **Logs > Auth** for
`templatemailer_template_body_parse_error`.

Copy the templates below into the dashboard. Do not add extra `{` characters
or unsupported variables such as `{{ .Data.display_name | default: "x" }}`.

## Confirm Signup Template

Open **Authentication > Email Templates > Confirm signup**.

**Subject**

```text
Your BitClass verification code is {{ .Token }}
```

**Body**

```html
<h2>Verify your BitClass account</h2>
<p>Your verification code is:</p>
<p style="font-size:32px;font-weight:700;font-family:Menlo,Consolas,monospace;color:#111111;letter-spacing:0;">
  {{ .Token }}
</p>
<p>This code expires in 10 minutes. Enter it in BitClass to finish creating your account.</p>
<p>If you did not create a BitClass account, you can ignore this email.</p>
```

## Reset Password Template

Open **Authentication > Email Templates > Reset Password**.

**Subject**

```text
Your BitClass recovery code is {{ .Token }}
```

**Body**

```html
<h2>Reset your BitClass password</h2>
<p>Your password recovery code is:</p>
<p style="font-size:32px;font-weight:700;font-family:Menlo,Consolas,monospace;color:#111111;letter-spacing:0;">
  {{ .Token }}
</p>
<p>This code expires in 10 minutes.</p>
<p>If you did not request a password reset, you can ignore this email.</p>
```

The mobile app verifies this code with Supabase's `recovery` OTP type and asks
for the new password before exposing the authenticated application shell.

## Gmail delivery

1. After saving the templates, create a new account with a Gmail address.
2. Check **Primary**, **Promotions**, **Updates**, and **Spam**.
3. The inbox row should show the 8-digit code in the subject.
4. If no message arrives, the built-in Supabase mailer is rate-limited and
   often blocked by Gmail. Configure a custom SMTP provider
   (**Project Settings > Authentication > SMTP Settings**) with SPF and DKIM
   on your sending domain before production use.
