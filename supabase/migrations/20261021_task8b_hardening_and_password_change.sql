-- ============================================================================
-- Migration: 20261021_task8b_hardening_and_password_change.sql
-- Description:
-- 1. Adds `must_change_password` boolean column to public.profiles (default false).
-- 2. Used to force password changes on first login when accounts are provisioned
--    with a shared initial password.
-- 3. Idempotent and safe to run on fresh or existing databases.
-- ============================================================================

ALTER TABLE public.profiles
ADD COLUMN IF NOT EXISTS must_change_password BOOLEAN NOT NULL DEFAULT FALSE;

CREATE INDEX IF NOT EXISTS idx_profiles_must_change_password
ON public.profiles(must_change_password);

-- Task 8b: explicit student grade and school fields
ALTER TABLE public.students ADD COLUMN IF NOT EXISTS first_name TEXT DEFAULT '';
ALTER TABLE public.students ADD COLUMN IF NOT EXISTS last_name TEXT DEFAULT '';
ALTER TABLE public.students ADD COLUMN IF NOT EXISTS school TEXT DEFAULT '';
ALTER TABLE public.students ADD COLUMN IF NOT EXISTS grade TEXT DEFAULT '';

