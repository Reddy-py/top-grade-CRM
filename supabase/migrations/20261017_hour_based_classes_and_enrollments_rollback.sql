-- ============================================================================
-- Rollback Migration: 20261017_hour_based_classes_and_enrollments_rollback.sql
-- ============================================================================

DROP TABLE IF EXISTS public.student_enrollments CASCADE;

ALTER TABLE public.courses DROP COLUMN IF EXISTS duration_months;
ALTER TABLE public.courses DROP COLUMN IF EXISTS package_hours;
ALTER TABLE public.courses DROP COLUMN IF EXISTS package_price;
ALTER TABLE public.courses DROP COLUMN IF EXISTS hourly_rate;
