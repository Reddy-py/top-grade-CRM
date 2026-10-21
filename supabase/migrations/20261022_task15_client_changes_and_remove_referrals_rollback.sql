-- ============================================================================
-- Rollback: 20261022_task15_client_changes_and_remove_referrals_rollback.sql
-- Reverses exclusion constraints, triggers, and extra columns from migration 18.
-- ============================================================================

DROP TRIGGER IF EXISTS trg_check_student_slot_collision ON public.schedule_students;
DROP FUNCTION IF EXISTS public.check_student_slot_collision();

ALTER TABLE public.schedules DROP CONSTRAINT IF EXISTS no_teacher_slot_collision;
ALTER TABLE public.schedules DROP CONSTRAINT IF EXISTS no_room_slot_collision;

DROP TRIGGER IF EXISTS trg_sync_schedule_minutes ON public.schedules;
DROP FUNCTION IF EXISTS public.sync_schedule_minutes();
DROP FUNCTION IF EXISTS public.time_to_minutes(text);

ALTER TABLE public.schedules DROP COLUMN IF EXISTS start_minute;
ALTER TABLE public.schedules DROP COLUMN IF EXISTS end_minute;

ALTER TABLE public.courses DROP COLUMN IF EXISTS duration_months;
ALTER TABLE public.courses DROP COLUMN IF EXISTS package_hours;
ALTER TABLE public.courses DROP COLUMN IF EXISTS package_price;
ALTER TABLE public.courses DROP COLUMN IF EXISTS hourly_rate;

DROP INDEX IF EXISTS idx_students_school;
DROP INDEX IF EXISTS idx_students_status;
DROP INDEX IF EXISTS idx_students_created_at;
DROP INDEX IF EXISTS idx_schedule_students_student_id;
DROP INDEX IF EXISTS idx_schedule_students_schedule_id;
DROP INDEX IF EXISTS idx_schedules_day_teacher;
DROP INDEX IF EXISTS idx_attendance_student_status;

DROP POLICY IF EXISTS "admin_all_student_dossiers" ON public.student_dossiers;

