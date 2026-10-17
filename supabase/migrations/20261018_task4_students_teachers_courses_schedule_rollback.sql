-- ============================================================================
-- Rollback Migration: 20261018_task4_students_teachers_courses_schedule_rollback.sql
-- ============================================================================

ALTER TABLE public.schedules DROP COLUMN IF EXISTS location_id;
ALTER TABLE public.schedules DROP COLUMN IF EXISTS location_address;
ALTER TABLE public.schedules DROP COLUMN IF EXISTS program_type;

ALTER TABLE public.students DROP COLUMN IF EXISTS program_type;
ALTER TABLE public.students DROP COLUMN IF EXISTS notes;

ALTER TABLE public.institute_settings DROP COLUMN IF EXISTS program_types;
ALTER TABLE public.institute_settings DROP COLUMN IF EXISTS course_categories;

DROP TABLE IF EXISTS public.locations CASCADE;
