-- ============================================================================
-- Rollback: 20261020_growth_engagement_and_referrals_rollback.sql
-- ============================================================================

DROP POLICY IF EXISTS "parent_own_referrals" ON public.referrals;
DROP POLICY IF EXISTS "admin_all_referrals" ON public.referrals;
DROP TABLE IF EXISTS public.referrals;

DROP POLICY IF EXISTS "parent_own_referral_codes" ON public.referral_codes;
DROP POLICY IF EXISTS "admin_all_referral_codes" ON public.referral_codes;
DROP TABLE IF EXISTS public.referral_codes;

DROP POLICY IF EXISTS "admin_all_campaigns" ON public.campaigns;
DROP TABLE IF EXISTS public.campaigns;

ALTER TABLE public.students DROP COLUMN IF EXISTS referred_by_code;
ALTER TABLE public.admission_requests DROP COLUMN IF EXISTS referred_by_code;

ALTER TABLE public.institute_settings DROP COLUMN IF EXISTS engagement_welcome_series_enabled;
ALTER TABLE public.institute_settings DROP COLUMN IF EXISTS engagement_monthly_update_enabled;
ALTER TABLE public.institute_settings DROP COLUMN IF EXISTS engagement_we_miss_you_enabled;

DELETE FROM public.email_templates WHERE key IN (
    'WELCOME_SERIES_WEEK_1',
    'WELCOME_SERIES_WEEK_2',
    'WELCOME_SERIES_WEEK_3',
    'WE_MISS_YOU_14_DAYS',
    'UPSELL_SUGGESTION',
    'CAMPAIGN_BROADCAST'
);
