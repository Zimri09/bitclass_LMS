-- =============================================================================
-- Migration: Add first_name, last_name, age to profiles
-- Replace the single display_name column with separate first/last name fields
-- =============================================================================
-- Run this in Supabase Dashboard → SQL Editor
-- Safe to re-run (uses IF NOT EXISTS / DO $$ blocks)
-- =============================================================================

-- 1. Add new columns (safe if they already exist)
ALTER TABLE public.profiles
  ADD COLUMN IF NOT EXISTS first_name text,
  ADD COLUMN IF NOT EXISTS last_name  text,
  ADD COLUMN IF NOT EXISTS age        integer CHECK (age >= 1 AND age <= 120);

-- 2. Migrate existing display_name data into first_name / last_name
--    Splits on first space: everything before → first_name, rest → last_name
UPDATE public.profiles
SET
  first_name = CASE
    WHEN display_name IS NOT NULL AND position(' ' IN display_name) > 0
      THEN split_part(display_name, ' ', 1)
    ELSE display_name
  END,
  last_name = CASE
    WHEN display_name IS NOT NULL AND position(' ' IN display_name) > 0
      THEN substring(display_name FROM position(' ' IN display_name) + 1)
    ELSE NULL
  END
WHERE display_name IS NOT NULL
  AND first_name IS NULL;

-- 3. *** IMPORTANT *** Update the handle_new_user trigger
--    This fixes the root cause: new signups now correctly save first_name/last_name
--    instead of the old display_name field.
create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into public.profiles (id, email, first_name, last_name, role)
  values (
    new.id,
    new.email,
    coalesce(
      new.raw_user_meta_data->>'first_name',
      -- fallback: if old display_name metadata exists, use it as first name
      new.raw_user_meta_data->>'display_name',
      split_part(new.email, '@', 1)
    ),
    new.raw_user_meta_data->>'last_name',
    coalesce((new.raw_user_meta_data->>'role')::user_role, 'student'::user_role)
  )
  on conflict (id) do update set
    email      = excluded.email,
    first_name = coalesce(excluded.first_name, public.profiles.first_name),
    last_name  = coalesce(excluded.last_name,  public.profiles.last_name),
    role       = coalesce(excluded.role,       public.profiles.role),
    updated_at = timezone('utc', now());
  return new;
end;
$$;

-- 4. (Optional) Drop the old display_name column once you're confident.
--    Comment this out until everything is verified working.
-- ALTER TABLE public.profiles DROP COLUMN IF EXISTS display_name;

-- 5. Verify the results
--   SELECT id, first_name, last_name, age FROM public.profiles LIMIT 10;
