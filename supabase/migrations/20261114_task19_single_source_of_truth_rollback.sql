-- ============================================================================
-- TOPGRADE CRM: TASK 19 PART B & C - ROLLBACK SCRIPT
-- Migration: 20261114_task19_single_source_of_truth_rollback.sql
-- ============================================================================

-- Recreate schedule_slots if rolled back
CREATE TABLE IF NOT EXISTS public.schedule_slots (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  course_id UUID NOT NULL,
  teacher_id UUID,
  grade TEXT NOT NULL DEFAULT 'All Grades',
  start_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  end_at TIMESTAMPTZ NOT NULL DEFAULT (now() + INTERVAL '1 hour'),
  duration_hours NUMERIC(4, 2) NOT NULL DEFAULT 1.0,
  max_students INTEGER NOT NULL DEFAULT 15,
  status TEXT NOT NULL DEFAULT 'open',
  notes TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Recreate bookings if rolled back
CREATE TABLE IF NOT EXISTS public.bookings (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  slot_id UUID NOT NULL,
  student_id UUID NOT NULL,
  status TEXT NOT NULL DEFAULT 'booked',
  tokens_reserved NUMERIC(4, 2) NOT NULL DEFAULT 1.0,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  cancelled_at TIMESTAMPTZ
);

-- Recreate schedule_students if rolled back
CREATE TABLE IF NOT EXISTS public.schedule_students (
  id TEXT PRIMARY KEY,
  schedule_id TEXT NOT NULL,
  student_id TEXT NOT NULL,
  student_name TEXT NOT NULL,
  student_code TEXT,
  created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);

-- Drop domain_events if rolled back
DROP TABLE IF EXISTS public.domain_events CASCADE;
DROP FUNCTION IF EXISTS public.reconcile_token_ledger() CASCADE;
