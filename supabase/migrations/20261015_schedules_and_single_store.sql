-- ============================================================================
-- Migration: 20261015_schedules_and_single_store.sql
-- Goal: Make Supabase the only store for schedules, history, teacher availability,
--       leads, lead interactions, enrollments, campaigns, and alert logs.
-- Rules:
-- 1. Never drop or recreate pre-existing tables:
--    (schedules, schedule_students, teacher_availability, student_history, leads, enrollments).
-- 2. Data-preserving conversion of ID columns from UUID to TEXT
--    (add new column -> copy -> swap -> re-point foreign keys).
-- 3. Drop all policies and functions depending on id/schedule_id before column swap.
-- 4. RLS strictly uses public.get_current_user_role() (reads profiles table).
-- 5. No public (anonymous) insert policies on leads or enrollments.
-- 6. teacher_availability policies match via public.my_teacher_keys().
-- 7. No references to non-existent students.parent_id (parents linked via students.parent_emails).
-- 8. Keep UNIQUE rule on enrollments.lead_id.
-- ============================================================================

-- ---------------------------------------------------------------------------
-- 0A. ENSURE CORE TABLES EXIST WITH FINAL SHAPE (TEXT IDs) FOR FRESH DATABASES
-- If the tables already exist (e.g. from migrations 20260817/20260910 with UUID ids),
-- CREATE TABLE IF NOT EXISTS does nothing, and Section 1 will convert them.
-- ---------------------------------------------------------------------------

-- 1. Schedules Table
CREATE TABLE IF NOT EXISTS public.schedules (
    id TEXT PRIMARY KEY,
    course_id TEXT NOT NULL,
    course_name TEXT NOT NULL,
    teacher_id TEXT,
    teacher_name TEXT,
    day_of_week TEXT NOT NULL,
    start_time TEXT NOT NULL,
    end_time TEXT NOT NULL,
    time_slot TEXT NOT NULL,
    room TEXT DEFAULT 'Room 101',
    location TEXT DEFAULT 'Main Academic Center',
    max_capacity INT DEFAULT 15,
    is_active BOOLEAN DEFAULT TRUE,
    open_for_teachers BOOLEAN NOT NULL DEFAULT FALSE,
    program TEXT,
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);

-- 2. Schedule Students Mapping Table
CREATE TABLE IF NOT EXISTS public.schedule_students (
    id TEXT PRIMARY KEY,
    schedule_id TEXT NOT NULL REFERENCES public.schedules(id) ON DELETE CASCADE,
    student_id TEXT NOT NULL,
    student_name TEXT NOT NULL,
    student_code TEXT,
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT unique_schedule_student UNIQUE (schedule_id, student_id)
);

-- 3. Teacher Availability Table
CREATE TABLE IF NOT EXISTS public.teacher_availability (
    id TEXT PRIMARY KEY,
    teacher_id TEXT NOT NULL,
    day_of_week TEXT NOT NULL,
    available_from TEXT NOT NULL DEFAULT '09:00',
    available_to TEXT NOT NULL DEFAULT '19:00',
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);

-- 4. Student History Ledger Table
CREATE TABLE IF NOT EXISTS public.student_history (
    id TEXT PRIMARY KEY,
    student_id TEXT NOT NULL,
    student_name TEXT,
    event_type TEXT NOT NULL,
    title TEXT NOT NULL,
    description TEXT,
    metadata JSONB DEFAULT '{}'::jsonb,
    actor TEXT DEFAULT 'System',
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);

-- 5. Leads Table
CREATE TABLE IF NOT EXISTS public.leads (
    id TEXT PRIMARY KEY,
    source TEXT NOT NULL DEFAULT 'DIRECT_FORM',
    student_name TEXT,
    parent_name TEXT,
    contact_number TEXT,
    email TEXT,
    academic_grade TEXT,
    message TEXT,
    is_converted BOOLEAN DEFAULT FALSE,
    converted_at TIMESTAMPTZ,
    full_name TEXT,
    phone TEXT,
    target_grade TEXT,
    notes TEXT,
    utm_parameters TEXT,
    status TEXT NOT NULL DEFAULT 'PENDING',
    last_interaction_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);

-- 6. Enrollments Table (Preserves UNIQUE constraint on lead_id)
CREATE TABLE IF NOT EXISTS public.enrollments (
    id TEXT PRIMARY KEY,
    lead_id TEXT UNIQUE REFERENCES public.leads(id) ON DELETE CASCADE,
    student_id UUID REFERENCES public.students(id) ON DELETE SET NULL,
    academic_grade TEXT,
    status TEXT NOT NULL DEFAULT 'FORM_SUBMITTED',
    student_name TEXT,
    email TEXT,
    primary_mobile TEXT,
    dob DATE,
    calculated_age INTEGER,
    residential_address TEXT,
    submitted_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    reviewed_at TIMESTAMPTZ,
    approved_at TIMESTAMPTZ,
    activated_at TIMESTAMPTZ,
    review_notes TEXT,
    financial_waiver BOOLEAN DEFAULT FALSE,
    transport_waiver BOOLEAN DEFAULT FALSE,
    media_waiver BOOLEAN DEFAULT FALSE
);

-- ---------------------------------------------------------------------------
-- 0B. Cleanup any temporary/deprecated helpers & drop dependent policies/functions
-- ---------------------------------------------------------------------------
DROP FUNCTION IF EXISTS public.user_role() CASCADE;

-- Drop policies from 20261010 & earlier that depend on schedules.id / schedule_students.schedule_id
DROP POLICY IF EXISTS "own_schedules_read" ON public.schedules;
DROP POLICY IF EXISTS "own_schedule_students_read" ON public.schedule_students;
DROP POLICY IF EXISTS "admin_all_schedules" ON public.schedules;
DROP POLICY IF EXISTS "teachers_view_assigned_or_open_schedules" ON public.schedules;
DROP POLICY IF EXISTS "students_parents_view_own_schedules" ON public.schedules;
DROP POLICY IF EXISTS "admin_all_schedule_students" ON public.schedule_students;
DROP POLICY IF EXISTS "teachers_view_roster_schedule_students" ON public.schedule_students;
DROP POLICY IF EXISTS "students_parents_view_own_schedule_students" ON public.schedule_students;
DROP POLICY IF EXISTS "students_view_own_schedule_students" ON public.schedule_students;
DROP POLICY IF EXISTS "parents_view_own_schedule_students" ON public.schedule_students;

-- Drop function my_schedule_ids() which queries schedules.id and schedule_students.schedule_id
DROP FUNCTION IF EXISTS public.my_schedule_ids() CASCADE;

-- ---------------------------------------------------------------------------
-- 1. DATA-PRESERVING CONVERSION & COLUMN ENRICHMENT FOR PRE-EXISTING TABLES
-- Pattern: Add new column -> copy data -> swap -> re-point foreign keys
-- ---------------------------------------------------------------------------

-- 1A & 1B. Tables: public.schedules & public.schedule_students
DO $$
BEGIN
  IF EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = 'public' AND table_name = 'schedules' AND column_name = 'id' AND data_type = 'uuid'
  ) THEN
    -- Step 1: Drop foreign key & unique constraints prior to swap
    ALTER TABLE IF EXISTS public.schedule_students DROP CONSTRAINT IF EXISTS schedule_students_schedule_id_fkey;
    ALTER TABLE IF EXISTS public.schedule_students DROP CONSTRAINT IF EXISTS unique_schedule_student;
    ALTER TABLE IF EXISTS public.schedule_students DROP CONSTRAINT IF EXISTS schedule_students_pkey;
    ALTER TABLE IF EXISTS public.schedules DROP CONSTRAINT IF EXISTS schedules_pkey;

    -- Step 2: Add new TEXT columns
    ALTER TABLE public.schedule_students ADD COLUMN IF NOT EXISTS new_schedule_id TEXT;
    ALTER TABLE public.schedule_students ADD COLUMN IF NOT EXISTS new_id TEXT;
    ALTER TABLE public.schedules ADD COLUMN IF NOT EXISTS new_id TEXT;

    -- Step 3: Copy existing UUID values as TEXT
    UPDATE public.schedule_students SET new_schedule_id = schedule_id::TEXT WHERE new_schedule_id IS NULL AND schedule_id IS NOT NULL;
    UPDATE public.schedule_students SET new_id = id::TEXT WHERE new_id IS NULL AND id IS NOT NULL;
    UPDATE public.schedules SET new_id = id::TEXT WHERE new_id IS NULL AND id IS NOT NULL;

    -- Step 4: Swap columns
    ALTER TABLE public.schedule_students DROP COLUMN id;
    ALTER TABLE public.schedule_students RENAME COLUMN new_id TO id;
    ALTER TABLE public.schedule_students ADD PRIMARY KEY (id);

    ALTER TABLE public.schedule_students DROP COLUMN schedule_id;
    ALTER TABLE public.schedule_students RENAME COLUMN new_schedule_id TO schedule_id;

    ALTER TABLE public.schedules DROP COLUMN id;
    ALTER TABLE public.schedules RENAME COLUMN new_id TO id;
    ALTER TABLE public.schedules ADD PRIMARY KEY (id);

    -- Step 5: Re-point foreign keys & unique constraints
    ALTER TABLE public.schedule_students ADD CONSTRAINT schedule_students_schedule_id_fkey
      FOREIGN KEY (schedule_id) REFERENCES public.schedules(id) ON DELETE CASCADE;
    ALTER TABLE public.schedule_students ADD CONSTRAINT unique_schedule_student
      UNIQUE (schedule_id, student_id);
  ELSE
    RAISE NOTICE 'schedules.id is already TEXT or non-UUID. Skipping schedules column swap.';
  END IF;
END $$;

-- Add missing columns & adjust nullability on public.schedules
ALTER TABLE public.schedules ALTER COLUMN teacher_id DROP NOT NULL;
ALTER TABLE public.schedules ALTER COLUMN teacher_name DROP NOT NULL;
ALTER TABLE public.schedules ADD COLUMN IF NOT EXISTS open_for_teachers BOOLEAN NOT NULL DEFAULT FALSE;
ALTER TABLE public.schedules ADD COLUMN IF NOT EXISTS location TEXT DEFAULT 'Main Academic Center';
ALTER TABLE public.schedules ADD COLUMN IF NOT EXISTS program TEXT;

CREATE INDEX IF NOT EXISTS idx_schedules_open ON public.schedules(open_for_teachers) WHERE open_for_teachers = TRUE;
CREATE INDEX IF NOT EXISTS idx_schedules_day_time ON public.schedules(day_of_week, start_time, end_time);
CREATE INDEX IF NOT EXISTS idx_schedules_teacher ON public.schedules(teacher_id);
CREATE INDEX IF NOT EXISTS idx_schedules_course ON public.schedules(course_id);
CREATE INDEX IF NOT EXISTS idx_schedule_students_sched ON public.schedule_students(schedule_id);
CREATE INDEX IF NOT EXISTS idx_schedule_students_stud ON public.schedule_students(student_id);

-- 1C. Table: public.teacher_availability
DO $$
BEGIN
  IF EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = 'public' AND table_name = 'teacher_availability' AND column_name = 'id' AND data_type = 'uuid'
  ) THEN
    ALTER TABLE public.teacher_availability DROP CONSTRAINT IF EXISTS teacher_availability_pkey;
    ALTER TABLE public.teacher_availability ADD COLUMN IF NOT EXISTS new_id TEXT;
    UPDATE public.teacher_availability SET new_id = id::TEXT WHERE new_id IS NULL AND id IS NOT NULL;
    ALTER TABLE public.teacher_availability DROP COLUMN id;
    ALTER TABLE public.teacher_availability RENAME COLUMN new_id TO id;
    ALTER TABLE public.teacher_availability ADD PRIMARY KEY (id);
  ELSE
    RAISE NOTICE 'teacher_availability.id is already TEXT. Skipping column swap.';
  END IF;
END $$;

CREATE INDEX IF NOT EXISTS idx_teacher_availability_tchr ON public.teacher_availability(teacher_id);
CREATE INDEX IF NOT EXISTS idx_teacher_availability_day ON public.teacher_availability(day_of_week);

-- 1D. Table: public.student_history
DO $$
BEGIN
  IF EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = 'public' AND table_name = 'student_history' AND column_name = 'id' AND data_type = 'uuid'
  ) THEN
    ALTER TABLE public.student_history DROP CONSTRAINT IF EXISTS student_history_pkey;
    ALTER TABLE public.student_history ADD COLUMN IF NOT EXISTS new_id TEXT;
    UPDATE public.student_history SET new_id = id::TEXT WHERE new_id IS NULL AND id IS NOT NULL;
    ALTER TABLE public.student_history DROP COLUMN id;
    ALTER TABLE public.student_history RENAME COLUMN new_id TO id;
    ALTER TABLE public.student_history ADD PRIMARY KEY (id);
  ELSE
    RAISE NOTICE 'student_history.id is already TEXT. Skipping column swap.';
  END IF;
END $$;

CREATE INDEX IF NOT EXISTS idx_student_history_student ON public.student_history(student_id);
CREATE INDEX IF NOT EXISTS idx_student_history_event ON public.student_history(event_type);

-- 1E. Table: public.leads & public.enrollments
DO $$
BEGIN
  IF EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = 'public' AND table_name = 'leads' AND column_name = 'id' AND data_type = 'uuid'
  ) THEN
    -- Step 1: Drop foreign key & primary keys
    ALTER TABLE IF EXISTS public.enrollments DROP CONSTRAINT IF EXISTS enrollments_lead_id_key;
    ALTER TABLE IF EXISTS public.enrollments DROP CONSTRAINT IF EXISTS enrollments_lead_id_fkey;
    ALTER TABLE IF EXISTS public.enrollments DROP CONSTRAINT IF EXISTS enrollments_pkey;
    ALTER TABLE IF EXISTS public.leads DROP CONSTRAINT IF EXISTS leads_pkey;

    -- Step 2: Add new TEXT columns
    ALTER TABLE public.enrollments ADD COLUMN IF NOT EXISTS new_id TEXT;
    ALTER TABLE public.enrollments ADD COLUMN IF NOT EXISTS new_lead_id TEXT;
    ALTER TABLE public.leads ADD COLUMN IF NOT EXISTS new_id TEXT;

    -- Step 3: Copy data
    UPDATE public.enrollments SET new_id = id::TEXT WHERE new_id IS NULL AND id IS NOT NULL;
    UPDATE public.enrollments SET new_lead_id = lead_id::TEXT WHERE new_lead_id IS NULL AND lead_id IS NOT NULL;
    UPDATE public.leads SET new_id = id::TEXT WHERE new_id IS NULL AND id IS NOT NULL;

    -- Step 4: Swap columns
    ALTER TABLE public.enrollments DROP COLUMN id;
    ALTER TABLE public.enrollments RENAME COLUMN new_id TO id;
    ALTER TABLE public.enrollments ADD PRIMARY KEY (id);

    ALTER TABLE public.enrollments DROP COLUMN lead_id;
    ALTER TABLE public.enrollments RENAME COLUMN new_lead_id TO lead_id;

    ALTER TABLE public.leads DROP COLUMN id;
    ALTER TABLE public.leads RENAME COLUMN new_id TO id;
    ALTER TABLE public.leads ADD PRIMARY KEY (id);

    -- Step 5: Re-point foreign keys & UNIQUE constraint on lead_id
    ALTER TABLE public.enrollments ADD CONSTRAINT enrollments_lead_id_key UNIQUE (lead_id);
    ALTER TABLE public.enrollments ADD CONSTRAINT enrollments_lead_id_fkey
      FOREIGN KEY (lead_id) REFERENCES public.leads(id) ON DELETE CASCADE;
  ELSE
    RAISE NOTICE 'leads.id is already TEXT. Skipping column swap.';
  END IF;
END $$;

-- Add missing columns on public.leads
ALTER TABLE public.leads ADD COLUMN IF NOT EXISTS full_name TEXT;
ALTER TABLE public.leads ADD COLUMN IF NOT EXISTS phone TEXT;
ALTER TABLE public.leads ADD COLUMN IF NOT EXISTS target_grade TEXT;
ALTER TABLE public.leads ADD COLUMN IF NOT EXISTS notes TEXT;
ALTER TABLE public.leads ADD COLUMN IF NOT EXISTS utm_parameters TEXT;
ALTER TABLE public.leads ADD COLUMN IF NOT EXISTS status TEXT NOT NULL DEFAULT 'PENDING';
ALTER TABLE public.leads ADD COLUMN IF NOT EXISTS last_interaction_at TIMESTAMPTZ;

-- Backfill full_name and phone if null
UPDATE public.leads SET full_name = student_name WHERE full_name IS NULL AND student_name IS NOT NULL;
UPDATE public.leads SET phone = contact_number WHERE phone IS NULL AND contact_number IS NOT NULL;

CREATE INDEX IF NOT EXISTS idx_leads_status ON public.leads(status);
CREATE INDEX IF NOT EXISTS idx_leads_email ON public.leads(email);
CREATE INDEX IF NOT EXISTS idx_leads_created_at ON public.leads(created_at DESC);

-- Add missing columns on public.enrollments
ALTER TABLE public.enrollments ADD COLUMN IF NOT EXISTS student_name TEXT;
ALTER TABLE public.enrollments ADD COLUMN IF NOT EXISTS email TEXT;
ALTER TABLE public.enrollments ADD COLUMN IF NOT EXISTS primary_mobile TEXT;
ALTER TABLE public.enrollments ADD COLUMN IF NOT EXISTS dob DATE;
ALTER TABLE public.enrollments ADD COLUMN IF NOT EXISTS calculated_age INTEGER;
ALTER TABLE public.enrollments ADD COLUMN IF NOT EXISTS residential_address TEXT;

CREATE INDEX IF NOT EXISTS idx_enrollments_status ON public.enrollments(status);
CREATE INDEX IF NOT EXISTS idx_enrollments_submitted ON public.enrollments(submitted_at DESC);

-- ---------------------------------------------------------------------------
-- 2. CREATE NEW TABLES (ZERO PRIOR INSTANCES IN DATABASE)
-- ---------------------------------------------------------------------------

-- 2A. Lead Interactions Table
CREATE TABLE IF NOT EXISTS public.lead_interactions (
    id TEXT PRIMARY KEY,
    lead_id TEXT NOT NULL REFERENCES public.leads(id) ON DELETE CASCADE,
    counselor_id TEXT,
    interaction_type TEXT NOT NULL,
    outcome TEXT NOT NULL,
    notes TEXT NOT NULL,
    scheduled_follow_up_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
CREATE INDEX IF NOT EXISTS idx_lead_interactions_lead_id ON public.lead_interactions(lead_id);
CREATE INDEX IF NOT EXISTS idx_lead_interactions_follow_up ON public.lead_interactions(scheduled_follow_up_at);

-- 2B. Campaigns Broadcast History Table
CREATE TABLE IF NOT EXISTS public.campaigns (
    id TEXT PRIMARY KEY,
    title TEXT NOT NULL,
    subject TEXT NOT NULL,
    target_source TEXT NOT NULL DEFAULT 'ALL',
    target_grade TEXT NOT NULL DEFAULT 'ALL',
    recipients_count INTEGER NOT NULL DEFAULT 0,
    status TEXT NOT NULL DEFAULT 'Completed',
    sent_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
CREATE INDEX IF NOT EXISTS idx_campaigns_sent_at ON public.campaigns(sent_at DESC);

-- 2C. Alert Logs Table
CREATE TABLE IF NOT EXISTS public.alert_logs (
    id TEXT PRIMARY KEY,
    trigger_type TEXT NOT NULL,
    recipient_id TEXT,
    recipient_name TEXT NOT NULL,
    recipient_email TEXT NOT NULL,
    recipient_phone TEXT,
    recipient_role TEXT NOT NULL DEFAULT 'STUDENT',
    channel TEXT NOT NULL DEFAULT 'MULTI_CHANNEL',
    subject TEXT NOT NULL,
    message_preview TEXT NOT NULL,
    status TEXT NOT NULL DEFAULT 'DELIVERED',
    timestamp TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    metadata JSONB,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
CREATE INDEX IF NOT EXISTS idx_alert_logs_trigger ON public.alert_logs(trigger_type);
CREATE INDEX IF NOT EXISTS idx_alert_logs_recipient ON public.alert_logs(recipient_id);
CREATE INDEX IF NOT EXISTS idx_alert_logs_timestamp ON public.alert_logs(timestamp DESC);

-- 2D. Tutoring Past Records Table
CREATE TABLE IF NOT EXISTS public.tutoring_past_records (
    id TEXT PRIMARY KEY,
    student_id TEXT NOT NULL,
    student_name TEXT NOT NULL,
    student_code TEXT,
    subject TEXT NOT NULL,
    teacher_name TEXT NOT NULL,
    term_period TEXT NOT NULL,
    total_hours_completed NUMERIC DEFAULT 0,
    total_sessions_attended INTEGER DEFAULT 0,
    final_score_percentage NUMERIC DEFAULT 0,
    curriculum_milestones TEXT[] DEFAULT '{}',
    status TEXT NOT NULL DEFAULT 'Completed',
    reenrollment_eligible BOOLEAN DEFAULT TRUE,
    reenrollment_status TEXT NOT NULL DEFAULT 'Pending Invitation',
    completion_date DATE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
CREATE INDEX IF NOT EXISTS idx_tutoring_past_student ON public.tutoring_past_records(student_id);

-- 2E. Afterschool Past Records Table
CREATE TABLE IF NOT EXISTS public.afterschool_past_records (
    id TEXT PRIMARY KEY,
    student_id TEXT NOT NULL,
    student_name TEXT NOT NULL,
    student_code TEXT,
    program_name TEXT NOT NULL,
    grade_level TEXT NOT NULL,
    term_period TEXT NOT NULL,
    attendance_consistency_rate NUMERIC DEFAULT 0,
    activities_completed TEXT[] DEFAULT '{}',
    certificate_issued BOOLEAN DEFAULT FALSE,
    certificate_url TEXT,
    retention_recommendation TEXT NOT NULL DEFAULT 'Standard Followup',
    status TEXT NOT NULL DEFAULT 'Completed',
    end_date DATE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
CREATE INDEX IF NOT EXISTS idx_afterschool_past_student ON public.afterschool_past_records(student_id);

-- ---------------------------------------------------------------------------
-- 3. RECREATE HELPER FUNCTION (SETOF TEXT return type)
-- Parents are linked strictly by lower(auth.jwt() ->> 'email') = ANY(s.parent_emails)
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.my_schedule_ids()
RETURNS SETOF TEXT
LANGUAGE plpgsql STABLE SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  r TEXT := public.get_current_user_role();
BEGIN
  IF r = 'TEACHER' THEN
    RETURN QUERY
      SELECT sc.id FROM public.schedules sc
      WHERE lower(coalesce(sc.teacher_id, '')) = ANY (public.my_teacher_keys())
         OR lower(coalesce(sc.teacher_name, '')) = ANY (public.my_teacher_names());
  ELSIF r IN ('PARENT', 'STUDENT') THEN
    RETURN QUERY
      SELECT ss.schedule_id FROM public.schedule_students ss
      JOIN public.students s ON (s.id::text = ss.student_id OR s.student_id_code = ss.student_id OR s.student_id_code = ss.student_code)
      WHERE (r = 'STUDENT' AND s.user_id = auth.uid())
         OR (r = 'PARENT' AND (
              lower(auth.jwt() ->> 'email') = ANY (s.parent_emails)
            ));
  ELSE
    RETURN;
  END IF;
END;
$$;

-- ---------------------------------------------------------------------------
-- 4. ROW LEVEL SECURITY (RLS) POLICIES
-- Strict adherence:
--  - Role checking strictly uses public.get_current_user_role() (reads profiles table)
--  - Teacher identity checked via public.my_teacher_keys()
--  - Parents linked strictly by email matching s.parent_emails (no parent_id)
--  - ZERO public/anon insert policies on leads or enrollments (backend API handles them)
-- ---------------------------------------------------------------------------

ALTER TABLE public.schedules ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.schedule_students ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.teacher_availability ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.student_history ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.leads ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.lead_interactions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.enrollments ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.campaigns ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.alert_logs ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.tutoring_past_records ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.afterschool_past_records ENABLE ROW LEVEL SECURITY;

-- 4A. Schedules Policies
DROP POLICY IF EXISTS "admin_all_schedules" ON public.schedules;
CREATE POLICY "admin_all_schedules" ON public.schedules
  FOR ALL USING (public.get_current_user_role() = 'ADMIN');

DROP POLICY IF EXISTS "teachers_view_assigned_or_open_schedules" ON public.schedules;
CREATE POLICY "teachers_view_assigned_or_open_schedules" ON public.schedules
  FOR SELECT USING (
    public.get_current_user_role() = 'TEACHER'
    AND (
      open_for_teachers = TRUE
      OR lower(coalesce(teacher_id, '')) = ANY (public.my_teacher_keys())
      OR lower(coalesce(teacher_name, '')) = ANY (public.my_teacher_names())
    )
  );

DROP POLICY IF EXISTS "students_parents_view_own_schedules" ON public.schedules;
CREATE POLICY "students_parents_view_own_schedules" ON public.schedules
  FOR SELECT USING (
    public.get_current_user_role() IN ('STUDENT', 'PARENT')
    AND id IN (SELECT public.my_schedule_ids())
  );

-- 4B. Schedule Students Policies
DROP POLICY IF EXISTS "admin_all_schedule_students" ON public.schedule_students;
CREATE POLICY "admin_all_schedule_students" ON public.schedule_students
  FOR ALL USING (public.get_current_user_role() = 'ADMIN');

DROP POLICY IF EXISTS "teachers_view_roster_schedule_students" ON public.schedule_students;
CREATE POLICY "teachers_view_roster_schedule_students" ON public.schedule_students
  FOR SELECT USING (
    public.get_current_user_role() = 'TEACHER'
    AND schedule_id IN (SELECT public.my_schedule_ids())
  );

DROP POLICY IF EXISTS "students_parents_view_own_schedule_students" ON public.schedule_students;
DROP POLICY IF EXISTS "students_view_own_schedule_students" ON public.schedule_students;
CREATE POLICY "students_view_own_schedule_students" ON public.schedule_students
  FOR SELECT USING (
    public.get_current_user_role() = 'STUDENT'
    AND EXISTS (
      SELECT 1 FROM public.students s
      WHERE (s.user_id = auth.uid() OR lower(s.email) = lower(auth.jwt() ->> 'email'))
        AND (schedule_students.student_id = s.id::text OR schedule_students.student_id = s.student_id_code OR schedule_students.student_code = s.student_id_code)
    )
  );

DROP POLICY IF EXISTS "parents_view_own_schedule_students" ON public.schedule_students;
CREATE POLICY "parents_view_own_schedule_students" ON public.schedule_students
  FOR SELECT USING (
    public.get_current_user_role() = 'PARENT'
    AND EXISTS (
      SELECT 1 FROM public.students s
      WHERE lower(auth.jwt() ->> 'email') = ANY (s.parent_emails)
        AND (schedule_students.student_id = s.id::text OR schedule_students.student_id = s.student_id_code OR schedule_students.student_code = s.student_id_code)
    )
  );

-- 4C. Teacher Availability Policies (checked via public.my_teacher_keys(), NOT auth.uid())
-- Leak 1 Fixed: Readable ONLY by ADMIN and owning TEACHER. Student, Parent, Anon see 0 rows.
DROP POLICY IF EXISTS "admin_all_teacher_availability" ON public.teacher_availability;
CREATE POLICY "admin_all_teacher_availability" ON public.teacher_availability
  FOR ALL USING (public.get_current_user_role() = 'ADMIN');

DROP POLICY IF EXISTS "teachers_manage_own_availability" ON public.teacher_availability;
CREATE POLICY "teachers_manage_own_availability" ON public.teacher_availability
  FOR ALL USING (
    public.get_current_user_role() = 'TEACHER'
    AND lower(teacher_id) = ANY (public.my_teacher_keys())
  )
  WITH CHECK (
    public.get_current_user_role() = 'TEACHER'
    AND lower(teacher_id) = ANY (public.my_teacher_keys())
  );

DROP POLICY IF EXISTS "authenticated_view_active_teacher_availability" ON public.teacher_availability;

-- 4D. Student History Policies
DROP POLICY IF EXISTS "admin_all_student_history" ON public.student_history;
CREATE POLICY "admin_all_student_history" ON public.student_history
  FOR ALL USING (public.get_current_user_role() = 'ADMIN');

DROP POLICY IF EXISTS "students_parents_view_own_history" ON public.student_history;
CREATE POLICY "students_parents_view_own_history" ON public.student_history
  FOR SELECT USING (
    public.get_current_user_role() IN ('STUDENT', 'PARENT')
    AND EXISTS (
      SELECT 1 FROM public.students s
      WHERE (s.id::text = student_history.student_id OR s.student_id_code = student_history.student_id)
        AND (
          (public.get_current_user_role() = 'STUDENT' AND s.user_id = auth.uid())
          OR (public.get_current_user_role() = 'PARENT' AND (
               lower(auth.jwt() ->> 'email') = ANY (s.parent_emails)
             ))
        )
    )
  );

-- 4E. Leads & Lead Interactions Policies (NO public/anon insert; API uses service role)
DROP POLICY IF EXISTS "anon_insert_leads" ON public.leads;
DROP POLICY IF EXISTS "public_insert_leads" ON public.leads;
DROP POLICY IF EXISTS "allow_anon_lead_submission" ON public.leads;
DROP POLICY IF EXISTS "anyone_can_insert_leads" ON public.leads;

DROP POLICY IF EXISTS "admin_all_leads" ON public.leads;
CREATE POLICY "admin_all_leads" ON public.leads
  FOR ALL USING (public.get_current_user_role() = 'ADMIN');

DROP POLICY IF EXISTS "admin_all_lead_interactions" ON public.lead_interactions;
CREATE POLICY "admin_all_lead_interactions" ON public.lead_interactions
  FOR ALL USING (public.get_current_user_role() = 'ADMIN');

-- 4F. Enrollments Policies (NO public/anon insert; API uses service role)
DROP POLICY IF EXISTS "anon_insert_enrollments" ON public.enrollments;
DROP POLICY IF EXISTS "public_insert_enrollments" ON public.enrollments;
DROP POLICY IF EXISTS "allow_anon_enrollment_submission" ON public.enrollments;
DROP POLICY IF EXISTS "anyone_can_insert_enrollments" ON public.enrollments;

DROP POLICY IF EXISTS "admin_all_enrollments" ON public.enrollments;
CREATE POLICY "admin_all_enrollments" ON public.enrollments
  FOR ALL USING (public.get_current_user_role() = 'ADMIN');

DROP POLICY IF EXISTS "students_parents_view_own_enrollment" ON public.enrollments;
CREATE POLICY "students_parents_view_own_enrollment" ON public.enrollments
  FOR SELECT USING (
    public.get_current_user_role() IN ('STUDENT', 'PARENT')
    AND (
      lower(email) = lower(auth.jwt() ->> 'email')
      OR (student_id IS NOT NULL AND EXISTS (
            SELECT 1 FROM public.students s
            WHERE s.id::text = enrollments.student_id::text
              AND (
                s.user_id = auth.uid()
                OR lower(auth.jwt() ->> 'email') = ANY (s.parent_emails)
              )
          ))
    )
  );

-- 4G. Campaigns Policies
DROP POLICY IF EXISTS "admin_all_campaigns" ON public.campaigns;
CREATE POLICY "admin_all_campaigns" ON public.campaigns
  FOR ALL USING (public.get_current_user_role() = 'ADMIN');

-- 4H. Alert Logs Policies
DROP POLICY IF EXISTS "admin_all_alert_logs" ON public.alert_logs;
CREATE POLICY "admin_all_alert_logs" ON public.alert_logs
  FOR ALL USING (public.get_current_user_role() = 'ADMIN');

-- 4I. Tutoring & Afterschool Past Records Policies
DROP POLICY IF EXISTS "admin_all_tutoring_past" ON public.tutoring_past_records;
CREATE POLICY "admin_all_tutoring_past" ON public.tutoring_past_records
  FOR ALL USING (public.get_current_user_role() = 'ADMIN');

DROP POLICY IF EXISTS "students_parents_view_own_tutoring_past" ON public.tutoring_past_records;
CREATE POLICY "students_parents_view_own_tutoring_past" ON public.tutoring_past_records
  FOR SELECT USING (
    public.get_current_user_role() IN ('STUDENT', 'PARENT')
    AND EXISTS (
      SELECT 1 FROM public.students s
      WHERE (s.id::text = tutoring_past_records.student_id OR s.student_id_code = tutoring_past_records.student_id)
        AND (
          (public.get_current_user_role() = 'STUDENT' AND s.user_id = auth.uid())
          OR (public.get_current_user_role() = 'PARENT' AND (
               lower(auth.jwt() ->> 'email') = ANY (s.parent_emails)
             ))
        )
    )
  );

DROP POLICY IF EXISTS "admin_all_afterschool_past" ON public.afterschool_past_records;
CREATE POLICY "admin_all_afterschool_past" ON public.afterschool_past_records
  FOR ALL USING (public.get_current_user_role() = 'ADMIN');

DROP POLICY IF EXISTS "students_parents_view_own_afterschool_past" ON public.afterschool_past_records;
CREATE POLICY "students_parents_view_own_afterschool_past" ON public.afterschool_past_records
  FOR SELECT USING (
    public.get_current_user_role() IN ('STUDENT', 'PARENT')
    AND EXISTS (
      SELECT 1 FROM public.students s
      WHERE (s.id::text = afterschool_past_records.student_id OR s.student_id_code = afterschool_past_records.student_id)
        AND (
          (public.get_current_user_role() = 'STUDENT' AND s.user_id = auth.uid())
          OR (public.get_current_user_role() = 'PARENT' AND (
               lower(auth.jwt() ->> 'email') = ANY (s.parent_emails)
             ))
        )
    )
  );
