-- ==============================================================================
-- TopGrade CRM Database Migration: 20261119_task21_client_fixes_fees_zelle.sql
-- ==============================================================================
-- TASK 21: Client meeting fixes, fee dues with automatic reminders, Zelle payments,
-- duplicate guarantees, student exam dates, and deployment parity tables.
--
-- Safe to execute multiple times (idempotent: IF NOT EXISTS, ON CONFLICT DO NOTHING).
-- Rollback file: 20261119_task21_client_fixes_fees_zelle_rollback.sql
-- ==============================================================================

BEGIN;

-- ------------------------------------------------------------------------------
-- 1. DEPLOYMENT PARITY: Add missing columns and tables to ensure schema parity
-- ------------------------------------------------------------------------------

-- Ensure updated_at exists on courses
ALTER TABLE public.courses ADD COLUMN IF NOT EXISTS updated_at TIMESTAMPTZ DEFAULT now();
ALTER TABLE public.courses ADD COLUMN IF NOT EXISTS class_length INTEGER DEFAULT 1;

-- Ensure starts_on and starts_at exist on student_enrollments
ALTER TABLE public.student_enrollments ADD COLUMN IF NOT EXISTS starts_on DATE DEFAULT CURRENT_DATE;
ALTER TABLE public.student_enrollments ADD COLUMN IF NOT EXISTS starts_at TIMESTAMPTZ DEFAULT now();

-- Ensure daily_job_claims exists for safe single-run daily jobs (reminders, sweeps)
CREATE TABLE IF NOT EXISTS public.daily_job_claims (
    job_name TEXT NOT NULL,
    claim_date DATE NOT NULL,
    claimed_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    claimed_by TEXT,
    PRIMARY KEY (job_name, claim_date)
);

-- Ensure schedules table exists (canonical single store for slots)
CREATE TABLE IF NOT EXISTS public.schedules (
    id TEXT PRIMARY KEY,
    course_id TEXT,
    course_name TEXT,
    teacher_id TEXT,
    teacher_name TEXT,
    day_of_week TEXT,
    start_time TEXT,
    end_time TEXT,
    time_slot TEXT,
    duration_hours NUMERIC DEFAULT 1,
    max_capacity INTEGER DEFAULT 15,
    room TEXT DEFAULT 'Room 101',
    notes TEXT DEFAULT '',
    location TEXT DEFAULT 'Main Academic Center',
    grade_range TEXT DEFAULT 'All Grades',
    start_at TIMESTAMPTZ,
    end_at TIMESTAMPTZ,
    status TEXT DEFAULT 'active',
    is_active BOOLEAN DEFAULT TRUE,
    open_for_teachers BOOLEAN DEFAULT FALSE,
    program TEXT DEFAULT 'TUTORING',
    created_at TIMESTAMPTZ DEFAULT now(),
    updated_at TIMESTAMPTZ DEFAULT now()
);

-- ------------------------------------------------------------------------------
-- 2. PART 2: DUPLICATE GUARANTEES (Parent Profiles and Student Records)
-- ------------------------------------------------------------------------------

-- Guarantee unique lower(email) per login in public.profiles
CREATE UNIQUE INDEX IF NOT EXISTS idx_profiles_lower_email ON public.profiles (lower(trim(email)));

-- Guarantee unique (student_id, parent_id) in student_parents
CREATE TABLE IF NOT EXISTS public.student_parents (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    student_id TEXT NOT NULL,
    parent_id TEXT NOT NULL,
    created_at TIMESTAMPTZ DEFAULT now(),
    CONSTRAINT uq_student_parent_pair UNIQUE (student_id, parent_id)
);

CREATE INDEX IF NOT EXISTS idx_student_parents_student ON public.student_parents(student_id);
CREATE INDEX IF NOT EXISTS idx_student_parents_parent ON public.student_parents(parent_id);

-- ------------------------------------------------------------------------------
-- 3. PART 5: STUDENT EXAM DATES (1-to-1 personal exam schedules)
-- ------------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS public.student_exam_dates (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    student_id TEXT NOT NULL,
    course_id TEXT,
    course_name TEXT,
    exam_date DATE NOT NULL,
    notes TEXT,
    created_by TEXT,
    created_at TIMESTAMPTZ DEFAULT now(),
    updated_at TIMESTAMPTZ DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_student_exam_dates_student ON public.student_exam_dates(student_id);
CREATE INDEX IF NOT EXISTS idx_student_exam_dates_date ON public.student_exam_dates(exam_date);

-- Migrate legacy exam dates stored in students.medical_notes or students.exam_date
DO $$
BEGIN
    IF EXISTS (
        SELECT 1 FROM information_schema.columns
        WHERE table_schema = 'public' AND table_name = 'students' AND column_name = 'medical_notes'
    ) THEN
        INSERT INTO public.student_exam_dates (student_id, exam_date, notes, created_by)
        SELECT 
            s.id,
            SUBSTRING(s.medical_notes FROM 'EXAM_DATE:([0-9]{4}-[0-9]{2}-[0-9]{2})')::DATE,
            'Migrated from medical_notes',
            'system_migration'
        FROM public.students s
        WHERE s.medical_notes LIKE 'EXAM_DATE:%'
          AND SUBSTRING(s.medical_notes FROM 'EXAM_DATE:([0-9]{4}-[0-9]{2}-[0-9]{2})') IS NOT NULL
        ON CONFLICT DO NOTHING;
    END IF;
END $$;

-- ------------------------------------------------------------------------------
-- 4. PART 6 & 7: FEE DUES, REMINDERS & ZELLE PAYMENT CLAIMS
-- ------------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS public.fee_dues (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    student_id TEXT NOT NULL,
    student_name TEXT,
    student_code TEXT,
    parent_email TEXT,
    course_id TEXT,
    course_name TEXT,
    amount_dollars NUMERIC(10, 2) NOT NULL DEFAULT 0.00,
    currency TEXT DEFAULT 'USD',
    due_date DATE NOT NULL,
    status TEXT NOT NULL DEFAULT 'UPCOMING', -- 'UPCOMING', 'REMINDED_1', 'REMINDED_2', 'PAID', 'WAIVED', 'CANCELLED', 'OVERDUE'
    invoice_ref TEXT UNIQUE NOT NULL,       -- TG-YYYYMM-XXXX
    notes TEXT,
    paid_at TIMESTAMPTZ,
    payment_method TEXT,                    -- 'zelle', 'bank_transfer_neft', 'cash', 'cheque', 'other'
    bank_reference TEXT,
    hours_credited NUMERIC DEFAULT 0,
    created_at TIMESTAMPTZ DEFAULT now(),
    updated_at TIMESTAMPTZ DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_fee_dues_student ON public.fee_dues(student_id);
CREATE INDEX IF NOT EXISTS idx_fee_dues_status ON public.fee_dues(status);
CREATE INDEX IF NOT EXISTS idx_fee_dues_due_date ON public.fee_dues(due_date);
CREATE INDEX IF NOT EXISTS idx_fee_dues_invoice_ref ON public.fee_dues(invoice_ref);

-- Table for Zelle and parent-reported payment claims awaiting admin verification
CREATE TABLE IF NOT EXISTS public.fee_due_claims (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    fee_due_id UUID REFERENCES public.fee_dues(id) ON DELETE CASCADE,
    student_id TEXT NOT NULL,
    parent_email TEXT NOT NULL,
    amount NUMERIC(10, 2) NOT NULL,
    zelle_memo TEXT,
    claim_timestamp TIMESTAMPTZ DEFAULT now(),
    status TEXT DEFAULT 'PENDING_VERIFICATION', -- 'PENDING_VERIFICATION', 'VERIFIED', 'REJECTED'
    verified_by TEXT,
    verified_at TIMESTAMPTZ,
    notes TEXT
);

CREATE INDEX IF NOT EXISTS idx_fee_due_claims_fee ON public.fee_due_claims(fee_due_id);
CREATE INDEX IF NOT EXISTS idx_fee_due_claims_status ON public.fee_due_claims(status);

-- Ensure Zelle configuration columns exist in institute_settings
ALTER TABLE public.institute_settings ADD COLUMN IF NOT EXISTS zelle_recipient_email TEXT DEFAULT 'billing@topgrade.org';
ALTER TABLE public.institute_settings ADD COLUMN IF NOT EXISTS zelle_recipient_phone TEXT DEFAULT '+1 (312) 555-0199';
ALTER TABLE public.institute_settings ADD COLUMN IF NOT EXISTS zelle_business_name TEXT DEFAULT 'Top Grade Learning LLC';
ALTER TABLE public.institute_settings ADD COLUMN IF NOT EXISTS zelle_payment_instructions TEXT DEFAULT 'Please include your TG-XXXXXX invoice reference in the Zelle memo field.';
ALTER TABLE public.institute_settings ADD COLUMN IF NOT EXISTS card_payments_enabled BOOLEAN DEFAULT FALSE;

-- ------------------------------------------------------------------------------
-- 5. ROW LEVEL SECURITY (RLS) & STRICT FOUR-ROLE POLICIES
-- ------------------------------------------------------------------------------

ALTER TABLE public.schedules ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.daily_job_claims ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.student_parents ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.student_exam_dates ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.fee_dues ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.fee_due_claims ENABLE ROW LEVEL SECURITY;

-- Helper to safely drop existing policies before recreation
DO $$
BEGIN
    DROP POLICY IF EXISTS schedules_admin_all ON public.schedules;
    DROP POLICY IF EXISTS schedules_teacher_read ON public.schedules;
    DROP POLICY IF EXISTS schedules_parent_student_read ON public.schedules;
    
    DROP POLICY IF EXISTS daily_job_claims_admin_all ON public.daily_job_claims;
    
    DROP POLICY IF EXISTS student_parents_admin_all ON public.student_parents;
    DROP POLICY IF EXISTS student_parents_parent_read ON public.student_parents;
    
    DROP POLICY IF EXISTS student_exam_dates_admin_all ON public.student_exam_dates;
    DROP POLICY IF EXISTS student_exam_dates_teacher_read ON public.student_exam_dates;
    DROP POLICY IF EXISTS student_exam_dates_parent_read ON public.student_exam_dates;
    DROP POLICY IF EXISTS student_exam_dates_student_read ON public.student_exam_dates;
    
    DROP POLICY IF EXISTS fee_dues_admin_all ON public.fee_dues;
    DROP POLICY IF EXISTS fee_dues_parent_read ON public.fee_dues;
    DROP POLICY IF EXISTS fee_dues_student_read ON public.fee_dues;
    
    DROP POLICY IF EXISTS fee_due_claims_admin_all ON public.fee_due_claims;
    DROP POLICY IF EXISTS fee_due_claims_parent_insert_read ON public.fee_due_claims;
END $$;

-- Policies for schedules
CREATE POLICY schedules_admin_all ON public.schedules
    FOR ALL TO authenticated
    USING (EXISTS (SELECT 1 FROM public.profiles WHERE id = auth.uid() AND role = 'ADMIN'))
    WITH CHECK (EXISTS (SELECT 1 FROM public.profiles WHERE id = auth.uid() AND role = 'ADMIN'));

CREATE POLICY schedules_teacher_read ON public.schedules
    FOR SELECT TO authenticated
    USING (
        EXISTS (SELECT 1 FROM public.profiles WHERE id = auth.uid() AND role = 'TEACHER')
    );

CREATE POLICY schedules_parent_student_read ON public.schedules
    FOR SELECT TO authenticated
    USING (
        EXISTS (SELECT 1 FROM public.profiles WHERE id = auth.uid() AND role IN ('PARENT', 'STUDENT'))
    );

-- Policies for daily_job_claims
CREATE POLICY daily_job_claims_admin_all ON public.daily_job_claims
    FOR ALL TO authenticated
    USING (EXISTS (SELECT 1 FROM public.profiles WHERE id = auth.uid() AND role = 'ADMIN'))
    WITH CHECK (EXISTS (SELECT 1 FROM public.profiles WHERE id = auth.uid() AND role = 'ADMIN'));

-- Policies for student_parents
CREATE POLICY student_parents_admin_all ON public.student_parents
    FOR ALL TO authenticated
    USING (EXISTS (SELECT 1 FROM public.profiles WHERE id = auth.uid() AND role = 'ADMIN'))
    WITH CHECK (EXISTS (SELECT 1 FROM public.profiles WHERE id = auth.uid() AND role = 'ADMIN'));

CREATE POLICY student_parents_parent_read ON public.student_parents
    FOR SELECT TO authenticated
    USING (parent_id = auth.uid()::TEXT);

-- Policies for student_exam_dates
CREATE POLICY student_exam_dates_admin_all ON public.student_exam_dates
    FOR ALL TO authenticated
    USING (EXISTS (SELECT 1 FROM public.profiles WHERE id = auth.uid() AND role = 'ADMIN'))
    WITH CHECK (EXISTS (SELECT 1 FROM public.profiles WHERE id = auth.uid() AND role = 'ADMIN'));

CREATE POLICY student_exam_dates_teacher_read ON public.student_exam_dates
    FOR SELECT TO authenticated
    USING (EXISTS (SELECT 1 FROM public.profiles WHERE id = auth.uid() AND role = 'TEACHER'));

CREATE POLICY student_exam_dates_parent_read ON public.student_exam_dates
    FOR SELECT TO authenticated
    USING (
        EXISTS (
            SELECT 1 FROM public.students s
            WHERE s.id = student_exam_dates.student_id
              AND (
                  s.parent_emails @> ARRAY[lower(trim(auth.jwt() ->> 'email'))]
                  OR s.father_name ILIKE (SELECT full_name FROM public.profiles WHERE id = auth.uid())
              )
        )
    );

CREATE POLICY student_exam_dates_student_read ON public.student_exam_dates
    FOR SELECT TO authenticated
    USING (
        EXISTS (
            SELECT 1 FROM public.students s
            WHERE s.id = student_exam_dates.student_id
              AND (
                  s.user_id = auth.uid()
                  OR lower(trim(s.email)) = lower(trim(auth.jwt() ->> 'email'))
              )
        )
    );

-- Policies for fee_dues
CREATE POLICY fee_dues_admin_all ON public.fee_dues
    FOR ALL TO authenticated
    USING (EXISTS (SELECT 1 FROM public.profiles WHERE id = auth.uid() AND role = 'ADMIN'))
    WITH CHECK (EXISTS (SELECT 1 FROM public.profiles WHERE id = auth.uid() AND role = 'ADMIN'));

CREATE POLICY fee_dues_parent_read ON public.fee_dues
    FOR SELECT TO authenticated
    USING (
        lower(trim(parent_email)) = lower(trim(auth.jwt() ->> 'email'))
        OR EXISTS (
            SELECT 1 FROM public.students s
            WHERE s.id = fee_dues.student_id
              AND s.parent_emails @> ARRAY[lower(trim(auth.jwt() ->> 'email'))]
        )
    );

CREATE POLICY fee_dues_student_read ON public.fee_dues
    FOR SELECT TO authenticated
    USING (
        EXISTS (
            SELECT 1 FROM public.students s
            WHERE s.id = fee_dues.student_id
              AND (
                  s.user_id = auth.uid()
                  OR lower(trim(s.email)) = lower(trim(auth.jwt() ->> 'email'))
              )
        )
    );

-- Policies for fee_due_claims
CREATE POLICY fee_due_claims_admin_all ON public.fee_due_claims
    FOR ALL TO authenticated
    USING (EXISTS (SELECT 1 FROM public.profiles WHERE id = auth.uid() AND role = 'ADMIN'))
    WITH CHECK (EXISTS (SELECT 1 FROM public.profiles WHERE id = auth.uid() AND role = 'ADMIN'));

CREATE POLICY fee_due_claims_parent_insert_read ON public.fee_due_claims
    FOR ALL TO authenticated
    USING (lower(trim(parent_email)) = lower(trim(auth.jwt() ->> 'email')))
    WITH CHECK (lower(trim(parent_email)) = lower(trim(auth.jwt() ->> 'email')));

COMMIT;

