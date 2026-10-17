-- ============================================================================
-- Migration: 20261016_institute_settings.sql
-- Description: Table institute_settings (single row) with US institute defaults,
--              timezone (America/New_York), US address fields, currency (usd),
--              and RLS allowing ADMIN read and write only.
-- Safe to run multiple times.
-- ============================================================================

CREATE TABLE IF NOT EXISTS public.institute_settings (
    id TEXT PRIMARY KEY DEFAULT 'default',
    institute_name TEXT NOT NULL DEFAULT 'Top Grade Learning',
    timezone TEXT NOT NULL DEFAULT 'America/New_York',
    address_line1 TEXT NOT NULL DEFAULT '',
    address_line2 TEXT NOT NULL DEFAULT '',
    city TEXT NOT NULL DEFAULT '',
    state TEXT NOT NULL DEFAULT '',
    zip TEXT NOT NULL DEFAULT '',
    phone TEXT NOT NULL DEFAULT '',
    support_email TEXT NOT NULL DEFAULT '',
    currency TEXT NOT NULL DEFAULT 'usd',
    logo_url TEXT NOT NULL DEFAULT '',
    created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc', now()),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc', now()),
    CONSTRAINT single_institute_row CHECK (id = 'default')
);

-- Seed initial row if it doesn't already exist
INSERT INTO public.institute_settings (
    id,
    institute_name,
    timezone,
    address_line1,
    address_line2,
    city,
    state,
    zip,
    phone,
    support_email,
    currency,
    logo_url
)
VALUES (
    'default',
    'Top Grade Learning',
    'America/New_York',
    '',
    '',
    '',
    '',
    '',
    '',
    '',
    'usd',
    ''
)
ON CONFLICT (id) DO NOTHING;

-- Enable Row-Level Security
ALTER TABLE public.institute_settings ENABLE ROW LEVEL SECURITY;

-- Drop existing policies if any to ensure clean re-runs
DROP POLICY IF EXISTS institute_settings_admin_all ON public.institute_settings;
DROP POLICY IF EXISTS institute_settings_admin_select ON public.institute_settings;
DROP POLICY IF EXISTS institute_settings_admin_insert ON public.institute_settings;
DROP POLICY IF EXISTS institute_settings_admin_update ON public.institute_settings;
DROP POLICY IF EXISTS institute_settings_admin_delete ON public.institute_settings;

-- Policy: Admin read and write only. Other logins get access only through backend.
CREATE POLICY institute_settings_admin_all ON public.institute_settings
    FOR ALL
    USING (public.get_current_user_role() = 'ADMIN')
    WITH CHECK (public.get_current_user_role() = 'ADMIN');
