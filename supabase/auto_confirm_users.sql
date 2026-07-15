-- ============================================================
-- SQL Script to Auto-Confirm All Users (Bypasses Email Verification)
-- ============================================================
-- By default, Supabase requires users to click a confirmation link
-- sent via email. If the email provider is not fully configured,
-- or if the user registers with a real email, they cannot sign in.
--
-- This script:
-- 1. Automatically confirms any newly registered user.
-- 2. Confirms any existing user who is currently unconfirmed.
-- ============================================================

-- 1. Helper function to auto-confirm users
create or replace function public.auto_confirm_user()
returns trigger
language plpgsql
security definer
set search_path = public, auth
as $$
begin
  -- Force confirm the email
  new.email_confirmed_at = coalesce(new.email_confirmed_at, timezone('utc', now()));
  return new;
end;
$$;

-- 2. Drop trigger if exists and create it before insert on auth.users
drop trigger if exists on_auth_user_created_before on auth.users;
create trigger on_auth_user_created_before
  before insert on auth.users
  for each row execute function public.auto_confirm_user();

-- 3. Confirm all existing users who registered but haven't confirmed yet
update auth.users
set email_confirmed_at = timezone('utc', now())
where email_confirmed_at is null;
