-- ============================================================================
-- TOPGRADE CRM: TASK 19 PART B & C - SINGLE SOURCE OF TRUTH & DOMAIN EVENTS
-- Migration: 20261114_task19_single_source_of_truth.sql
-- ============================================================================

-- 1. EXTEND PUBLIC.SCHEDULES (Single source of truth for all schedule slots)
ALTER TABLE public.schedules
  ADD COLUMN IF NOT EXISTS duration_hours NUMERIC(4, 2) DEFAULT 1.0,
  ADD COLUMN IF NOT EXISTS grade_range TEXT DEFAULT 'All Grades',
  ADD COLUMN IF NOT EXISTS start_at TIMESTAMPTZ,
  ADD COLUMN IF NOT EXISTS end_at TIMESTAMPTZ,
  ADD COLUMN IF NOT EXISTS notes TEXT,
  ADD COLUMN IF NOT EXISTS status TEXT DEFAULT 'active';

-- Ensure status check constraint includes active, archived, cancelled
DO $$
BEGIN
  ALTER TABLE public.schedules DROP CONSTRAINT IF EXISTS check_schedules_status;
  ALTER TABLE public.schedules ADD CONSTRAINT check_schedules_status 
    CHECK (status IN ('active', 'archived', 'cancelled'));
EXCEPTION WHEN OTHERS THEN
  NULL;
END $$;

-- Migrate data from schedule_slots into schedules if schedule_slots exists
DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'schedule_slots') THEN
    INSERT INTO public.schedules (
      id, course_id, course_name, teacher_id, teacher_name, day_of_week,
      start_time, end_time, time_slot, room, location, max_capacity, is_active,
      open_for_teachers, duration_hours, grade_range, start_at, end_at, notes, status, created_at, updated_at
    )
    SELECT
      ss.id::TEXT,
      ss.course_id::TEXT,
      COALESCE(c.name, 'Course'),
      ss.teacher_id::TEXT,
      COALESCE(t.name, 'Unassigned Teacher'),
      TO_CHAR(ss.start_at AT TIME ZONE 'America/Chicago', 'FMDay'),
      TO_CHAR(ss.start_at AT TIME ZONE 'America/Chicago', 'HH12:MI AM'),
      TO_CHAR(ss.end_at AT TIME ZONE 'America/Chicago', 'HH12:MI AM'),
      TO_CHAR(ss.start_at AT TIME ZONE 'America/Chicago', 'HH12:MI AM') || ' - ' || TO_CHAR(ss.end_at AT TIME ZONE 'America/Chicago', 'HH12:MI AM'),
      COALESCE(ss.notes, 'Room 101'),
      'Main Academic Center',
      ss.max_students,
      (ss.status != 'cancelled' AND ss.status != 'archived'),
      (ss.teacher_id IS NULL),
      COALESCE(ss.duration_hours, 1.0),
      COALESCE(ss.grade, 'All Grades'),
      ss.start_at,
      ss.end_at,
      ss.notes,
      CASE WHEN ss.status = 'completed' THEN 'active' ELSE ss.status END,
      ss.created_at,
      ss.updated_at
    FROM public.schedule_slots ss
    LEFT JOIN public.courses c ON c.id::TEXT = ss.course_id::TEXT
    LEFT JOIN public.teachers t ON t.id::TEXT = ss.teacher_id::TEXT
    ON CONFLICT (id) DO UPDATE SET
      duration_hours = EXCLUDED.duration_hours,
      grade_range = EXCLUDED.grade_range,
      start_at = EXCLUDED.start_at,
      end_at = EXCLUDED.end_at,
      notes = EXCLUDED.notes,
      status = EXCLUDED.status;
  END IF;
END $$;

-- 2. EXTEND PUBLIC.STUDENT_ENROLLMENTS (Single source of truth for enrollments)
ALTER TABLE public.student_enrollments
  ADD COLUMN IF NOT EXISTS slot_id TEXT,
  ADD COLUMN IF NOT EXISTS paused_at TIMESTAMPTZ,
  ADD COLUMN IF NOT EXISTS end_date TIMESTAMPTZ;

-- Update status check constraint to include PAUSED_NO_HOURS and ENDED
DO $$
BEGIN
  ALTER TABLE public.student_enrollments DROP CONSTRAINT IF EXISTS student_enrollments_status_check;
  ALTER TABLE public.student_enrollments ADD CONSTRAINT student_enrollments_status_check
    CHECK (status IN ('ACTIVE', 'PAUSED_NO_HOURS', 'ENDED', 'EXPIRED', 'COMPLETED', 'CANCELLED'));
EXCEPTION WHEN OTHERS THEN
  NULL;
END $$;

-- Migrate bookings into student_enrollments if bookings exists
DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'bookings') THEN
    INSERT INTO public.student_enrollments (
      id, student_id, course_id, slot_id, plan, hours_total, status, created_at, updated_at
    )
    SELECT
      b.id::TEXT,
      b.student_id::TEXT,
      COALESCE(s.course_id, 'course-default'),
      b.slot_id::TEXT,
      'HOURS',
      b.tokens_reserved::INTEGER,
      CASE 
        WHEN b.status = 'booked' THEN 'ACTIVE'
        WHEN b.status = 'cancelled' THEN 'CANCELLED'
        WHEN b.status = 'completed' THEN 'COMPLETED'
        ELSE 'ACTIVE'
      END,
      b.created_at,
      COALESCE(b.cancelled_at, b.created_at)
    FROM public.bookings b
    LEFT JOIN public.schedules s ON s.id = b.slot_id::TEXT
    ON CONFLICT (id) DO NOTHING;
  END IF;
END $$;

-- Migrate schedule_students into student_enrollments if schedule_students exists
DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'schedule_students') THEN
    INSERT INTO public.student_enrollments (
      id, student_id, course_id, slot_id, plan, hours_total, status, created_at, updated_at
    )
    SELECT
      ss.id,
      ss.student_id,
      COALESCE(s.course_id, 'course-default'),
      ss.schedule_id,
      'HOURS',
      COALESCE(s.duration_hours::INTEGER, 1),
      'ACTIVE',
      ss.created_at,
      ss.created_at
    FROM public.schedule_students ss
    LEFT JOIN public.schedules s ON s.id = ss.schedule_id
    ON CONFLICT (id) DO NOTHING;
  END IF;
END $$;

-- 3. DROP DUPLICATE / DEPRECATED TABLES
DROP TABLE IF EXISTS public.schedule_slots CASCADE;
DROP TABLE IF EXISTS public.schedule_students CASCADE;
DROP TABLE IF EXISTS public.bookings CASCADE;
DROP TABLE IF EXISTS public.hour_wallets CASCADE;
DROP TABLE IF EXISTS public.hour_ledger CASCADE;

-- 4. ENSURE TOKEN_WALLETS AND TOKEN_LEDGER ARE CANONICAL
CREATE TABLE IF NOT EXISTS public.token_wallets (
  student_id UUID NOT NULL REFERENCES public.students(id) ON DELETE CASCADE,
  course_id TEXT NOT NULL,
  balance INTEGER NOT NULL DEFAULT 0,
  total_purchased INTEGER NOT NULL DEFAULT 0,
  total_used INTEGER NOT NULL DEFAULT 0,
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  PRIMARY KEY (student_id, course_id)
);

CREATE TABLE IF NOT EXISTS public.token_ledger (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  student_id UUID NOT NULL REFERENCES public.students(id) ON DELETE CASCADE,
  course_id TEXT NOT NULL,
  delta INTEGER NOT NULL,
  reason TEXT NOT NULL CHECK (reason IN ('PURCHASE','MANUAL_CREDIT','CLASS_ATTENDED','ADJUSTMENT','REFUND')),
  ref TEXT,
  note TEXT,
  created_by TEXT,
  balance_after INTEGER,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE UNIQUE INDEX IF NOT EXISTS token_ledger_once ON public.token_ledger (reason, ref) WHERE ref IS NOT NULL;
CREATE INDEX IF NOT EXISTS token_ledger_student_idx ON public.token_ledger (student_id, created_at DESC);

-- 5. DOMAIN EVENTS OUTBOX TABLE (PART C)
CREATE TABLE IF NOT EXISTS public.domain_events (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  type TEXT NOT NULL,
  entity TEXT NOT NULL,
  entity_id TEXT NOT NULL,
  payload JSONB NOT NULL DEFAULT '{}'::jsonb,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  processed_at TIMESTAMPTZ,
  attempts INTEGER NOT NULL DEFAULT 0,
  last_error TEXT
);
CREATE INDEX IF NOT EXISTS idx_domain_events_unprocessed ON public.domain_events (processed_at) WHERE processed_at IS NULL;
CREATE INDEX IF NOT EXISTS idx_domain_events_type ON public.domain_events (type, created_at DESC);

-- 6. LEDGER RECONCILIATION FUNCTION
CREATE OR REPLACE FUNCTION public.reconcile_token_ledger()
RETURNS TABLE (
  student_id UUID,
  course_id TEXT,
  wallet_balance INTEGER,
  ledger_sum BIGINT,
  is_reconciled BOOLEAN,
  is_orphan BOOLEAN
) LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
BEGIN
  RETURN QUERY
  WITH ledger_totals AS (
    SELECT 
      tl.student_id AS l_student_id,
      tl.course_id AS l_course_id,
      COALESCE(SUM(tl.delta), 0) AS total_delta,
      NOT EXISTS (SELECT 1 FROM public.students st WHERE st.id = tl.student_id) AS orphan_student
    FROM public.token_ledger tl
    GROUP BY tl.student_id, tl.course_id
  )
  SELECT
    COALESCE(w.student_id, lt.l_student_id) AS student_id,
    COALESCE(w.course_id, lt.l_course_id) AS course_id,
    COALESCE(w.balance, 0)::INTEGER AS wallet_balance,
    COALESCE(lt.total_delta, 0)::BIGINT AS ledger_sum,
    (COALESCE(w.balance, 0)::BIGINT = COALESCE(lt.total_delta, 0)::BIGINT) AS is_reconciled,
    COALESCE(lt.orphan_student, FALSE) AS is_orphan
  FROM public.token_wallets w
  FULL OUTER JOIN ledger_totals lt
    ON lt.l_student_id = w.student_id AND lt.l_course_id = w.course_id;
END;
$$;

-- 7. SUPABASE REALTIME PUBLICATION (PART D)
-- Add canonical tables to supabase_realtime
DO $$
BEGIN
  BEGIN
    ALTER PUBLICATION supabase_realtime ADD TABLE public.schedules;
  EXCEPTION WHEN OTHERS THEN NULL; END;
  BEGIN
    ALTER PUBLICATION supabase_realtime ADD TABLE public.student_enrollments;
  EXCEPTION WHEN OTHERS THEN NULL; END;
  BEGIN
    ALTER PUBLICATION supabase_realtime ADD TABLE public.attendance;
  EXCEPTION WHEN OTHERS THEN NULL; END;
  BEGIN
    ALTER PUBLICATION supabase_realtime ADD TABLE public.token_wallets;
  EXCEPTION WHEN OTHERS THEN NULL; END;
  BEGIN
    ALTER PUBLICATION supabase_realtime ADD TABLE public.token_ledger;
  EXCEPTION WHEN OTHERS THEN NULL; END;
  BEGIN
    ALTER PUBLICATION supabase_realtime ADD TABLE public.courses;
  EXCEPTION WHEN OTHERS THEN NULL; END;
  BEGIN
    ALTER PUBLICATION supabase_realtime ADD TABLE public.students;
  EXCEPTION WHEN OTHERS THEN NULL; END;
  BEGIN
    ALTER PUBLICATION supabase_realtime ADD TABLE public.teachers;
  EXCEPTION WHEN OTHERS THEN NULL; END;
  BEGIN
    ALTER PUBLICATION supabase_realtime ADD TABLE public.announcements;
  EXCEPTION WHEN OTHERS THEN NULL; END;
  BEGIN
    ALTER PUBLICATION supabase_realtime ADD TABLE public.domain_events;
  EXCEPTION WHEN OTHERS THEN NULL; END;
END $$;

