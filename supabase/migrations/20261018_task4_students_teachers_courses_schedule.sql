-- ============================================================================
-- Migration: 20261018_task4_students_teachers_courses_schedule.sql
-- Description:
-- 1. Table locations (id, name, type CENTER or SCHOOL, address).
-- 2. Institute settings extension for program_types and course_categories (dynamic UI).
-- 3. Students table extension for program_type and notes.
-- 4. Schedules table extension for location_id, location_address, program_type.
-- 5. Row-level security for locations and settings.
-- Safe to run multiple times (idempotent).
-- ============================================================================

-- 1. Create locations table
CREATE TABLE IF NOT EXISTS public.locations (
    id TEXT PRIMARY KEY DEFAULT ('loc-' || floor(extract(epoch from now()) * 1000)::bigint || '-' || substr(md5(random()::text), 1, 6)),
    name TEXT NOT NULL,
    type TEXT NOT NULL CHECK (type IN ('CENTER', 'SCHOOL')),
    address TEXT NOT NULL DEFAULT '',
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);

-- Seed default initial locations if table is empty
INSERT INTO public.locations (id, name, type, address)
VALUES
    ('loc-center-main', 'Main Academic Center', 'CENTER', '123 Education Blvd, Suite 100, Edison, NJ 08817'),
    ('loc-center-west', 'West Campus Center', 'CENTER', '450 Campus Way, Princeton, NJ 08540'),
    ('loc-school-bhashyam', 'Bhashyam High School', 'SCHOOL', '78 School Lane, South Brunswick, NJ 08852'),
    ('loc-school-oakridge', 'Oakridge International School', 'SCHOOL', '102 Oakridge Ave, Plainsboro, NJ 08536'),
    ('loc-school-dps', 'Delhi Public School', 'SCHOOL', '200 DPS Way, North Brunswick, NJ 08902')
ON CONFLICT (id) DO NOTHING;

-- Enable RLS on locations
ALTER TABLE public.locations ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "admin_all_locations" ON public.locations;
CREATE POLICY "admin_all_locations" ON public.locations
    FOR ALL USING (public.get_current_user_role() = 'ADMIN');

DROP POLICY IF EXISTS "auth_read_locations" ON public.locations;
CREATE POLICY "auth_read_locations" ON public.locations
    FOR SELECT USING (auth.role() = 'authenticated');

-- 2. Extend institute_settings with program_types and course_categories
ALTER TABLE public.institute_settings ADD COLUMN IF NOT EXISTS program_types JSONB DEFAULT '["TUTORING", "AFTERSCHOOL"]'::jsonb;
ALTER TABLE public.institute_settings ADD COLUMN IF NOT EXISTS course_categories JSONB DEFAULT '["Coding", "Robotics", "3D Printing", "Math", "Reading", "STEM & Technology", "Science", "Other"]'::jsonb;

UPDATE public.institute_settings
SET
  program_types = COALESCE(program_types, '["TUTORING", "AFTERSCHOOL"]'::jsonb),
  course_categories = COALESCE(course_categories, '["Coding", "Robotics", "3D Printing", "Math", "Reading", "STEM & Technology", "Science", "Other"]'::jsonb)
WHERE id = 'default';

-- 3. Extend students table with program_type and notes
ALTER TABLE public.students ADD COLUMN IF NOT EXISTS program_type TEXT DEFAULT 'TUTORING';
ALTER TABLE public.students ADD COLUMN IF NOT EXISTS notes TEXT DEFAULT '';

-- Backfill program_type from program if already present
UPDATE public.students
SET program_type = CASE
    WHEN program ILIKE '%afterschool%' THEN 'AFTERSCHOOL'
    ELSE 'TUTORING'
END
WHERE program_type IS NULL OR program_type = '';

-- 4. Extend schedules table with location_id, location_address, program_type
ALTER TABLE public.schedules ADD COLUMN IF NOT EXISTS location_id TEXT REFERENCES public.locations(id) ON DELETE SET NULL;
ALTER TABLE public.schedules ADD COLUMN IF NOT EXISTS location_address TEXT DEFAULT '';
ALTER TABLE public.schedules ADD COLUMN IF NOT EXISTS program_type TEXT DEFAULT 'TUTORING';

-- Backfill schedule program_type from program
UPDATE public.schedules
SET program_type = CASE
    WHEN program ILIKE '%afterschool%' THEN 'AFTERSCHOOL'
    WHEN program IS NOT NULL AND program <> '' THEN UPPER(program)
    ELSE 'TUTORING'
END
WHERE program_type IS NULL OR program_type = '';
