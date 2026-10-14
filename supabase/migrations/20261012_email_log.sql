-- ============================================================================
-- Email log in Supabase (replaces data/automated_emails_log.json)
--  * every automatic email (birthday, student added, student updated, exam wishes) leaves one row
--  * once-a-day emails (birthdays, exam wishes) are protected by a unique index, so a restart,
--    a redeploy or a second server can never send the same wish twice on the same day
-- Only the backend (service role) and admins can read it.
-- ============================================================================
CREATE TABLE IF NOT EXISTS public.email_log (
  id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  kind        TEXT NOT NULL,                 -- BIRTHDAY, TEACHER_BIRTHDAY, EXAM_GOOD_LUCK, STUDENT_ADDED, STUDENT_UPDATED
  subject_key TEXT NOT NULL,                 -- student id or teacher id the email is about
  send_date   DATE NOT NULL,                 -- the institute's local date
  recipients  TEXT[] NOT NULL DEFAULT '{}',
  subject     TEXT,
  status      TEXT NOT NULL DEFAULT 'sending',   -- sending | sent | failed | simulated
  error       TEXT,
  created_at  TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at  TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE UNIQUE INDEX IF NOT EXISTS email_log_once_per_day
  ON public.email_log (kind, subject_key, send_date)
  WHERE kind IN ('BIRTHDAY', 'TEACHER_BIRTHDAY', 'EXAM_GOOD_LUCK');
CREATE INDEX IF NOT EXISTS email_log_created_at_idx ON public.email_log (created_at DESC);

ALTER TABLE public.email_log ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "admin_all" ON public.email_log;
CREATE POLICY "admin_all" ON public.email_log FOR ALL TO authenticated
  USING (public.get_current_user_role() = 'ADMIN')
  WITH CHECK (public.get_current_user_role() = 'ADMIN');
