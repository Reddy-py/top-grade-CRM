-- ==============================================================================
-- TopGrade CRM Database Migration: 20261120_task22_automated_zelle_and_admissions.sql
-- ==============================================================================
-- TASK 22: Automated Zelle payments, low-hours and payment reminder emails,
-- admissions automations, one payable object (payment_requests), payer aliases,
-- bank feed/CSV transaction matching, and rollout safety switches.
--
-- Safe to execute multiple times (idempotent: IF NOT EXISTS, ON CONFLICT DO NOTHING).
-- Rollback file: 20261120_task22_automated_zelle_and_admissions_rollback.sql
-- ==============================================================================

BEGIN;

CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- ------------------------------------------------------------------------------
-- 1. INSTITUTE SETTINGS: Automation rollout safety switches and configuration
-- ------------------------------------------------------------------------------
ALTER TABLE public.institute_settings ADD COLUMN IF NOT EXISTS low_hours_emails BOOLEAN DEFAULT FALSE;
ALTER TABLE public.institute_settings ADD COLUMN IF NOT EXISTS payment_reminders BOOLEAN DEFAULT FALSE;
ALTER TABLE public.institute_settings ADD COLUMN IF NOT EXISTS trial_automation BOOLEAN DEFAULT FALSE;
ALTER TABLE public.institute_settings ADD COLUMN IF NOT EXISTS waitlist BOOLEAN DEFAULT FALSE;
ALTER TABLE public.institute_settings ADD COLUMN IF NOT EXISTS onboarding_chaser BOOLEAN DEFAULT FALSE;
ALTER TABLE public.institute_settings ADD COLUMN IF NOT EXISTS win_back BOOLEAN DEFAULT FALSE;
ALTER TABLE public.institute_settings ADD COLUMN IF NOT EXISTS attendance_care BOOLEAN DEFAULT FALSE;
ALTER TABLE public.institute_settings ADD COLUMN IF NOT EXISTS admin_morning_digest BOOLEAN DEFAULT FALSE;
ALTER TABLE public.institute_settings ADD COLUMN IF NOT EXISTS bank_auto_confirm BOOLEAN DEFAULT FALSE;
ALTER TABLE public.institute_settings ADD COLUMN IF NOT EXISTS bank_feed BOOLEAN DEFAULT FALSE;
ALTER TABLE public.institute_settings ADD COLUMN IF NOT EXISTS pause_all_automatic_emails BOOLEAN DEFAULT FALSE;

ALTER TABLE public.institute_settings ADD COLUMN IF NOT EXISTS low_hours_threshold INT DEFAULT 2;
ALTER TABLE public.institute_settings ADD COLUMN IF NOT EXISTS low_hours_recipients TEXT DEFAULT 'STUDENT_ELSE_PARENT';
ALTER TABLE public.institute_settings ADD COLUMN IF NOT EXISTS auto_confirm_limit INT DEFAULT 500;
ALTER TABLE public.institute_settings ADD COLUMN IF NOT EXISTS matching_date_window_days INT DEFAULT 10;
ALTER TABLE public.institute_settings ADD COLUMN IF NOT EXISTS request_expiry_days INT DEFAULT 7;
ALTER TABLE public.institute_settings ADD COLUMN IF NOT EXISTS overdue_reminders BOOLEAN DEFAULT FALSE;
ALTER TABLE public.institute_settings ADD COLUMN IF NOT EXISTS admin_notification_emails TEXT[] DEFAULT ARRAY['tglbiz101@gmail.com'];
ALTER TABLE public.institute_settings ADD COLUMN IF NOT EXISTS saved_bank_csv_mappings JSONB DEFAULT '{}'::jsonb;

-- Course-level low hours threshold override
ALTER TABLE public.courses ADD COLUMN IF NOT EXISTS low_hours_threshold INT DEFAULT NULL;

-- Schedule trial support
ALTER TABLE public.schedules ADD COLUMN IF NOT EXISTS trial_allowed BOOLEAN DEFAULT FALSE;
ALTER TABLE public.schedules ADD COLUMN IF NOT EXISTS trial_seats INT DEFAULT 1;

-- ------------------------------------------------------------------------------
-- 2. AUTOMATION PREVIEWS: Dry-run counts when automations are OFF
-- ------------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.automation_previews (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    automation_key TEXT NOT NULL,
    recipient_count INT NOT NULL DEFAULT 0,
    preview_data JSONB NOT NULL DEFAULT '{}'::jsonb,
    created_at TIMESTAMPTZ DEFAULT now()
);

ALTER TABLE public.automation_previews ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Admin full access automation_previews" ON public.automation_previews;
CREATE POLICY "Admin full access automation_previews" ON public.automation_previews
    FOR ALL TO authenticated USING (auth.jwt() ->> 'role' = 'ADMIN');

-- ------------------------------------------------------------------------------
-- 3. ONE PAYABLE OBJECT: payment_requests
-- ------------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.payment_requests (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    student_id UUID NOT NULL REFERENCES public.students(id) ON DELETE CASCADE,
    course_id TEXT NOT NULL,
    kind TEXT NOT NULL CHECK (kind IN ('PACKAGE', 'HOURS_TOPUP', 'CUSTOM')),
    hours_included INT NOT NULL DEFAULT 0,
    amount_cents INT NOT NULL CHECK (amount_cents >= 0),
    currency TEXT NOT NULL DEFAULT 'usd',
    due_date DATE NOT NULL,
    status TEXT NOT NULL DEFAULT 'OPEN' CHECK (status IN ('OPEN', 'CLAIMED', 'PAID', 'EXPIRED', 'WAIVED', 'CANCELLED', 'OVERDUE')),
    reference_code TEXT NOT NULL UNIQUE,
    created_by TEXT NOT NULL DEFAULT 'ADMIN' CHECK (created_by IN ('ADMIN', 'PARENT', 'STUDENT', 'SYSTEM')),
    created_by_user_id UUID,
    expires_at TIMESTAMPTZ,
    claimed_at TIMESTAMPTZ,
    claim_note TEXT,
    paid_at TIMESTAMPTZ,
    confirmed_by TEXT,
    confirmation_source TEXT CHECK (confirmation_source IN ('ADMIN_MANUAL', 'BANK_FILE', 'BANK_FEED')),
    bank_transaction_id UUID,
    receipt_number TEXT,
    notes TEXT,
    version INT NOT NULL DEFAULT 1,
    reminder_count INT NOT NULL DEFAULT 0,
    last_reminded_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ DEFAULT now(),
    updated_at TIMESTAMPTZ DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_payment_requests_student ON public.payment_requests(student_id);
CREATE INDEX IF NOT EXISTS idx_payment_requests_course ON public.payment_requests(course_id);
CREATE INDEX IF NOT EXISTS idx_payment_requests_status ON public.payment_requests(status);
CREATE INDEX IF NOT EXISTS idx_payment_requests_ref ON public.payment_requests(reference_code);
CREATE INDEX IF NOT EXISTS idx_payment_requests_due_date ON public.payment_requests(due_date);

ALTER TABLE public.payment_requests ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Admin full access payment_requests" ON public.payment_requests;
CREATE POLICY "Admin full access payment_requests" ON public.payment_requests
    FOR ALL TO authenticated USING (auth.jwt() ->> 'role' = 'ADMIN');

DROP POLICY IF EXISTS "Parent view own children payment_requests" ON public.payment_requests;
CREATE POLICY "Parent view own children payment_requests" ON public.payment_requests
    FOR SELECT TO authenticated
    USING (
        auth.jwt() ->> 'role' = 'PARENT' AND
        (
            student_id IN (
                SELECT sp.student_id FROM public.student_parents sp
                JOIN public.profiles p ON sp.parent_profile_id = p.id
                WHERE p.email = auth.jwt() ->> 'email'
            )
            OR
            student_id IN (
                SELECT s.id FROM public.students s
                WHERE auth.jwt() ->> 'email' = ANY(s.parent_emails)
            )
        )
    );

DROP POLICY IF EXISTS "Parent claim own children payment_requests" ON public.payment_requests;
CREATE POLICY "Parent claim own children payment_requests" ON public.payment_requests
    FOR UPDATE TO authenticated
    USING (
        auth.jwt() ->> 'role' = 'PARENT' AND
        (
            student_id IN (
                SELECT sp.student_id FROM public.student_parents sp
                JOIN public.profiles p ON sp.parent_profile_id = p.id
                WHERE p.email = auth.jwt() ->> 'email'
            )
            OR
            student_id IN (
                SELECT s.id FROM public.students s
                WHERE auth.jwt() ->> 'email' = ANY(s.parent_emails)
            )
        )
    )
    WITH CHECK (
        status = 'CLAIMED'
    );

DROP POLICY IF EXISTS "Student view own payment_requests" ON public.payment_requests;
CREATE POLICY "Student view own payment_requests" ON public.payment_requests
    FOR SELECT TO authenticated
    USING (
        auth.jwt() ->> 'role' = 'STUDENT' AND
        student_id IN (
            SELECT s.id FROM public.students s
            WHERE s.email = auth.jwt() ->> 'email'
        )
    );

-- ------------------------------------------------------------------------------
-- 4. PAYER ALIASES: Normalized Zelle sender names per parent
-- ------------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.payer_aliases (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    parent_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    alias_name TEXT NOT NULL,
    source TEXT NOT NULL CHECK (source IN ('ADMIN', 'LEARNED')),
    created_at TIMESTAMPTZ DEFAULT now(),
    UNIQUE(parent_id, alias_name)
);

CREATE INDEX IF NOT EXISTS idx_payer_aliases_parent ON public.payer_aliases(parent_id);
CREATE INDEX IF NOT EXISTS idx_payer_aliases_name ON public.payer_aliases(alias_name);

ALTER TABLE public.payer_aliases ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Admin full access payer_aliases" ON public.payer_aliases;
CREATE POLICY "Admin full access payer_aliases" ON public.payer_aliases
    FOR ALL TO authenticated USING (auth.jwt() ->> 'role' = 'ADMIN');

DROP POLICY IF EXISTS "Parent manage own payer_aliases" ON public.payer_aliases;
CREATE POLICY "Parent manage own payer_aliases" ON public.payer_aliases
    FOR ALL TO authenticated
    USING (
        auth.jwt() ->> 'role' = 'PARENT' AND parent_id = auth.uid()
    );

-- ------------------------------------------------------------------------------
-- 5. BANK TRANSACTIONS: Ingested credits and debits from CSV or Feed
-- ------------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.bank_transactions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    source TEXT NOT NULL CHECK (source IN ('CSV', 'FEED')),
    bank_txn_id TEXT,
    posted_date DATE NOT NULL,
    amount_cents INT NOT NULL,
    direction TEXT NOT NULL CHECK (direction IN ('CREDIT', 'DEBIT')),
    description TEXT NOT NULL,
    counterparty_name TEXT,
    memo TEXT,
    account_last4 TEXT,
    hash TEXT NOT NULL UNIQUE,
    matched_request_id UUID REFERENCES public.payment_requests(id) ON DELETE SET NULL,
    match_status TEXT NOT NULL DEFAULT 'UNMATCHED' CHECK (match_status IN ('UNMATCHED', 'SUGGESTED', 'MATCHED_AUTO', 'MATCHED_ADMIN', 'IGNORED', 'FLAGGED')),
    match_reasons JSONB,
    match_score INT DEFAULT 0,
    created_at TIMESTAMPTZ DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_bank_transactions_posted_date ON public.bank_transactions(posted_date);
CREATE INDEX IF NOT EXISTS idx_bank_transactions_status ON public.bank_transactions(match_status);
CREATE INDEX IF NOT EXISTS idx_bank_transactions_hash ON public.bank_transactions(hash);

ALTER TABLE public.bank_transactions ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Admin full access bank_transactions" ON public.bank_transactions;
CREATE POLICY "Admin full access bank_transactions" ON public.bank_transactions
    FOR ALL TO authenticated USING (auth.jwt() ->> 'role' = 'ADMIN');

-- ------------------------------------------------------------------------------
-- 6. AUTOMATION CLAIMS & LOW-HOURS CROSSINGS: Safe multi-worker idempotency
-- ------------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.automation_claims (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    claim_type TEXT NOT NULL,
    entity_id TEXT NOT NULL,
    claimed_date DATE NOT NULL,
    payload JSONB,
    created_at TIMESTAMPTZ DEFAULT now(),
    UNIQUE(claim_type, entity_id, claimed_date)
);

ALTER TABLE public.automation_claims ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Admin full access automation_claims" ON public.automation_claims;
CREATE POLICY "Admin full access automation_claims" ON public.automation_claims
    FOR ALL TO authenticated USING (auth.jwt() ->> 'role' = 'ADMIN');

CREATE TABLE IF NOT EXISTS public.low_hours_crossings (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    student_id UUID NOT NULL REFERENCES public.students(id) ON DELETE CASCADE,
    course_id TEXT NOT NULL,
    threshold INT NOT NULL,
    crossed_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    status TEXT NOT NULL DEFAULT 'ACTIVE' CHECK (status IN ('ACTIVE', 'REARMED')),
    last_email_at TIMESTAMPTZ,
    followup_email_at TIMESTAMPTZ,
    zero_hours_email_at TIMESTAMPTZ
);

CREATE INDEX IF NOT EXISTS idx_low_hours_crossings_student ON public.low_hours_crossings(student_id, course_id, status);

ALTER TABLE public.low_hours_crossings ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Admin full access low_hours_crossings" ON public.low_hours_crossings;
CREATE POLICY "Admin full access low_hours_crossings" ON public.low_hours_crossings
    FOR ALL TO authenticated USING (auth.jwt() ->> 'role' = 'ADMIN');

-- ------------------------------------------------------------------------------
-- 7. TRIAL BOOKINGS & WAITLIST ENTRIES: Admissions automations
-- ------------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.trial_bookings (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    schedule_id TEXT NOT NULL,
    course_id TEXT NOT NULL,
    student_name TEXT NOT NULL,
    parent_name TEXT NOT NULL,
    parent_email TEXT NOT NULL,
    parent_phone TEXT,
    booking_date DATE NOT NULL,
    status TEXT NOT NULL DEFAULT 'CONFIRMED' CHECK (status IN ('CONFIRMED', 'ATTENDED', 'NO_SHOW', 'CANCELLED', 'CONVERTED')),
    confirmation_sent_at TIMESTAMPTZ,
    reminder_24h_sent_at TIMESTAMPTZ,
    reminder_2h_sent_at TIMESTAMPTZ,
    followup_sent_at TIMESTAMPTZ,
    notes TEXT,
    created_at TIMESTAMPTZ DEFAULT now(),
    updated_at TIMESTAMPTZ DEFAULT now()
);

ALTER TABLE public.trial_bookings ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Admin full access trial_bookings" ON public.trial_bookings;
CREATE POLICY "Admin full access trial_bookings" ON public.trial_bookings
    FOR ALL TO authenticated USING (auth.jwt() ->> 'role' = 'ADMIN');

DROP POLICY IF EXISTS "Anyone can create trial_bookings" ON public.trial_bookings;
CREATE POLICY "Anyone can create trial_bookings" ON public.trial_bookings
    FOR INSERT TO anon, authenticated WITH CHECK (true);

DROP POLICY IF EXISTS "Parent view own trial_bookings" ON public.trial_bookings;
CREATE POLICY "Parent view own trial_bookings" ON public.trial_bookings
    FOR SELECT TO authenticated
    USING (
        parent_email = auth.jwt() ->> 'email'
    );

CREATE TABLE IF NOT EXISTS public.waitlist_entries (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    schedule_id TEXT NOT NULL,
    student_id UUID NOT NULL REFERENCES public.students(id) ON DELETE CASCADE,
    status TEXT NOT NULL DEFAULT 'WAITING' CHECK (status IN ('WAITING', 'OFFERED', 'ACCEPTED', 'EXPIRED', 'CANCELLED')),
    position INT NOT NULL DEFAULT 1,
    offered_at TIMESTAMPTZ,
    offer_expires_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ DEFAULT now(),
    updated_at TIMESTAMPTZ DEFAULT now()
);

ALTER TABLE public.waitlist_entries ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Admin full access waitlist_entries" ON public.waitlist_entries;
CREATE POLICY "Admin full access waitlist_entries" ON public.waitlist_entries
    FOR ALL TO authenticated USING (auth.jwt() ->> 'role' = 'ADMIN');

DROP POLICY IF EXISTS "Parent and student view own waitlist_entries" ON public.waitlist_entries;
CREATE POLICY "Parent and student view own waitlist_entries" ON public.waitlist_entries
    FOR SELECT TO authenticated
    USING (
        student_id IN (
            SELECT s.id FROM public.students s
            WHERE s.email = auth.jwt() ->> 'email'
               OR auth.jwt() ->> 'email' = ANY(s.parent_emails)
        )
    );

-- ------------------------------------------------------------------------------
-- 8. DATA MIGRATION: Migrate legacy fee_dues and token_orders into payment_requests
-- ------------------------------------------------------------------------------
DO $$
BEGIN
    -- Check if fee_dues table exists
    IF EXISTS (SELECT FROM pg_tables WHERE schemaname = 'public' AND tablename = 'fee_dues') THEN
        INSERT INTO public.payment_requests (
            id,
            student_id,
            course_id,
            kind,
            hours_included,
            amount_cents,
            currency,
            due_date,
            status,
            reference_code,
            created_by,
            paid_at,
            receipt_number,
            notes,
            created_at,
            updated_at
        )
        SELECT
            fd.id,
            fd.student_id,
            fd.course_id::text,
            'CUSTOM',
            COALESCE(fd.hours_included, 0),
            ROUND(COALESCE(fd.amount, 0) * 100)::INT,
            'usd',
            fd.due_date,
            CASE
                WHEN fd.status = 'PAID' THEN 'PAID'
                WHEN fd.status = 'OVERDUE' THEN 'OVERDUE'
                WHEN fd.status = 'WAIVED' THEN 'WAIVED'
                WHEN fd.status = 'CANCELLED' THEN 'CANCELLED'
                ELSE 'OPEN'
            END,
            fd.due_reference,
            'ADMIN',
            fd.paid_at,
            fd.receipt_number,
            fd.notes,
            COALESCE(fd.created_at, now()),
            COALESCE(fd.updated_at, now())
        FROM public.fee_dues fd
        ON CONFLICT (reference_code) DO NOTHING;
    END IF;

    -- Check if token_orders table exists
    IF EXISTS (SELECT FROM pg_tables WHERE schemaname = 'public' AND tablename = 'token_orders') THEN
        INSERT INTO public.payment_requests (
            student_id,
            course_id,
            kind,
            hours_included,
            amount_cents,
            currency,
            due_date,
            status,
            reference_code,
            created_by,
            paid_at,
            created_at,
            updated_at
        )
        SELECT
            torders.student_id,
            torders.course_id,
            'HOURS_TOPUP',
            COALESCE(torders.quantity, 0),
            ROUND(COALESCE(torders.amount_total, 0) * 100)::INT,
            COALESCE(torders.currency, 'usd'),
            COALESCE(torders.created_at::date, CURRENT_DATE),
            CASE
                WHEN torders.status = 'PAID' THEN 'PAID'
                WHEN torders.status = 'FAILED' THEN 'CANCELLED'
                WHEN torders.status = 'CANCELLED' THEN 'CANCELLED'
                ELSE 'OPEN'
            END,
            'TG-' || UPPER(SUBSTRING(MD5(torders.id::text) FROM 1 FOR 6)),
            'PARENT',
            CASE WHEN torders.status = 'PAID' THEN torders.created_at ELSE NULL END,
            COALESCE(torders.created_at, now()),
            COALESCE(torders.created_at, now())
        FROM public.token_orders torders
        WHERE torders.student_id IS NOT NULL
        ON CONFLICT (reference_code) DO NOTHING;
    END IF;
END $$;

COMMIT;
