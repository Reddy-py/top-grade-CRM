-- ============================================================================
-- Rollback Migration: 20261019_email_templates_and_automation_rollback.sql
-- ============================================================================

DROP TABLE IF EXISTS public.student_monthly_notes CASCADE;
DROP TABLE IF EXISTS public.email_unsubscribes CASCADE;
DROP TABLE IF EXISTS public.email_templates CASCADE;

ALTER TABLE public.email_log DROP COLUMN IF EXISTS retry_count;
ALTER TABLE public.email_log DROP COLUMN IF EXISTS next_retry_at;
ALTER TABLE public.email_log DROP COLUMN IF EXISTS body_preview;
ALTER TABLE public.email_log DROP COLUMN IF EXISTS metadata;

-- Restore baseline email_log RLS
DROP POLICY IF EXISTS "users_read_own_email_logs" ON public.email_log;
