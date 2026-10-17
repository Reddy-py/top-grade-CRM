-- ============================================================================
-- Migration: 20261020_growth_engagement_and_referrals.sql
-- Goal:
-- 1. Table referral_codes for unique, unguessable parent referral codes.
-- 2. Table referrals for tracking referred students, status, and manual admin reward notes.
-- 3. Enhance campaigns table with scheduling, sent/failed/unsubscribed summaries.
-- 4. Seed default email templates for engagement, welcome series, we miss you, upsell, campaigns.
-- 5. Add referred_by_code column to students and admission_requests.
-- 6. Add growth and engagement toggle columns to institute_settings.
-- Safe and idempotent to run multiple times.
-- ============================================================================

-- ---------------------------------------------------------------------------
-- 1. Table: referral_codes
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.referral_codes (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    parent_email TEXT NOT NULL,
    parent_name TEXT DEFAULT '',
    code TEXT NOT NULL UNIQUE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc', now()),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc', now())
);

CREATE INDEX IF NOT EXISTS idx_referral_codes_email ON public.referral_codes(LOWER(parent_email));
CREATE INDEX IF NOT EXISTS idx_referral_codes_code ON public.referral_codes(code);

-- Enable RLS on referral_codes
-- Rule: Referral codes cannot be guessed and are visible ONLY to the owning parent and admin.
ALTER TABLE public.referral_codes ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "admin_all_referral_codes" ON public.referral_codes;
CREATE POLICY "admin_all_referral_codes" ON public.referral_codes
    FOR ALL USING (public.get_current_user_role() = 'ADMIN');

DROP POLICY IF EXISTS "parent_own_referral_codes" ON public.referral_codes;
CREATE POLICY "parent_own_referral_codes" ON public.referral_codes
    FOR SELECT USING (
        LOWER(parent_email) = LOWER(auth.jwt() ->> 'email')
    );

-- ---------------------------------------------------------------------------
-- 2. Table: referrals
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.referrals (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    referrer_email TEXT NOT NULL,
    referrer_name TEXT DEFAULT '',
    referral_code TEXT NOT NULL,
    referred_student_id TEXT NOT NULL,
    referred_student_name TEXT DEFAULT '',
    referred_student_code TEXT DEFAULT '',
    status TEXT NOT NULL DEFAULT 'registered', -- 'registered' | 'enrolled'
    reward_notes TEXT DEFAULT '',              -- Admin manual note, no money logic
    created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc', now()),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc', now())
);

CREATE INDEX IF NOT EXISTS idx_referrals_referrer_email ON public.referrals(LOWER(referrer_email));
CREATE INDEX IF NOT EXISTS idx_referrals_code ON public.referrals(referral_code);
CREATE INDEX IF NOT EXISTS idx_referrals_student ON public.referrals(referred_student_id);

ALTER TABLE public.referrals ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "admin_all_referrals" ON public.referrals;
CREATE POLICY "admin_all_referrals" ON public.referrals
    FOR ALL USING (public.get_current_user_role() = 'ADMIN');

DROP POLICY IF EXISTS "parent_own_referrals" ON public.referrals;
CREATE POLICY "parent_own_referrals" ON public.referrals
    FOR SELECT USING (
        LOWER(referrer_email) = LOWER(auth.jwt() ->> 'email')
    );

-- ---------------------------------------------------------------------------
-- 3. Enhance students and admission_requests with referred_by_code
-- ---------------------------------------------------------------------------
ALTER TABLE public.students ADD COLUMN IF NOT EXISTS referred_by_code TEXT DEFAULT NULL;
ALTER TABLE public.admission_requests ADD COLUMN IF NOT EXISTS referred_by_code TEXT DEFAULT NULL;

-- ---------------------------------------------------------------------------
-- 4. Table: campaigns (Create or enhance)
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.campaigns (
    id TEXT PRIMARY KEY,
    title TEXT NOT NULL,
    subject TEXT NOT NULL,
    body TEXT DEFAULT '',
    target_source TEXT DEFAULT 'ALL',
    target_grade TEXT DEFAULT 'ALL',
    target_audience TEXT DEFAULT 'ALL',
    scheduled_at TIMESTAMPTZ DEFAULT NULL,
    sent_at TIMESTAMPTZ DEFAULT NULL,
    status TEXT NOT NULL DEFAULT 'Draft', -- 'Draft' | 'Scheduled' | 'Sending' | 'Completed' | 'Failed'
    recipients_count INT NOT NULL DEFAULT 0,
    sent_count INT NOT NULL DEFAULT 0,
    failed_count INT NOT NULL DEFAULT 0,
    skipped_unsubscribed_count INT NOT NULL DEFAULT 0,
    created_by TEXT DEFAULT 'admin',
    created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc', now()),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc', now())
);

ALTER TABLE public.campaigns ADD COLUMN IF NOT EXISTS target_audience TEXT DEFAULT 'ALL';
ALTER TABLE public.campaigns ADD COLUMN IF NOT EXISTS scheduled_at TIMESTAMPTZ DEFAULT NULL;
ALTER TABLE public.campaigns ADD COLUMN IF NOT EXISTS sent_count INT NOT NULL DEFAULT 0;
ALTER TABLE public.campaigns ADD COLUMN IF NOT EXISTS failed_count INT NOT NULL DEFAULT 0;
ALTER TABLE public.campaigns ADD COLUMN IF NOT EXISTS skipped_unsubscribed_count INT NOT NULL DEFAULT 0;
ALTER TABLE public.campaigns ADD COLUMN IF NOT EXISTS created_by TEXT DEFAULT 'admin';
ALTER TABLE public.campaigns ADD COLUMN IF NOT EXISTS updated_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc', now());

ALTER TABLE public.campaigns ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "admin_all_campaigns" ON public.campaigns;
CREATE POLICY "admin_all_campaigns" ON public.campaigns
    FOR ALL USING (public.get_current_user_role() = 'ADMIN');

-- ---------------------------------------------------------------------------
-- 5. Institute Settings: Growth & Engagement Toggles
-- ---------------------------------------------------------------------------
ALTER TABLE public.institute_settings ADD COLUMN IF NOT EXISTS engagement_welcome_series_enabled BOOLEAN NOT NULL DEFAULT true;
ALTER TABLE public.institute_settings ADD COLUMN IF NOT EXISTS engagement_monthly_update_enabled BOOLEAN NOT NULL DEFAULT true;
ALTER TABLE public.institute_settings ADD COLUMN IF NOT EXISTS engagement_we_miss_you_enabled BOOLEAN NOT NULL DEFAULT true;

-- ---------------------------------------------------------------------------
-- 6. Seed Email Templates for Growth, Engagement, and Upsell
-- ---------------------------------------------------------------------------
INSERT INTO public.email_templates (key, name, audience, subject, body, enabled)
VALUES
(
    'WELCOME_SERIES_WEEK_1',
    '14a. Welcome Series: Week 1 — Getting Started & Faculty Support',
    'PARENTS',
    'Welcome to {{institute_name}} — Week 1: Getting the Most Out of Classes',
    'Dear {{parent_name}},<br><br>We are thrilled to complete {{student_name}}''s first week of learning at <strong>{{institute_name}}</strong>!<br><br>Here are three quick tips to support {{student_name}}''s academic success:<br>&bull; <strong>Parent Portal:</strong> Check attendance roll-call and upcoming session times in real-time.<br>&bull; <strong>Dedicated Faculty:</strong> Your teachers prepare individualized learning plans for each student.<br>&bull; <strong>Questions?</strong> Reply directly to this email or reach our support team anytime at {{support_email}}.<br><br>Warm regards,<br>{{institute_name}} Academic Operations',
    true
),
(
    'WELCOME_SERIES_WEEK_2',
    '14b. Welcome Series: Week 2 — Study Habits & Practice Milestones',
    'PARENTS',
    '{{student_name}}''s Journey at {{institute_name}} — Week 2 Progress Check',
    'Dear {{parent_name}},<br><br>As {{student_name}} wraps up week 2 at <strong>{{institute_name}}</strong>, we want to share our appreciation for your partnership in education.<br><br>By maintaining regular attendance and completing practice assignments, students typically accelerate comprehension by up to 40%. You can log into your Parent Portal anytime to review class logs and instructor notes.<br><br>Thank you for being part of our academic family!<br><br>Warm regards,<br>{{institute_name}} Team',
    true
),
(
    'WELCOME_SERIES_WEEK_3',
    '14c. Welcome Series: Week 3 — Celebrating Milestones & Feedback',
    'PARENTS',
    'Week 3 Milestone: How Is {{student_name}} Enjoying Classes at {{institute_name}}?',
    'Dear {{parent_name}},<br><br>{{student_name}} has now completed three weeks at <strong>{{institute_name}}</strong>! We hope the learning experience has been inspiring and enriching.<br><br>We value your feedback immensely. If you have any thoughts, suggestions, or questions regarding {{student_name}}''s curriculum track or faculty mentors, please reply directly to this email.<br><br>Here is to continued academic excellence!<br><br>Warm regards,<br>{{institute_name}} Leadership',
    true
),
(
    'WE_MISS_YOU_14_DAYS',
    '15. We Miss You Notice (14 Days Inactive)',
    'PARENTS',
    'We Miss You at {{institute_name}}, {{student_name}}!',
    'Dear {{parent_name}},<br><br>We noticed it has been over 14 days since <strong>{{student_name}}</strong> attended a scheduled session at <strong>{{institute_name}}</strong>.<br><br>Consistent learning rhythm is key to long-term academic mastery and retention. We would love to welcome {{student_name}} back to the classroom!<br><br>Please sign in to the Parent Portal or reply to this message so we can assist you with scheduling, class rescheduling, or curriculum adjustments.<br><br>Warm regards,<br>{{institute_name}} Student Support Directorate',
    true
),
(
    'UPSELL_SUGGESTION',
    '16. Academic Growth & Course Upsell Suggestion',
    'PARENTS',
    'Academic Recommendation for {{student_name}}: {{suggestion_title}}',
    'Dear {{parent_name}},<br><br>Based on <strong>{{student_name}}</strong>''s recent progress and enrollment at <strong>{{institute_name}}</strong>, our academic advisory team has a tailored recommendation:<br><br><div style="background:#f0fdf4;border-left:4px solid #16a34a;padding:16px;margin:16px 0;border-radius:8px;"><strong>🎯 {{suggestion_title}}</strong><br><p style="margin:8px 0 0 0;color:#166534;line-height:1.6;">{{recommendation_text}}</p></div><br>To confirm this recommendation or explore available class slots, please reply to this email or speak with our academic directorate.<br><br>Warm regards,<br>{{institute_name}} Academic Advisory Team',
    true
),
(
    'CAMPAIGN_BROADCAST',
    '17. Campaign Broadcast Announcement',
    'ALL',
    '{{subject}}',
    'Dear {{recipient_name}},<br><br>{{campaign_body}}<br><br>For any inquiries, please contact {{institute_name}} at {{support_email}}.<br><br>Warm regards,<br>{{institute_name}} Administration',
    true
)
ON CONFLICT (key) DO UPDATE SET
    name = EXCLUDED.name,
    audience = EXCLUDED.audience,
    subject = EXCLUDED.subject,
    body = EXCLUDED.body;
