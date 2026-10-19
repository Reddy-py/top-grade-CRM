-- Rollback Migration: 20261021_task8b_hardening_and_password_change_rollback.sql

DROP INDEX IF EXISTS public.idx_profiles_must_change_password;
ALTER TABLE public.profiles DROP COLUMN IF EXISTS must_change_password;
ALTER TABLE public.students DROP COLUMN IF EXISTS first_name;
ALTER TABLE public.students DROP COLUMN IF EXISTS last_name;
ALTER TABLE public.students DROP COLUMN IF EXISTS school;
ALTER TABLE public.students DROP COLUMN IF EXISTS grade;

