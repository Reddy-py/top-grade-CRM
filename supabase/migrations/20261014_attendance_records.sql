-- ============================================================================
-- Attendance: Supabase is the only store
-- Before: the roll-call wrote a text name into a UUID column (so the save failed and was ignored), several screens
-- wrote the same class in different ways, and the real records lived in server memory.
-- Now: one row per student, per class, per day. Saving the same class again updates that row.
-- ============================================================================
ALTER TABLE public.attendance
  ADD COLUMN IF NOT EXISTS student_code    TEXT,
  ADD COLUMN IF NOT EXISTS course_id       TEXT,
  ADD COLUMN IF NOT EXISTS course_name     TEXT,
  ADD COLUMN IF NOT EXISTS schedule_id     TEXT,
  ADD COLUMN IF NOT EXISTS class_key       TEXT,
  ADD COLUMN IF NOT EXISTS check_in_time   TIMESTAMPTZ,
  ADD COLUMN IF NOT EXISTS check_out_time  TIMESTAMPTZ,
  ADD COLUMN IF NOT EXISTS scan_method     TEXT,
  ADD COLUMN IF NOT EXISTS marked_by_name  TEXT,
  ADD COLUMN IF NOT EXISTS updated_at      TIMESTAMPTZ NOT NULL DEFAULT now();

-- Fills class_key (which class this row is for) and writes the status in capitals, whichever screen saved the row.
CREATE OR REPLACE FUNCTION public.attendance_before_write()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
BEGIN
  NEW.status := upper(coalesce(NEW.status, 'PRESENT'));
  NEW.class_key := lower(coalesce(nullif(NEW.class_key, ''), nullif(NEW.schedule_id, ''), nullif(NEW.course_id, ''), NEW.class_name, ''));
  NEW.updated_at := now();
  RETURN NEW;
END $$;

DROP TRIGGER IF EXISTS attendance_before_write ON public.attendance;
CREATE TRIGGER attendance_before_write BEFORE INSERT OR UPDATE ON public.attendance
  FOR EACH ROW EXECUTE FUNCTION public.attendance_before_write();

-- Existing rows: normalise, then remove duplicates of the same student, class and day (keep the newest)
UPDATE public.attendance SET status = status;   -- runs the trigger once per row
DELETE FROM public.attendance a
 USING public.attendance b
 WHERE a.student_id = b.student_id AND a.class_key = b.class_key AND a.date = b.date
   AND (a.created_at, a.id) < (b.created_at, b.id);

CREATE UNIQUE INDEX IF NOT EXISTS attendance_one_per_class_day
  ON public.attendance (student_id, class_key, date);
CREATE INDEX IF NOT EXISTS attendance_date_idx ON public.attendance (date DESC);
