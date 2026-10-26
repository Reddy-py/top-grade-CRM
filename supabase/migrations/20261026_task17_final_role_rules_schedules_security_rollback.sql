-- ============================================================================
-- Rollback Migration: 20261026_task17_final_role_rules_schedules_security_rollback.sql
-- Description: Rollback of TASK 17 additions.
-- ============================================================================

DROP POLICY IF EXISTS "users_view_own_sessions" ON public.user_sessions;
DROP POLICY IF EXISTS "admin_manage_user_sessions" ON public.user_sessions;
DROP TABLE IF EXISTS public.user_sessions;

DROP POLICY IF EXISTS "admin_manage_fee_audit" ON public.fee_structure_audit;
DROP TABLE IF EXISTS public.fee_structure_audit;

ALTER TABLE public.courses DROP COLUMN IF EXISTS hourly_rate;
ALTER TABLE public.courses DROP COLUMN IF EXISTS package_hours;
ALTER TABLE public.courses DROP COLUMN IF EXISTS package_price;
ALTER TABLE public.courses DROP COLUMN IF EXISTS duration;

ALTER TABLE public.institute_settings DROP CONSTRAINT IF EXISTS chk_institute_settings_self_enrollment_mode;
ALTER TABLE public.institute_settings DROP COLUMN IF EXISTS self_enrollment_mode;

DROP TRIGGER IF EXISTS trg_check_unique_student_per_parent ON public.student_parents;
DROP FUNCTION IF EXISTS public.check_unique_student_per_parent();

DROP POLICY IF EXISTS "parents_view_own_student_parents" ON public.student_parents;
DROP POLICY IF EXISTS "admin_manage_student_parents" ON public.student_parents;
DROP TABLE IF EXISTS public.student_parents;

DROP INDEX IF EXISTS idx_profiles_lower_email;

ALTER TABLE public.courses DROP CONSTRAINT IF EXISTS chk_courses_class_length;
ALTER TABLE public.courses DROP COLUMN IF EXISTS class_length;

ALTER TABLE public.schedules DROP CONSTRAINT IF EXISTS chk_schedules_duration_hours;
ALTER TABLE public.schedules DROP COLUMN IF EXISTS duration_hours;
