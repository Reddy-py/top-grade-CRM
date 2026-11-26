-- Migration: Clean up legacy/removed tables, deduplicate test students, and renumber IDs sequentially
-- (TGST001, TGT001, TGC001, TGSC001)
-- Safe & idempotent SQL for Supabase SQL Editor.

BEGIN;

-- 1. Drop removed Campaigns table and any *_legacy* backup tables cluttering public schema
DROP TABLE IF EXISTS public.campaigns CASCADE;

DO $$
DECLARE
  r RECORD;
BEGIN
  FOR r IN
    SELECT tablename
    FROM pg_tables
    WHERE schemaname = 'public'
      AND (
        tablename LIKE '%\_legacy%' ESCAPE '\'
        OR tablename IN ('attendance_logs', 'schedule_students')
      )
  LOOP
    EXECUTE format('DROP TABLE IF EXISTS public.%I CASCADE;', r.tablename);
  END LOOP;
END $$;

-- 2. Remove synthetic test students (e.g., Benjamin Franklin-1117, @test.edu / @example.org dummy rows)
--    and exact duplicate student records (keeping earliest created_at).
CREATE TEMP TABLE _students_to_delete ON COMMIT DROP AS
WITH ranked AS (
  SELECT
    id,
    ROW_NUMBER() OVER (
      PARTITION BY
        LOWER(TRIM(COALESCE(name, ''))),
        COALESCE(dob::text, ''),
        LOWER(TRIM(COALESCE(email, parent_emails[1], '')))
      ORDER BY created_at ASC NULLS LAST, id ASC
    ) AS dup_rn
  FROM public.students
)
SELECT s.id
FROM public.students s
JOIN ranked r ON r.id = s.id
WHERE
  r.dup_rn > 1
  OR s.name ILIKE 'Benjamin Franklin-%'
  OR COALESCE(s.email, '') ILIKE '%@test.edu'
  OR COALESCE(s.parent_emails[1], '') ILIKE '%@test.edu'
  OR COALESCE(s.email, '') ILIKE '%@example.org'
  OR COALESCE(s.parent_emails[1], '') ILIKE '%@example.org';

-- Clean up child rows referencing deleted students (checks table + column existence first)
DO $$
DECLARE
  tbl TEXT;
  child_tables TEXT[] := ARRAY[
    'token_wallets',
    'token_ledger',
    'token_orders',
    'student_enrollments',
    'student_dossiers',
    'student_history',
    'student_exam_dates',
    'student_monthly_notes',
    'student_parents',
    'parent_students',
    'attendance',
    'attendance_records',
    'fees',
    'fee_dues',
    'invoices',
    'payment_requests',
    'waitlist_entries'
  ];
BEGIN
  FOREACH tbl IN ARRAY child_tables LOOP
    IF EXISTS (
      SELECT 1
      FROM information_schema.columns
      WHERE table_schema = 'public'
        AND table_name = tbl
        AND column_name = 'student_id'
    ) THEN
      EXECUTE format(
        'DELETE FROM public.%I WHERE student_id::text IN (SELECT id::text FROM _students_to_delete);',
        tbl
      );
    END IF;
  END LOOP;
END $$;

DELETE FROM public.students WHERE id IN (SELECT id FROM _students_to_delete);

-- 3. Renumber all remaining Students sequentially: TGST001, TGST002, ...
WITH ordered_students AS (
  SELECT
    id,
    'TGST' || LPAD(ROW_NUMBER() OVER (ORDER BY created_at ASC NULLS LAST, id ASC)::text, 3, '0') AS new_code
  FROM public.students
)
UPDATE public.students s
SET student_id_code = o.new_code
FROM ordered_students o
WHERE s.id = o.id;

-- 4. Renumber all Teachers sequentially: TGT001, TGT002, ...
WITH ordered_teachers AS (
  SELECT
    id,
    'TGT' || LPAD(ROW_NUMBER() OVER (ORDER BY created_at ASC NULLS LAST, id ASC)::text, 3, '0') AS new_code
  FROM public.teachers
)
UPDATE public.teachers t
SET teacher_id_code = o.new_code
FROM ordered_teachers o
WHERE t.id = o.id;

-- 5. Renumber all Courses sequentially: TGC001, TGC002, ...
WITH ordered_courses AS (
  SELECT
    id,
    'TGC' || LPAD(ROW_NUMBER() OVER (ORDER BY created_at ASC NULLS LAST, id ASC)::text, 3, '0') AS new_code
  FROM public.courses
)
UPDATE public.courses c
SET course_code = o.new_code
FROM ordered_courses o
WHERE c.id = o.id;

-- 6. Renumber all Schedules sequentially: TGSC001, TGSC002, ...
--    and cascade updated IDs only to tables/columns that actually exist.
CREATE TEMP TABLE _schedule_id_map ON COMMIT DROP AS
SELECT
  id AS old_id,
  'TGSC' || LPAD(ROW_NUMBER() OVER (ORDER BY created_at ASC NULLS LAST, id ASC)::text, 3, '0') AS new_id
FROM public.schedules;

-- Temporarily avoid PK collision if any TGSC* already exists
UPDATE public.schedules s
SET id = '__TMP__' || m.new_id
FROM _schedule_id_map m
WHERE s.id = m.old_id;

DO $$
DECLARE
  pair RECORD;
  col_type TEXT;
  fk RECORD;
BEGIN
  FOR pair IN
    SELECT * FROM (VALUES
      ('student_enrollments', 'slot_id'),
      ('teacher_slot_claims', 'slot_id'),
      ('attendance', 'slot_id'),
      ('attendance', 'schedule_id'),
      ('attendance_records', 'slot_id'),
      ('attendance_records', 'schedule_id'),
      ('session_qr_tokens', 'schedule_id'),
      ('waitlist_entries', 'slot_id')
    ) AS t(tbl, col)
  LOOP
    SELECT data_type INTO col_type
    FROM information_schema.columns
    WHERE table_schema = 'public'
      AND table_name = pair.tbl
      AND column_name = pair.col;

    IF col_type IS NOT NULL THEN
      IF col_type = 'uuid' THEN
        FOR fk IN
          SELECT tc.constraint_name
          FROM information_schema.table_constraints tc
          JOIN information_schema.key_column_usage kcu
            ON tc.constraint_name = kcu.constraint_name
           AND tc.table_schema = kcu.table_schema
          WHERE tc.constraint_type = 'FOREIGN KEY'
            AND tc.table_schema = 'public'
            AND tc.table_name = pair.tbl
            AND kcu.column_name = pair.col
        LOOP
          EXECUTE format('ALTER TABLE public.%I DROP CONSTRAINT IF EXISTS %I;', pair.tbl, fk.constraint_name);
        END LOOP;

        EXECUTE format('ALTER TABLE public.%I ALTER COLUMN %I TYPE TEXT USING %I::text;', pair.tbl, pair.col, pair.col);
      END IF;

      EXECUTE format(
        'UPDATE public.%I tgt SET %I = m.new_id FROM _schedule_id_map m WHERE tgt.%I::text = m.old_id::text;',
        pair.tbl, pair.col, pair.col
      );
    END IF;
  END LOOP;
END $$;

UPDATE public.schedules
SET id = SUBSTRING(id FROM 8)
WHERE id LIKE '__TMP__%';

COMMIT;
