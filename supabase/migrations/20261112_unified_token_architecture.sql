-- ============================================================================
-- TOPGRADE CRM: UNIFIED TOKEN & COURSE-WISE BOOKING ARCHITECTURE
-- Migration: 20261112_unified_token_architecture.sql
-- ============================================================================

-- Enable btree_gist extension for teacher schedule collision exclusion constraint
CREATE EXTENSION IF NOT EXISTS btree_gist;

-- 1. INSTITUTE SETTINGS TABLE (Single Source of Truth)
CREATE TABLE IF NOT EXISTS public.institute_settings (
  id TEXT PRIMARY KEY DEFAULT 'default',
  institute_name TEXT NOT NULL DEFAULT 'TopGrade Learning',
  institute_timezone TEXT NOT NULL DEFAULT 'America/Chicago',
  payments_enabled BOOLEAN NOT NULL DEFAULT false,
  cancellation_cutoff_hours INTEGER NOT NULL DEFAULT 24,
  low_balance_threshold_hours INTEGER NOT NULL DEFAULT 5,
  attendance_marking_window_days INTEGER NOT NULL DEFAULT 7,
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

INSERT INTO public.institute_settings (id, institute_name, institute_timezone, payments_enabled)
VALUES ('default', 'TopGrade Learning', 'America/Chicago', false)
ON CONFLICT (id) DO UPDATE SET
  institute_timezone = 'America/Chicago',
  payments_enabled = false;

-- 2. ENHANCE STUDENTS & TEACHERS (Preserve all existing data)
ALTER TABLE public.students 
  ADD COLUMN IF NOT EXISTS grade TEXT,
  ADD COLUMN IF NOT EXISTS parent_id UUID REFERENCES public.profiles(id) ON DELETE SET NULL;

-- Populate grade from existing nationality string (e.g. 'Grade: Grade 11' -> 'Grade 11')
UPDATE public.students 
SET grade = TRIM(REPLACE(nationality, 'Grade:', ''))
WHERE (grade IS NULL OR grade = '') AND nationality ILIKE '%Grade%';

ALTER TABLE public.teachers
  ADD COLUMN IF NOT EXISTS subjects TEXT[] DEFAULT '{}';

-- 3. PARENTS TABLE (Linked to profiles and students)
CREATE TABLE IF NOT EXISTS public.parents (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  profile_id UUID REFERENCES public.profiles(id) ON DELETE SET NULL,
  name TEXT NOT NULL,
  email TEXT NOT NULL,
  phone TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE UNIQUE INDEX IF NOT EXISTS idx_parents_email ON public.parents(LOWER(email));

-- 4. ENHANCE COURSES & CREATE COURSE PACKAGES
ALTER TABLE public.courses
  ADD COLUMN IF NOT EXISTS title TEXT,
  ADD COLUMN IF NOT EXISTS duration_info TEXT,
  ADD COLUMN IF NOT EXISTS grade_level TEXT;

UPDATE public.courses
SET title = name WHERE title IS NULL;

CREATE TABLE IF NOT EXISTS public.course_packages (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  course_id UUID NOT NULL REFERENCES public.courses(id) ON DELETE CASCADE,
  name TEXT NOT NULL,
  hours NUMERIC(6, 2) NOT NULL CHECK (hours > 0),
  validity_days INTEGER,
  price NUMERIC(10, 2), -- Display-only while payments are on hold
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- 5. SCHEDULE SLOTS (With Teacher Overlap Exclusion Constraint)
CREATE TABLE IF NOT EXISTS public.schedule_slots (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  course_id UUID NOT NULL REFERENCES public.courses(id) ON DELETE RESTRICT,
  teacher_id UUID NOT NULL REFERENCES public.teachers(id) ON DELETE RESTRICT,
  grade TEXT NOT NULL,
  start_at TIMESTAMPTZ NOT NULL,
  end_at TIMESTAMPTZ NOT NULL,
  duration_hours NUMERIC(4, 2) NOT NULL CHECK (duration_hours > 0),
  max_students INTEGER NOT NULL DEFAULT 15 CHECK (max_students >= 1),
  status TEXT NOT NULL DEFAULT 'open' CHECK (status IN ('open', 'full', 'completed', 'cancelled')),
  notes TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  CONSTRAINT check_slot_times CHECK (end_at > start_at),
  -- Exclusion constraint: Teacher cannot have two overlapping non-cancelled slots
  CONSTRAINT no_teacher_slot_overlap EXCLUDE USING gist (
    teacher_id WITH =,
    tstzrange(start_at, end_at, '[)') WITH &&
  ) WHERE (status != 'cancelled')
);

-- 6. BOOKINGS TABLE
CREATE TABLE IF NOT EXISTS public.bookings (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  slot_id UUID NOT NULL REFERENCES public.schedule_slots(id) ON DELETE CASCADE,
  student_id UUID NOT NULL REFERENCES public.students(id) ON DELETE CASCADE,
  status TEXT NOT NULL DEFAULT 'booked' CHECK (status IN ('booked', 'cancelled', 'completed', 'no_show')),
  tokens_reserved NUMERIC(4, 2) NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  cancelled_at TIMESTAMPTZ,
  CONSTRAINT unique_student_slot_active UNIQUE (slot_id, student_id)
);

-- 7. ATTENDANCE (Auto-created from bookings)
-- Archive old attendance data first
CREATE TABLE IF NOT EXISTS public.attendance_legacy_archive AS 
SELECT * FROM public.attendance;

-- Recreate attendance table
DROP TABLE IF EXISTS public.attendance CASCADE;
CREATE TABLE public.attendance (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  slot_id UUID NOT NULL REFERENCES public.schedule_slots(id) ON DELETE CASCADE,
  student_id UUID NOT NULL REFERENCES public.students(id) ON DELETE CASCADE,
  booking_id UUID NOT NULL REFERENCES public.bookings(id) ON DELETE CASCADE,
  status TEXT NOT NULL DEFAULT 'scheduled' CHECK (status IN ('scheduled', 'present', 'absent', 'late', 'excused', 'cancelled')),
  marked_by UUID REFERENCES public.profiles(id) ON DELETE SET NULL,
  marked_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  CONSTRAINT unique_attendance_booking UNIQUE (booking_id)
);

-- 8. APPEND-ONLY TOKEN LEDGER (Strict Accounting)
-- Archive old token tables
CREATE TABLE IF NOT EXISTS public.token_ledger_legacy_archive AS 
SELECT * FROM public.token_ledger;

CREATE TABLE IF NOT EXISTS public.token_wallets_legacy_archive AS 
SELECT * FROM public.token_wallets;

DROP TABLE IF EXISTS public.token_ledger CASCADE;
DROP TABLE IF EXISTS public.token_wallets CASCADE;

CREATE TABLE public.token_ledger (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  student_id UUID NOT NULL REFERENCES public.students(id) ON DELETE CASCADE,
  course_id UUID NOT NULL REFERENCES public.courses(id) ON DELETE CASCADE,
  hours NUMERIC(6, 2) NOT NULL,
  type TEXT NOT NULL CHECK (type IN ('grant', 'reserve', 'consume', 'release', 'refund', 'adjustment', 'expire')),
  ref_booking_id UUID REFERENCES public.bookings(id) ON DELETE SET NULL,
  ref_package_id UUID REFERENCES public.course_packages(id) ON DELETE SET NULL,
  expires_at TIMESTAMPTZ,
  note TEXT,
  created_by TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX idx_token_ledger_student_course ON public.token_ledger(student_id, course_id);
CREATE INDEX idx_token_ledger_expiry ON public.token_ledger(expires_at) WHERE expires_at IS NOT NULL;

-- 9. DYNAMIC TOKEN BALANCE VIEW & RPC FUNCTIONS
CREATE OR REPLACE VIEW public.student_course_balance AS
SELECT 
  student_id,
  course_id,
  COALESCE(SUM(hours), 0)::NUMERIC(6, 2) AS available_tokens
FROM public.token_ledger
WHERE (expires_at IS NULL OR expires_at > now())
GROUP BY student_id, course_id;

CREATE OR REPLACE FUNCTION public.get_available_tokens(p_student_id UUID, p_course_id UUID)
RETURNS NUMERIC AS $$
  SELECT COALESCE(SUM(hours), 0)::NUMERIC(6, 2)
  FROM public.token_ledger
  WHERE student_id = p_student_id 
    AND course_id = p_course_id
    AND (expires_at IS NULL OR expires_at > now());
$$ LANGUAGE sql STABLE;

CREATE OR REPLACE FUNCTION public.get_student_balance_summary(p_student_id UUID)
RETURNS TABLE (
  course_id UUID,
  course_name TEXT,
  available_tokens NUMERIC
) AS $$
  SELECT 
    c.id AS course_id,
    c.name AS course_name,
    COALESCE(b.available_tokens, 0) AS available_tokens
  FROM public.courses c
  LEFT JOIN public.student_course_balance b ON b.course_id = c.id AND b.student_id = p_student_id
  WHERE c.status = 'Active';
$$ LANGUAGE sql STABLE;

-- 10. TRANSACTIONAL BOOKING FUNCTION (book_slot)
CREATE OR REPLACE FUNCTION public.book_slot(p_student_id UUID, p_slot_id UUID)
RETURNS TABLE (success BOOLEAN, booking_id UUID, error_message TEXT)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE
  v_slot RECORD;
  v_student RECORD;
  v_balance NUMERIC;
  v_booked_count INTEGER;
  v_new_booking_id UUID;
  v_conflict_count INTEGER;
BEGIN
  -- 1. Lock slot row for concurrency safety
  SELECT * INTO v_slot FROM public.schedule_slots WHERE id = p_slot_id FOR UPDATE;
  IF NOT FOUND THEN
    RETURN QUERY SELECT false, NULL::UUID, 'Class schedule slot not found.';
    RETURN;
  END IF;

  IF v_slot.status != 'open' THEN
    RETURN QUERY SELECT false, NULL::UUID, 'This schedule slot is not open for booking.';
    RETURN;
  END IF;

  IF v_slot.start_at <= now() THEN
    RETURN QUERY SELECT false, NULL::UUID, 'Cannot book a class that has already started or passed.';
    RETURN;
  END IF;

  -- 2. Verify student is active
  SELECT * INTO v_student FROM public.students WHERE id = p_student_id;
  IF NOT FOUND OR v_student.status != 'ACTIVE' THEN
    RETURN QUERY SELECT false, NULL::UUID, 'Student profile is not active.';
    RETURN;
  END IF;

  -- 3. Check for overlapping student bookings
  SELECT COUNT(*) INTO v_conflict_count
  FROM public.bookings b
  JOIN public.schedule_slots s ON b.slot_id = s.id
  WHERE b.student_id = p_student_id
    AND b.status = 'booked'
    AND s.status != 'cancelled'
    AND tstzrange(s.start_at, s.end_at, '[)') && tstzrange(v_slot.start_at, v_slot.end_at, '[)');

  IF v_conflict_count > 0 THEN
    RETURN QUERY SELECT false, NULL::UUID, 'You already have another class booked at this time.';
    RETURN;
  END IF;

  -- 4. Check available token balance for this specific course
  v_balance := public.get_available_tokens(p_student_id, v_slot.course_id);
  IF v_balance < v_slot.duration_hours THEN
    RETURN QUERY SELECT false, NULL::UUID, 'No tokens for this course. Ask admin to add hours.';
    RETURN;
  END IF;

  -- 5. Check slot capacity
  SELECT COUNT(*) INTO v_booked_count
  FROM public.bookings
  WHERE slot_id = p_slot_id AND status = 'booked';

  IF v_booked_count >= v_slot.max_students THEN
    UPDATE public.schedule_slots SET status = 'full' WHERE id = p_slot_id;
    RETURN QUERY SELECT false, NULL::UUID, 'This class slot is already full.';
    RETURN;
  END IF;

  -- 6. Insert Booking
  INSERT INTO public.bookings (slot_id, student_id, status, tokens_reserved)
  VALUES (p_slot_id, p_student_id, 'booked', v_slot.duration_hours)
  RETURNING id INTO v_new_booking_id;

  -- 7. Insert Token Ledger Reservation (-duration_hours)
  INSERT INTO public.token_ledger (student_id, course_id, hours, type, ref_booking_id, note)
  VALUES (p_student_id, v_slot.course_id, -v_slot.duration_hours, 'reserve', v_new_booking_id, 'Tokens reserved for class booking');

  -- 8. Automatically Insert Attendance Row ('scheduled')
  INSERT INTO public.attendance (slot_id, student_id, booking_id, status)
  VALUES (p_slot_id, p_student_id, v_new_booking_id, 'scheduled');

  -- 9. Update slot status to 'full' if capacity reached
  IF v_booked_count + 1 >= v_slot.max_students THEN
    UPDATE public.schedule_slots SET status = 'full' WHERE id = p_slot_id;
  END IF;

  RETURN QUERY SELECT true, v_new_booking_id, NULL::TEXT;
END;
$$;

-- 11. ANNOUNCEMENTS & DELIVERIES
CREATE TABLE IF NOT EXISTS public.announcements (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  title TEXT NOT NULL,
  body TEXT NOT NULL,
  audience_type TEXT NOT NULL CHECK (audience_type IN ('ALL', 'PARENTS', 'TEACHERS', 'STUDENTS', 'ADMINS', 'CUSTOM')),
  created_by TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.announcement_deliveries (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  announcement_id UUID NOT NULL REFERENCES public.announcements(id) ON DELETE CASCADE,
  recipient_email TEXT NOT NULL,
  recipient_name TEXT,
  recipient_role TEXT NOT NULL,
  status TEXT NOT NULL DEFAULT 'queued' CHECK (status IN ('queued', 'sent', 'failed')),
  error_message TEXT,
  sent_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

