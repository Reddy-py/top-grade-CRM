-- Migration: Reset negative balances to 0, populate Parents with sequential TGP001 IDs, and set Exact 36 Courses (TGC001-TGC036)
-- Safe & idempotent SQL for Supabase SQL Editor.

BEGIN;

-- =====================================================================
-- 1. ELIMINATE NEGATIVE HOURS (only positive and 0 neutral allowed)
-- =====================================================================
DO $$
BEGIN
  IF to_regclass('public.token_wallets') IS NOT NULL THEN
    UPDATE public.token_wallets SET balance = 0 WHERE balance < 0;
  END IF;
  IF to_regclass('public.students') IS NOT NULL THEN
    UPDATE public.students SET purchased_hours = 0 WHERE purchased_hours < 0;
  END IF;
END $$;

DO $$
BEGIN
  IF to_regclass('public.token_ledger') IS NOT NULL THEN
    CREATE OR REPLACE VIEW public.student_course_balance AS
    SELECT
      student_id,
      course_id,
      GREATEST(0, COALESCE(SUM(hours), 0))::numeric(6, 2) AS available_tokens
    FROM public.token_ledger
    WHERE expires_at IS NULL OR expires_at > now()
    GROUP BY student_id, course_id;
  END IF;
END $$;

-- =====================================================================
-- 2. PARENTS TABLE: ADD parent_id_code (TGP001+) & BACKFILL FROM STUDENTS
-- =====================================================================
CREATE TABLE IF NOT EXISTS public.parents (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  profile_id UUID REFERENCES public.profiles(id) ON DELETE SET NULL,
  parent_id_code TEXT,
  name TEXT NOT NULL,
  email TEXT NOT NULL,
  phone TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

ALTER TABLE public.parents ADD COLUMN IF NOT EXISTS parent_id_code TEXT;

-- Populate missing parent records from students.parent_emails (with real emails)
INSERT INTO public.parents (name, email, phone)
SELECT DISTINCT ON (LOWER(TRIM(pe)))
  COALESCE(NULLIF(TRIM(s.father_name), ''), NULLIF(TRIM(s.mother_name), ''), NULLIF(TRIM(s.guardian), ''), 'Parent of ' || COALESCE(s.name, 'Student')),
  LOWER(TRIM(pe)),
  COALESCE(s.father_phone, s.phone)
FROM public.students s,
LATERAL unnest(COALESCE(s.parent_emails, ARRAY[]::TEXT[])) AS pe
WHERE TRIM(pe) <> ''
  AND NOT EXISTS (
    SELECT 1 FROM public.parents p WHERE LOWER(TRIM(p.email)) = LOWER(TRIM(pe))
  )
ORDER BY LOWER(TRIM(pe)), s.created_at ASC NULLS LAST;

-- Ensure parents exist even for students who only had parent names (no email)
INSERT INTO public.parents (name, email, phone)
SELECT
  COALESCE(NULLIF(TRIM(s.father_name), ''), NULLIF(TRIM(s.mother_name), ''), NULLIF(TRIM(s.guardian), ''), 'Parent of ' || COALESCE(s.name, 'Student')),
  LOWER(COALESCE(NULLIF(TRIM(s.student_id_code), ''), SUBSTRING(s.id::text FROM 1 FOR 8))) || '.parent@login.topgrade.local',
  COALESCE(s.father_phone, s.phone)
FROM public.students s
WHERE COALESCE(array_length(s.parent_emails, 1), 0) = 0
  AND NOT EXISTS (
    SELECT 1 FROM public.parents p
    WHERE LOWER(TRIM(p.email)) = LOWER(COALESCE(NULLIF(TRIM(s.student_id_code), ''), SUBSTRING(s.id::text FROM 1 FOR 8))) || '.parent@login.topgrade.local'
  );

-- Sequentially number all parents as TGP001, TGP002, ...
WITH ordered_parents AS (
  SELECT
    id,
    'TGP' || LPAD(ROW_NUMBER() OVER (ORDER BY created_at ASC NULLS LAST, id ASC)::text, 3, '0') AS new_code
  FROM public.parents
)
UPDATE public.parents p
SET parent_id_code = o.new_code
FROM ordered_parents o
WHERE p.id = o.id;

-- Normalize synthetic parent emails to <tgp_code>@login.topgrade.local when using placeholder
UPDATE public.parents
SET email = LOWER(parent_id_code) || '@login.topgrade.local'
WHERE email LIKE '%.parent@login.topgrade.local';

-- =====================================================================
-- 3. EXACT 36 COURSES CATALOG ($1/hr Continuous, TGC001 - TGC036)
-- =====================================================================
CREATE TEMP TABLE _exact_36_courses (
  ord INT,
  course_name TEXT,
  category TEXT
) ON COMMIT DROP;

INSERT INTO _exact_36_courses (ord, course_name, category) VALUES
  (1,  'After school program', 'Programs'),
  (2,  'Before School Program', 'Programs'),
  (3,  'Enrollment fees', 'Administration'),
  (4,  'Summer Camp', 'Programs'),
  (5,  'SAT Prep', 'Test Prep'),
  (6,  'ACT Prep', 'Test Prep'),
  (7,  'CogNT Prep', 'Test Prep'),
  (8,  'College Prep', 'Test Prep'),
  (9,  'STAAR Prep', 'Test Prep'),
  (10, '3D Printing', 'STEM & Technology'),
  (11, 'Coding', 'STEM & Technology'),
  (12, 'Reading', 'Language Arts'),
  (13, 'Math', 'Mathematics'),
  (14, 'Social Sciences', 'Humanities'),
  (15, 'Chemistry', 'Science'),
  (16, 'Physics', 'Science'),
  (17, 'Biology', 'Science'),
  (18, 'Calculus', 'Mathematics'),
  (19, 'Geometry', 'Mathematics'),
  (20, 'English', 'Language Arts'),
  (21, 'French', 'World Languages'),
  (22, 'Spanish', 'World Languages'),
  (23, 'Physcology', 'Social Sciences'),
  (24, 'AP Chemistry', 'AP Courses'),
  (25, 'AP Physics', 'AP Courses'),
  (26, 'AP Biology', 'AP Courses'),
  (27, 'AP Calculus', 'AP Courses'),
  (28, 'AP English', 'AP Courses'),
  (29, 'AP French', 'AP Courses'),
  (30, 'AP Spanish', 'AP Courses'),
  (31, 'AP Physcology', 'AP Courses'),
  (32, 'AP Human Geography', 'AP Courses'),
  (33, 'US History', 'Humanities'),
  (34, 'AP US History', 'AP Courses'),
  (35, 'Economics', 'Social Sciences'),
  (36, 'US Government', 'Social Sciences');

-- Clean up dependent rows for any courses NOT in the 36-course list
DO $$
DECLARE
  del_ids TEXT[];
  tbl TEXT;
  child_course_tables TEXT[] := ARRAY[
    'course_packages',
    'teacher_course_assignments',
    'student_enrollments',
    'schedules',
    'schedule_slots',
    'token_wallets',
    'token_ledger',
    'token_orders',
    'attendance',
    'attendance_records',
    'fees',
    'waitlist_entries'
  ];
BEGIN
  SELECT ARRAY_AGG(id::text) INTO del_ids
  FROM public.courses c
  WHERE NOT EXISTS (
    SELECT 1 FROM _exact_36_courses e
    WHERE LOWER(TRIM(c.name)) = LOWER(TRIM(e.course_name))
  );

  IF del_ids IS NOT NULL AND array_length(del_ids, 1) > 0 THEN
    FOREACH tbl IN ARRAY child_course_tables LOOP
      IF EXISTS (
        SELECT 1
        FROM information_schema.columns
        WHERE table_schema = 'public'
          AND table_name = tbl
          AND column_name = 'course_id'
      ) THEN
        EXECUTE format(
          'DELETE FROM public.%I WHERE course_id::text = ANY($1);',
          tbl
        ) USING del_ids;
      END IF;
    END LOOP;

    DELETE FROM public.courses WHERE id::text = ANY(del_ids);
  END IF;
END $$;

-- Temporarily clear existing course_code values to avoid unique constraint collisions during renumbering
UPDATE public.courses
SET course_code = '__TMP__' || id::text;

-- Insert any of the 36 courses not yet in public.courses (core columns only)
INSERT INTO public.courses (
  name,
  course_code,
  required_teacher_skills,
  description,
  duration,
  fee,
  max_students,
  status
)
SELECT
  e.course_name,
  'TGC' || LPAD(e.ord::text, 3, '0'),
  e.category,
  e.course_name || ' — Continuous Track ($1/hr token)',
  'Continuous (No End Date)',
  1,
  20,
  'Active'
FROM _exact_36_courses e
WHERE NOT EXISTS (
  SELECT 1 FROM public.courses c WHERE LOWER(TRIM(c.name)) = LOWER(TRIM(e.course_name))
);

-- Enforce exact names, continuous $1/hr pricing, and TGC001-TGC036 codes
UPDATE public.courses c
SET
  name = e.course_name,
  course_code = 'TGC' || LPAD(e.ord::text, 3, '0'),
  required_teacher_skills = e.category,
  duration = 'Continuous (No End Date)',
  fee = 1,
  status = 'Active'
FROM _exact_36_courses e
WHERE LOWER(TRIM(c.name)) = LOWER(TRIM(e.course_name));

-- Safely apply optional package/hourly columns only if present in schema
DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema = 'public' AND table_name = 'courses' AND column_name = 'hourly_rate') THEN
    UPDATE public.courses SET hourly_rate = 1;
  END IF;
  IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema = 'public' AND table_name = 'courses' AND column_name = 'duration_months') THEN
    UPDATE public.courses SET duration_months = NULL;
  END IF;
  IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema = 'public' AND table_name = 'courses' AND column_name = 'package_hours') THEN
    UPDATE public.courses SET package_hours = NULL;
  END IF;
  IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema = 'public' AND table_name = 'courses' AND column_name = 'package_price') THEN
    UPDATE public.courses SET package_price = NULL;
  END IF;
END $$;

COMMIT;
