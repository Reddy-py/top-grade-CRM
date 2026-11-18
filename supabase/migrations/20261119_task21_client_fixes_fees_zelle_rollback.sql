-- ==============================================================================
-- Rollback for Migration: 20261119_task21_client_fixes_fees_zelle.sql
-- ==============================================================================

BEGIN;

DROP TABLE IF EXISTS public.fee_due_claims CASCADE;
DROP TABLE IF EXISTS public.fee_dues CASCADE;
DROP TABLE IF EXISTS public.student_exam_dates CASCADE;
DROP TABLE IF EXISTS public.student_parents CASCADE;
DROP INDEX IF EXISTS idx_profiles_lower_email;

COMMIT;
