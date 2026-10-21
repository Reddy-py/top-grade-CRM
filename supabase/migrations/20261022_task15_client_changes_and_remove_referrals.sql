-- ============================================================================
-- Migration: 20261022_task15_client_changes_and_remove_referrals.sql
-- Goal: 
-- 1. Completely drop referrals tables and columns.
-- 2. Add course columns (duration_months, package_hours, package_price, hourly_rate).
-- 3. Enforce schedule slot collision prevention with exclusion constraints and triggers.
-- 4. Enforce student schedule collision prevention with a trigger and row-level locking.
-- 5. Add performance indexes for sub-300ms student roster search & filtering.
-- Idempotency: Safe to run multiple times without error.
-- ============================================================================

-- 1. Add course columns to public.courses
ALTER TABLE public.courses ADD COLUMN IF NOT EXISTS duration_months INT;
ALTER TABLE public.courses ADD COLUMN IF NOT EXISTS package_hours INT;
ALTER TABLE public.courses ADD COLUMN IF NOT EXISTS package_price NUMERIC;
ALTER TABLE public.courses ADD COLUMN IF NOT EXISTS hourly_rate NUMERIC;

-- 2. Completely drop all referrals tables and referred_by_code columns
DROP TABLE IF EXISTS public.referrals CASCADE;
DROP TABLE IF EXISTS public.referral_codes CASCADE;
ALTER TABLE IF EXISTS public.students DROP COLUMN IF EXISTS referred_by_code CASCADE;
ALTER TABLE IF EXISTS public.admissions DROP COLUMN IF EXISTS referred_by_code CASCADE;
ALTER TABLE IF EXISTS public.leads DROP COLUMN IF EXISTS referred_by_code CASCADE;

-- 3. Time conversion helper (IMMUTABLE for index/constraints)
CREATE OR REPLACE FUNCTION public.time_to_minutes(t text) RETURNS INT AS $$
DECLARE
  parts text[];
  time_part text;
  ampm text;
  h int;
  m int;
BEGIN
  IF t IS NULL OR t = '' THEN
    RETURN 0;
  END IF;
  t := trim(t);
  IF t ~* '(AM|PM)' THEN
    ampm := upper(substring(t from '(?i)(AM|PM)'));
    time_part := trim(regexp_replace(t, '(?i)(AM|PM)', ''));
    parts := string_to_array(time_part, ':');
    h := COALESCE(parts[1]::int, 0);
    m := COALESCE(parts[2]::int, 0);
    IF ampm = 'PM' AND h < 12 THEN
      h := h + 12;
    ELSIF ampm = 'AM' AND h = 12 THEN
      h := 0;
    END IF;
    RETURN h * 60 + m;
  ELSE
    parts := string_to_array(t, ':');
    h := COALESCE(parts[1]::int, 0);
    m := COALESCE(parts[2]::int, 0);
    RETURN h * 60 + m;
  END IF;
EXCEPTION WHEN OTHERS THEN
  RETURN 0;
END;
$$ LANGUAGE plpgsql IMMUTABLE;

-- 4. Add start_minute and end_minute columns to public.schedules
ALTER TABLE public.schedules ADD COLUMN IF NOT EXISTS start_minute INT NOT NULL DEFAULT 0;
ALTER TABLE public.schedules ADD COLUMN IF NOT EXISTS end_minute INT NOT NULL DEFAULT 60;

-- Populate existing rows
UPDATE public.schedules
SET 
  start_minute = public.time_to_minutes(start_time),
  end_minute = CASE 
    WHEN public.time_to_minutes(end_time) > public.time_to_minutes(start_time) 
      THEN public.time_to_minutes(end_time) 
    ELSE public.time_to_minutes(start_time) + 60 
  END
WHERE start_minute = 0 AND end_minute = 60 AND start_time IS NOT NULL AND start_time != '';

-- Trigger to maintain start_minute and end_minute on schedules
CREATE OR REPLACE FUNCTION public.sync_schedule_minutes() RETURNS TRIGGER AS $$
BEGIN
  IF NEW.start_minute IS NULL OR NEW.start_minute = 0 THEN
    NEW.start_minute := public.time_to_minutes(NEW.start_time);
  END IF;
  IF NEW.end_minute IS NULL OR NEW.end_minute = 0 OR NEW.end_minute <= NEW.start_minute THEN
    NEW.end_minute := public.time_to_minutes(NEW.end_time);
    IF NEW.end_minute <= NEW.start_minute THEN
      NEW.end_minute := NEW.start_minute + 60;
    END IF;
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_sync_schedule_minutes ON public.schedules;
CREATE TRIGGER trg_sync_schedule_minutes
  BEFORE INSERT OR UPDATE ON public.schedules
  FOR EACH ROW EXECUTE FUNCTION public.sync_schedule_minutes();

-- 5. Trigger for Teacher and Room Slot Collisions (provides explicit error naming conflicting class and time)
CREATE OR REPLACE FUNCTION public.check_schedule_slot_collisions()
RETURNS TRIGGER AS $$
DECLARE
  conflict_course TEXT;
  conflict_start TEXT;
  conflict_end TEXT;
BEGIN
  -- 1. Check Teacher Collision
  IF NEW.is_active = TRUE AND NEW.teacher_id IS NOT NULL AND NEW.teacher_id != '' AND NEW.open_for_teachers = FALSE THEN
    SELECT course_name, start_time, end_time
    INTO conflict_course, conflict_start, conflict_end
    FROM public.schedules
    WHERE is_active = TRUE
      AND id != COALESCE(NEW.id, '')
      AND teacher_id = NEW.teacher_id
      AND day_of_week = NEW.day_of_week
      AND int4range(start_minute, end_minute) && int4range(NEW.start_minute, NEW.end_minute)
    LIMIT 1;

    IF conflict_course IS NOT NULL THEN
      RAISE EXCEPTION 'Teacher collision: teacher is already teaching class "%" on % (% - %).',
        conflict_course, NEW.day_of_week, conflict_start, conflict_end;
    END IF;
  END IF;

  -- 2. Check Room Collision
  IF NEW.is_active = TRUE AND NEW.room IS NOT NULL AND NEW.room != '' AND NEW.location IS NOT NULL AND NEW.location != '' THEN
    SELECT course_name, start_time, end_time
    INTO conflict_course, conflict_start, conflict_end
    FROM public.schedules
    WHERE is_active = TRUE
      AND id != COALESCE(NEW.id, '')
      AND location = NEW.location
      AND room = NEW.room
      AND day_of_week = NEW.day_of_week
      AND int4range(start_minute, end_minute) && int4range(NEW.start_minute, NEW.end_minute)
    LIMIT 1;

    IF conflict_course IS NOT NULL THEN
      RAISE EXCEPTION 'Room collision: room "%" at % is already hosting class "%" on % (% - %).',
        NEW.room, NEW.location, conflict_course, NEW.day_of_week, conflict_start, conflict_end;
    END IF;
  END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_check_schedule_slot_collisions ON public.schedules;
CREATE TRIGGER trg_check_schedule_slot_collisions
  BEFORE INSERT OR UPDATE ON public.schedules
  FOR EACH ROW EXECUTE FUNCTION public.check_schedule_slot_collisions();

-- 6. Add btree_gist exclusion constraints when btree_gist is available in the environment
DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM pg_available_extensions WHERE name = 'btree_gist') THEN
    BEGIN
      CREATE EXTENSION IF NOT EXISTS btree_gist;

      ALTER TABLE public.schedules DROP CONSTRAINT IF EXISTS no_teacher_slot_collision;
      ALTER TABLE public.schedules
        ADD CONSTRAINT no_teacher_slot_collision
        EXCLUDE USING gist (
          teacher_id WITH =,
          day_of_week WITH =,
          int4range(start_minute, end_minute) WITH &&
        ) WHERE (is_active = TRUE AND teacher_id IS NOT NULL AND teacher_id != '' AND open_for_teachers = FALSE);

      ALTER TABLE public.schedules DROP CONSTRAINT IF EXISTS no_room_slot_collision;
      ALTER TABLE public.schedules
        ADD CONSTRAINT no_room_slot_collision
        EXCLUDE USING gist (
          location WITH =,
          room WITH =,
          day_of_week WITH =,
          int4range(start_minute, end_minute) WITH &&
        ) WHERE (is_active = TRUE AND room IS NOT NULL AND room != '' AND location IS NOT NULL AND location != '');
    EXCEPTION WHEN OTHERS THEN
      RAISE NOTICE 'Could not create btree_gist exclusion constraint (trigger handles collision): %', SQLERRM;
    END;
  END IF;
END $$;

-- 7. Student slot collision prevention trigger with row-level locking
CREATE OR REPLACE FUNCTION public.check_student_slot_collision()
RETURNS TRIGGER AS $$
DECLARE
  new_day TEXT;
  new_start INT;
  new_end INT;
  slot_cap INT;
  cur_count INT;
  conflict_course TEXT;
  conflict_day TEXT;
  conflict_start TEXT;
  conflict_end TEXT;
BEGIN
  -- Lock student row to prevent concurrent race conditions
  PERFORM 1 FROM public.students WHERE id::text = NEW.student_id::text FOR UPDATE;

  -- Get the slot details and capacity of the slot the student is enrolling in
  SELECT day_of_week, start_minute, end_minute, max_capacity
  INTO new_day, new_start, new_end, slot_cap
  FROM public.schedules
  WHERE id = NEW.schedule_id;

  -- Check Class Capacity
  IF slot_cap IS NOT NULL AND slot_cap > 0 THEN
    SELECT COUNT(*) INTO cur_count FROM public.schedule_students WHERE schedule_id = NEW.schedule_id;
    IF cur_count >= slot_cap THEN
      RAISE EXCEPTION 'Class capacity limit reached (%). Cannot enroll more students.', slot_cap;
    END IF;
  END IF;

  IF new_day IS NOT NULL THEN
    -- Check if student already enrolled in an active overlapping slot on the same weekday
    SELECT s.course_name, s.day_of_week, s.start_time, s.end_time
    INTO conflict_course, conflict_day, conflict_start, conflict_end
    FROM public.schedule_students ss
    JOIN public.schedules s ON s.id = ss.schedule_id
    WHERE ss.student_id::text = NEW.student_id::text
      AND s.is_active = TRUE
      AND s.id != NEW.schedule_id
      AND s.day_of_week = new_day
      AND int4range(s.start_minute, s.end_minute) && int4range(new_start, new_end)
    LIMIT 1;

    IF conflict_course IS NOT NULL THEN
      RAISE EXCEPTION 'Student collision: student is already enrolled in conflicting class "%" on % (% - %).',
        conflict_course, conflict_day, conflict_start, conflict_end;
    END IF;
  END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_check_student_slot_collision ON public.schedule_students;
CREATE TRIGGER trg_check_student_slot_collision
  BEFORE INSERT OR UPDATE ON public.schedule_students
  FOR EACH ROW EXECUTE FUNCTION public.check_student_slot_collision();

-- 8. Performance indexes for student roster filtering
CREATE INDEX IF NOT EXISTS idx_students_school ON public.students (school);
CREATE INDEX IF NOT EXISTS idx_students_status ON public.students (status);
CREATE INDEX IF NOT EXISTS idx_students_created_at ON public.students (created_at);
CREATE INDEX IF NOT EXISTS idx_schedule_students_student_id ON public.schedule_students (student_id);
CREATE INDEX IF NOT EXISTS idx_schedule_students_schedule_id ON public.schedule_students (schedule_id);
CREATE INDEX IF NOT EXISTS idx_schedules_day_teacher ON public.schedules (day_of_week, teacher_id) WHERE is_active = TRUE;
CREATE INDEX IF NOT EXISTS idx_attendance_student_status ON public.attendance (student_id, status);

-- 9. Explicit RLS policy for student_dossiers (admin and service_role)
ALTER TABLE public.student_dossiers ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "admin_all_student_dossiers" ON public.student_dossiers;
CREATE POLICY "admin_all_student_dossiers" ON public.student_dossiers
  FOR ALL USING (
    public.get_current_user_role() = 'ADMIN' 
    OR auth.role() = 'service_role' 
    OR (auth.jwt() ->> 'role') = 'service_role'
  )
  WITH CHECK (
    public.get_current_user_role() = 'ADMIN' 
    OR auth.role() = 'service_role' 
    OR (auth.jwt() ->> 'role') = 'service_role'
  );

