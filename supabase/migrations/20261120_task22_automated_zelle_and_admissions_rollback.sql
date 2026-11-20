-- ==============================================================================
-- TopGrade CRM Database Migration Rollback: 20261120_task22_automated_zelle_and_admissions_rollback.sql
-- ==============================================================================

BEGIN;

DROP TABLE IF EXISTS public.waitlist_entries CASCADE;
DROP TABLE IF EXISTS public.trial_bookings CASCADE;
DROP TABLE IF EXISTS public.low_hours_crossings CASCADE;
DROP TABLE IF EXISTS public.automation_claims CASCADE;
DROP TABLE IF EXISTS public.bank_transactions CASCADE;
DROP TABLE IF EXISTS public.payer_aliases CASCADE;
DROP TABLE IF EXISTS public.payment_requests CASCADE;
DROP TABLE IF EXISTS public.automation_previews CASCADE;

ALTER TABLE public.schedules DROP COLUMN IF EXISTS trial_allowed;
ALTER TABLE public.schedules DROP COLUMN IF EXISTS trial_seats;
ALTER TABLE public.courses DROP COLUMN IF EXISTS low_hours_threshold;

ALTER TABLE public.institute_settings DROP COLUMN IF EXISTS low_hours_emails;
ALTER TABLE public.institute_settings DROP COLUMN IF EXISTS payment_reminders;
ALTER TABLE public.institute_settings DROP COLUMN IF EXISTS trial_automation;
ALTER TABLE public.institute_settings DROP COLUMN IF EXISTS waitlist;
ALTER TABLE public.institute_settings DROP COLUMN IF EXISTS onboarding_chaser;
ALTER TABLE public.institute_settings DROP COLUMN IF EXISTS win_back;
ALTER TABLE public.institute_settings DROP COLUMN IF EXISTS attendance_care;
ALTER TABLE public.institute_settings DROP COLUMN IF EXISTS admin_morning_digest;
ALTER TABLE public.institute_settings DROP COLUMN IF EXISTS bank_auto_confirm;
ALTER TABLE public.institute_settings DROP COLUMN IF EXISTS bank_feed;
ALTER TABLE public.institute_settings DROP COLUMN IF EXISTS pause_all_automatic_emails;
ALTER TABLE public.institute_settings DROP COLUMN IF EXISTS low_hours_threshold;
ALTER TABLE public.institute_settings DROP COLUMN IF EXISTS low_hours_recipients;
ALTER TABLE public.institute_settings DROP COLUMN IF EXISTS auto_confirm_limit;
ALTER TABLE public.institute_settings DROP COLUMN IF EXISTS matching_date_window_days;
ALTER TABLE public.institute_settings DROP COLUMN IF EXISTS request_expiry_days;
ALTER TABLE public.institute_settings DROP COLUMN IF EXISTS overdue_reminders;
ALTER TABLE public.institute_settings DROP COLUMN IF EXISTS admin_notification_emails;
ALTER TABLE public.institute_settings DROP COLUMN IF EXISTS saved_bank_csv_mappings;

COMMIT;
