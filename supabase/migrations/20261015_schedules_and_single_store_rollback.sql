-- ============================================================================
-- Rollback Migration: 20261015_schedules_and_single_store_rollback.sql
-- Goal: Safely revert changes introduced by 20261015 without deleting or dropping
--       ANY pre-existing tables or historical data.
-- Pre-existing tables PRESERVED IN FULL:
--  - public.schedules
--  - public.schedule_students
--  - public.teacher_availability
--  - public.student_history
--  - public.leads
--  - public.enrollments
-- ============================================================================

-- ---------------------------------------------------------------------------
-- 1. DROP ONLY NEW TABLES CREATED IN 20261015 (NEVER TOUCH PRE-EXISTING TABLES)
-- ---------------------------------------------------------------------------
DROP TABLE IF EXISTS public.afterschool_past_records CASCADE;
DROP TABLE IF EXISTS public.tutoring_past_records CASCADE;
DROP TABLE IF EXISTS public.alert_logs CASCADE;
DROP TABLE IF EXISTS public.campaigns CASCADE;
DROP TABLE IF EXISTS public.lead_interactions CASCADE;

-- ---------------------------------------------------------------------------
-- 2. DROP NEWLY ADDED INDEXES (PRESERVES DATA IN TABLES)
-- ---------------------------------------------------------------------------
DROP INDEX IF EXISTS public.idx_schedules_open;
DROP INDEX IF EXISTS public.idx_leads_created_at;
DROP INDEX IF EXISTS public.idx_enrollments_submitted;

-- ---------------------------------------------------------------------------
-- 3. DROP NEWLY ADDED COLUMNS FROM PRE-EXISTING TABLES (OPTIONAL / SAFE REVERT)
-- Keeps all existing core rows and original columns intact
-- ---------------------------------------------------------------------------
ALTER TABLE public.schedules DROP COLUMN IF EXISTS open_for_teachers;
ALTER TABLE public.schedules DROP COLUMN IF EXISTS program;

ALTER TABLE public.leads DROP COLUMN IF EXISTS notes;
ALTER TABLE public.leads DROP COLUMN IF EXISTS utm_parameters;
ALTER TABLE public.leads DROP COLUMN IF EXISTS last_interaction_at;

ALTER TABLE public.enrollments DROP COLUMN IF EXISTS calculated_age;

-- ---------------------------------------------------------------------------
-- 4. REVERT HELPER FUNCTIONS TO UUID SIGNATURE IF NEEDED
-- ---------------------------------------------------------------------------
DROP FUNCTION IF EXISTS public.my_schedule_ids() CASCADE;

CREATE OR REPLACE FUNCTION public.my_schedule_ids()
RETURNS SETOF UUID
LANGUAGE plpgsql STABLE SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  r TEXT := public.get_current_user_role();
BEGIN
  IF r = 'TEACHER' THEN
    RETURN QUERY
      SELECT sc.id::uuid FROM public.schedules sc
      WHERE lower(coalesce(sc.teacher_id, '')) = ANY (public.my_teacher_keys())
         OR lower(coalesce(sc.teacher_name, '')) = ANY (public.my_teacher_names());
  ELSIF r IN ('PARENT', 'STUDENT') THEN
    RETURN QUERY
      SELECT ss.schedule_id::uuid FROM public.schedule_students ss
      JOIN public.students s ON (s.id::text = ss.student_id OR s.student_id_code = ss.student_id OR s.student_id_code = ss.student_code)
      WHERE (r = 'STUDENT' AND s.user_id = auth.uid())
         OR (r = 'PARENT' AND (
              lower(auth.jwt() ->> 'email') = ANY (s.parent_emails)
            ));
  ELSE
    RETURN;
  END IF;
END;
$$;
