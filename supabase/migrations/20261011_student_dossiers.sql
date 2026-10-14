-- ============================================================================
-- Students: Supabase becomes the only store.
-- The full student record (extra details that have no column of their own) lives in student_dossiers.
-- Row-level security is ON with no policy, so ONLY the backend (service role) can read or write it.
-- Parents, teachers and students can never read it through the browser.
-- ============================================================================
CREATE TABLE IF NOT EXISTS public.student_dossiers (
  student_id UUID PRIMARY KEY REFERENCES public.students(id) ON DELETE CASCADE,
  dossier    JSONB NOT NULL DEFAULT '{}'::jsonb,
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
ALTER TABLE public.student_dossiers ENABLE ROW LEVEL SECURITY;

-- parent_emails is what links a parent login to a child (also added by 20261010, safe to repeat)
ALTER TABLE public.students ADD COLUMN IF NOT EXISTS parent_emails TEXT[] NOT NULL DEFAULT '{}';
CREATE INDEX IF NOT EXISTS idx_students_parent_emails ON public.students USING GIN (parent_emails);

-- one student record per student code (the backend saves by this code)
CREATE UNIQUE INDEX IF NOT EXISTS students_student_id_code_uniq ON public.students (student_id_code);
