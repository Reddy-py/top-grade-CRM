-- ============================================================================
-- Migration: 20261017_hour_based_classes_and_enrollments.sql
-- Description: Hour-based classes, course package fields, and student_enrollments.
--   1 token = 1 hour = 1 class.
-- Safe to run multiple times (idempotent).
-- ============================================================================

-- 1. Add course package and hourly rate columns to public.courses with DEFAULT NULL
ALTER TABLE public.courses ADD COLUMN IF NOT EXISTS duration_months INT DEFAULT NULL;
ALTER TABLE public.courses ADD COLUMN IF NOT EXISTS package_hours INT DEFAULT NULL;
ALTER TABLE public.courses ADD COLUMN IF NOT EXISTS package_price NUMERIC(10,2) DEFAULT NULL;
ALTER TABLE public.courses ADD COLUMN IF NOT EXISTS hourly_rate NUMERIC(10,2) DEFAULT NULL;

-- Ensure defaults are NULL even if previously created with 6 or 20
ALTER TABLE public.courses ALTER COLUMN duration_months SET DEFAULT NULL;
ALTER TABLE public.courses ALTER COLUMN package_hours SET DEFAULT NULL;
ALTER TABLE public.courses ALTER COLUMN package_price SET DEFAULT NULL;
ALTER TABLE public.courses ALTER COLUMN hourly_rate SET DEFAULT NULL;

-- 2. Populate course package columns from existing fee and course_material metadata
DO $$
DECLARE
  r RECORD;
  mat JSONB;
  dur_num INT;
  h_rate NUMERIC(10,2);
  p_hours INT;
BEGIN
  FOR r IN SELECT id, fee, duration, course_material FROM public.courses LOOP
    mat := '{}'::jsonb;
    IF r.course_material IS NOT NULL AND r.course_material <> '' THEN
      BEGIN
        mat := r.course_material::jsonb;
      EXCEPTION WHEN OTHERS THEN
        mat := '{}'::jsonb;
      END;
    END IF;

    -- Extract duration months ONLY if explicitly provided in course_material or duration text
    dur_num := NULL;
    IF mat->>'duration_months' IS NOT NULL AND (mat->>'duration_months') ~ '^[0-9]+$' THEN
      dur_num := (mat->>'duration_months')::INT;
    ELSIF r.duration ILIKE '%year%' THEN
      dur_num := 12;
    ELSIF r.duration ~ '[0-9]+' THEN
      dur_num := (regexp_match(r.duration, '([0-9]+)'))[1]::INT;
    END IF;

    -- Extract hourly rate from course_material
    h_rate := NULL;
    IF mat->>'hourly_rate' IS NOT NULL AND (mat->>'hourly_rate') ~ '^[0-9]+(\.[0-9]+)?$' THEN
      h_rate := (mat->>'hourly_rate')::NUMERIC(10,2);
    END IF;

    -- Extract package hours ONLY if explicitly in course_material
    p_hours := NULL;
    IF mat->>'package_hours' IS NOT NULL AND (mat->>'package_hours') ~ '^[0-9]+$' THEN
      p_hours := (mat->>'package_hours')::INT;
    END IF;

    UPDATE public.courses
    SET
      duration_months = dur_num,
      package_hours = p_hours,
      package_price = COALESCE(courses.package_price, NULLIF(r.fee, 0)),
      hourly_rate = COALESCE(courses.hourly_rate, h_rate)
    WHERE id = r.id;
  END LOOP;
END $$;

-- 3. Create student_enrollments table
CREATE TABLE IF NOT EXISTS public.student_enrollments (
    id TEXT PRIMARY KEY DEFAULT ('enr-' || floor(extract(epoch from now()) * 1000)::bigint || '-' || substr(md5(random()::text), 1, 6)),
    student_id TEXT NOT NULL,
    course_id TEXT NOT NULL,
    plan TEXT NOT NULL CHECK (plan IN ('PACKAGE', 'HOURS')),
    hours_total INT NOT NULL DEFAULT 0,
    quoted_amount NUMERIC(10,2) DEFAULT NULL,
    currency TEXT NOT NULL DEFAULT 'usd',
    starts_on DATE NOT NULL DEFAULT CURRENT_DATE,
    expires_on DATE DEFAULT NULL,
    status TEXT NOT NULL DEFAULT 'ACTIVE' CHECK (status IN ('ACTIVE', 'EXPIRED', 'COMPLETED', 'CANCELLED')),
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Indices for student_enrollments
CREATE INDEX IF NOT EXISTS idx_student_enrollments_student ON public.student_enrollments(student_id);
CREATE INDEX IF NOT EXISTS idx_student_enrollments_course ON public.student_enrollments(course_id);
CREATE INDEX IF NOT EXISTS idx_student_enrollments_status ON public.student_enrollments(status);
CREATE INDEX IF NOT EXISTS idx_student_enrollments_plan ON public.student_enrollments(plan);
CREATE INDEX IF NOT EXISTS idx_student_enrollments_expiry ON public.student_enrollments(expires_on) WHERE status = 'ACTIVE';

-- 4. Enable Row Level Security
ALTER TABLE public.student_enrollments ENABLE ROW LEVEL SECURITY;

-- 5. RLS Policies for student_enrollments
-- Admin: all permissions (SELECT, INSERT, UPDATE, DELETE)
DROP POLICY IF EXISTS "admin_all_student_enrollments" ON public.student_enrollments;
CREATE POLICY "admin_all_student_enrollments" ON public.student_enrollments
    FOR ALL USING (public.get_current_user_role() = 'ADMIN');

-- Student: view own enrollments
DROP POLICY IF EXISTS "students_view_own_student_enrollments" ON public.student_enrollments;
CREATE POLICY "students_view_own_student_enrollments" ON public.student_enrollments
    FOR SELECT USING (
        public.get_current_user_role() = 'STUDENT'
        AND EXISTS (
            SELECT 1 FROM public.students s
            WHERE (s.user_id = auth.uid() OR lower(s.email) = lower(auth.jwt() ->> 'email'))
              AND (student_enrollments.student_id = s.id::text OR student_enrollments.student_id = s.student_id_code)
        )
    );

-- Parent: view children's enrollments
DROP POLICY IF EXISTS "parents_view_own_student_enrollments" ON public.student_enrollments;
CREATE POLICY "parents_view_own_student_enrollments" ON public.student_enrollments
    FOR SELECT USING (
        public.get_current_user_role() = 'PARENT'
        AND EXISTS (
            SELECT 1 FROM public.students s
            WHERE lower(auth.jwt() ->> 'email') = ANY (s.parent_emails)
              AND (student_enrollments.student_id = s.id::text OR student_enrollments.student_id = s.student_id_code)
        )
    );

-- 6. Migrate existing student course mappings into student_enrollments
-- Existing mappings become enrollments with plan HOURS and no quote.
DO $$
BEGIN
  -- Insert from students.program matching courses.name or courses.course_code
  INSERT INTO public.student_enrollments (
    student_id,
    course_id,
    plan,
    hours_total,
    quoted_amount,
    currency,
    starts_on,
    expires_on,
    status
  )
  SELECT DISTINCT
    s.id::text AS student_id,
    c.id::text AS course_id,
    'HOURS' AS plan,
    COALESCE(s.purchased_hours, 0) AS hours_total,
    NULL::NUMERIC(10,2) AS quoted_amount,
    'usd' AS currency,
    COALESCE(s.created_at::date, CURRENT_DATE) AS starts_on,
    NULL::DATE AS expires_on,
    'ACTIVE' AS status
  FROM public.students s
  JOIN public.courses c ON (
    lower(trim(c.name)) = lower(trim(s.program))
    OR (c.course_code IS NOT NULL AND lower(trim(c.course_code)) = lower(trim(s.program)))
  )
  WHERE s.program IS NOT NULL AND trim(s.program) <> ''
    AND NOT EXISTS (
      SELECT 1 FROM public.student_enrollments se
      WHERE se.student_id = s.id::text AND se.course_id = c.id::text
    );

  -- Insert from schedule_students joining schedules to courses
  INSERT INTO public.student_enrollments (
    student_id,
    course_id,
    plan,
    hours_total,
    quoted_amount,
    currency,
    starts_on,
    expires_on,
    status
  )
  SELECT DISTINCT
    ss.student_id AS student_id,
    sch.course_id AS course_id,
    'HOURS' AS plan,
    0 AS hours_total,
    NULL::NUMERIC(10,2) AS quoted_amount,
    'usd' AS currency,
    CURRENT_DATE AS starts_on,
    NULL::DATE AS expires_on,
    'ACTIVE' AS status
  FROM public.schedule_students ss
  JOIN public.schedules sch ON sch.id = ss.schedule_id
  WHERE sch.course_id IS NOT NULL AND sch.course_id <> ''
    AND NOT EXISTS (
      SELECT 1 FROM public.student_enrollments se
      WHERE se.student_id = ss.student_id AND se.course_id = sch.course_id
    );
END $$;
