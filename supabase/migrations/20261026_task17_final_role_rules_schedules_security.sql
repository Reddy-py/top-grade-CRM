-- ============================================================================
-- Migration: 20261026_task17_final_role_rules_schedules_security.sql
-- Description: TASK 17 Database Guarantees:
--   1. Unique lowercase email index on public.profiles.
--   2. student_parents table with unique (student_id, parent_id) and unique (student_id, lower(parent_email)).
--   3. Unique student per parent per name and date of birth trigger.
--   4. institute_settings self_enrollment_mode column (OFF, REQUEST, AUTO).
--   5. Fee structure columns on public.courses & fee_structure_audit table.
--   6. user_sessions table for server-side idle tracking.
-- Safe to run multiple times (idempotent).
-- ============================================================================

-- 1. Unique index on lower(email) in profiles
CREATE UNIQUE INDEX IF NOT EXISTS idx_profiles_lower_email ON public.profiles(LOWER(email));

-- 2. student_parents table for parent-student link guarantees
CREATE TABLE IF NOT EXISTS public.student_parents (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    student_id UUID NOT NULL REFERENCES public.students(id) ON DELETE CASCADE,
    parent_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
    parent_email TEXT NOT NULL,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    CONSTRAINT uq_student_parent UNIQUE(student_id, parent_id)
);

CREATE UNIQUE INDEX IF NOT EXISTS idx_student_parents_student_email 
    ON public.student_parents(student_id, LOWER(parent_email));

CREATE INDEX IF NOT EXISTS idx_student_parents_parent_email 
    ON public.student_parents(LOWER(parent_email));

-- 3. Trigger: Unique student per parent per name and date of birth when present
CREATE OR REPLACE FUNCTION public.check_unique_student_per_parent()
RETURNS TRIGGER AS $$
DECLARE
  dup_count INT;
  st_name TEXT;
  st_dob DATE;
BEGIN
  SELECT name, dob INTO st_name, st_dob FROM public.students WHERE id = NEW.student_id;
  IF st_dob IS NOT NULL AND st_name IS NOT NULL THEN
    SELECT COUNT(*) INTO dup_count
    FROM public.student_parents sp
    JOIN public.students s ON s.id = sp.student_id
    WHERE LOWER(sp.parent_email) = LOWER(NEW.parent_email)
      AND sp.student_id != NEW.student_id
      AND LOWER(s.name) = LOWER(st_name)
      AND s.dob = st_dob;

    IF dup_count > 0 THEN
      RAISE EXCEPTION 'Student with name "%" and date of birth "%" is already linked to parent "%".',
        st_name, st_dob, NEW.parent_email;
    END IF;
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_check_unique_student_per_parent ON public.student_parents;
CREATE TRIGGER trg_check_unique_student_per_parent
  BEFORE INSERT OR UPDATE ON public.student_parents
  FOR EACH ROW EXECUTE FUNCTION public.check_unique_student_per_parent();

-- 4. Enable RLS on student_parents
ALTER TABLE public.student_parents ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "admin_manage_student_parents" ON public.student_parents;
CREATE POLICY "admin_manage_student_parents" ON public.student_parents
    FOR ALL
    USING (public.get_current_user_role() = 'ADMIN');

DROP POLICY IF EXISTS "parents_view_own_student_parents" ON public.student_parents;
CREATE POLICY "parents_view_own_student_parents" ON public.student_parents
    FOR SELECT
    USING (
        public.get_current_user_role() = 'PARENT' 
        AND (
            LOWER(parent_email) = LOWER(auth.jwt() ->> 'email')
            OR parent_id = auth.uid()
        )
    );

-- 5. Add self_enrollment_mode column to institute_settings
ALTER TABLE public.institute_settings 
    ADD COLUMN IF NOT EXISTS self_enrollment_mode TEXT NOT NULL DEFAULT 'REQUEST';

DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint WHERE conname = 'chk_institute_settings_self_enrollment_mode'
    ) THEN
        ALTER TABLE public.institute_settings 
            ADD CONSTRAINT chk_institute_settings_self_enrollment_mode 
            CHECK (self_enrollment_mode IN ('OFF', 'REQUEST', 'AUTO'));
    END IF;
END $$;

-- 6. Fee structure columns on public.courses & fee_structure_audit table
ALTER TABLE public.courses ADD COLUMN IF NOT EXISTS hourly_rate NUMERIC DEFAULT 50;
ALTER TABLE public.courses ADD COLUMN IF NOT EXISTS package_hours NUMERIC DEFAULT 20;
ALTER TABLE public.courses ADD COLUMN IF NOT EXISTS package_price NUMERIC DEFAULT 900;
ALTER TABLE public.courses ADD COLUMN IF NOT EXISTS duration TEXT DEFAULT '3 Months';

CREATE TABLE IF NOT EXISTS public.fee_structure_audit (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    course_id UUID REFERENCES public.courses(id) ON DELETE CASCADE,
    course_name TEXT NOT NULL,
    changed_by UUID REFERENCES auth.users(id),
    changed_by_name TEXT,
    old_values JSONB NOT NULL,
    new_values JSONB NOT NULL,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

ALTER TABLE public.fee_structure_audit ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "admin_manage_fee_audit" ON public.fee_structure_audit;
CREATE POLICY "admin_manage_fee_audit" ON public.fee_structure_audit
    FOR ALL
    USING (public.get_current_user_role() = 'ADMIN');

-- 7. Table user_sessions for server-side idle and token activity tracking
CREATE TABLE IF NOT EXISTS public.user_sessions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    last_activity TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    revoked BOOLEAN NOT NULL DEFAULT FALSE
);

CREATE INDEX IF NOT EXISTS idx_user_sessions_user_activity 
    ON public.user_sessions(user_id, last_activity);

ALTER TABLE public.user_sessions ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "admin_manage_user_sessions" ON public.user_sessions;
CREATE POLICY "admin_manage_user_sessions" ON public.user_sessions
    FOR ALL
    USING (public.get_current_user_role() = 'ADMIN');

DROP POLICY IF EXISTS "users_view_own_sessions" ON public.user_sessions;
CREATE POLICY "users_view_own_sessions" ON public.user_sessions
    FOR SELECT
    USING (user_id = auth.uid());

-- 8. Course class length (1 or 2 hours) and schedule duration_hours
ALTER TABLE public.courses ADD COLUMN IF NOT EXISTS class_length INT DEFAULT 1;

DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'chk_courses_class_length') THEN
        ALTER TABLE public.courses ADD CONSTRAINT chk_courses_class_length CHECK (class_length IN (1, 2));
    END IF;
END $$;

ALTER TABLE public.schedules ADD COLUMN IF NOT EXISTS duration_hours INT DEFAULT 1;

DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'chk_schedules_duration_hours') THEN
        ALTER TABLE public.schedules ADD CONSTRAINT chk_schedules_duration_hours CHECK (duration_hours IN (1, 2));
    END IF;
END $$;

CREATE OR REPLACE FUNCTION public.sync_schedule_minutes() RETURNS TRIGGER AS $$
BEGIN
  IF NEW.duration_hours IS NULL OR NEW.duration_hours NOT IN (1, 2) THEN
    NEW.duration_hours := 1;
  END IF;
  IF NEW.start_minute IS NULL OR NEW.start_minute = 0 THEN
    NEW.start_minute := public.time_to_minutes(NEW.start_time);
  END IF;
  IF NEW.end_minute IS NULL OR NEW.end_minute = 0 OR NEW.end_minute <= NEW.start_minute THEN
    NEW.end_minute := public.time_to_minutes(NEW.end_time);
    IF NEW.end_minute <= NEW.start_minute THEN
      NEW.end_minute := NEW.start_minute + (NEW.duration_hours * 60);
    END IF;
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

