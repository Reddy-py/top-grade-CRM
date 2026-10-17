# Live Database Migration Run Order

This document specifies the exact migrations to apply to the live production database (`topgrade-crm`).

---

## ⚠️ CRITICAL WARNING: DO NOT RE-RUN 20261010 TO 20261014

> **DO NOT** re-run migrations `20261010` to `20261014` on the live database!
> Migration `20261010_role_access_lockdown.sql` contains statements that drop existing RLS policies (`DROP POLICY IF EXISTS ...`), which will disrupt active security policies and table permissions on the live system.
> The live database already has baseline RBAC, dossiers, email log, token ledger, and attendance tables configured.

---

## Exact Live Migrations in Run Order

Run ONLY the following three migrations in the exact order listed below:

### 1. `supabase/migrations/20261015_schedules_and_single_store.sql`
- **Purpose**: Establishes Supabase as the single store of truth for schedules, student-schedule mappings, teacher availability, and lead interactions. Preserves data by safely casting UUIDs to TEXT without table drops.
- **Check Query**:
  ```sql
  SELECT 
      to_regclass('public.schedules') IS NOT NULL AS schedules_table_exists,
      to_regclass('public.schedule_students') IS NOT NULL AS schedule_students_table_exists,
      to_regclass('public.teacher_availability') IS NOT NULL AS teacher_availability_exists;
  ```
- **Expected Result**:
  All three boolean columns return `true`.

---

### 2. `supabase/migrations/20261016_institute_settings.sql`
- **Purpose**: Installs singleton `public.institute_settings` table holding timezone, business address, phone, support email, currency, and curriculum categories/program types. Enforces ADMIN-only modification with secure public reading of non-sensitive contact fields.
- **Check Query**:
  ```sql
  SELECT id, institute_name, timezone, currency 
  FROM public.institute_settings 
  WHERE id = 'default';
  ```
- **Expected Result**:
  Returns exactly 1 row with `id = 'default'`, `institute_name = 'Top Grade Learning'`, `timezone = 'America/New_York'`, `currency = 'usd'`.

---

### 3. `supabase/migrations/20261017_hour_based_classes_and_enrollments.sql`
- **Purpose**: Adds `duration_months`, `package_hours`, `package_price`, and `hourly_rate` columns to `public.courses` with `DEFAULT NULL`. Creates `public.student_enrollments` table for tracking hourly and package enrollments with automated claim-based expiry. Backfills rates from `course_material` and migrates student course relationships into enrollments.
- **Check Query**:
  ```sql
  SELECT 
      column_name, 
      column_default, 
      is_nullable
  FROM information_schema.columns
  WHERE table_schema = 'public'
    AND table_name = 'courses'
    AND column_name IN ('duration_months', 'package_hours', 'package_price', 'hourly_rate')
  ORDER BY column_name;
  ```
- **Check Query 2**:
  ```sql
  SELECT 
      to_regclass('public.student_enrollments') IS NOT NULL AS enrollments_table_exists,
      (SELECT COUNT(*) FROM public.courses WHERE duration_months IS NOT NULL OR hourly_rate IS NOT NULL) AS configured_courses;
  ```
- **Expected Result**:
  - Query 1: Shows all 4 columns exist with `column_default IS NULL` (or `DEFAULT NULL`).
  - Query 2: `enrollments_table_exists = true`, and `configured_courses >= 0`.

---

### 4. `supabase/migrations/20261018_locations_and_history.sql`
- **Purpose**: Creates `public.locations` table for managed facilities (CENTERS and partner SCHOOLS) with addresses; adds `program_type` column to schedules and students; establishes student and teacher history tracking.
- **Check Query**:
  ```sql
  SELECT 
      to_regclass('public.locations') IS NOT NULL AS locations_table_exists,
      to_regclass('public.student_history') IS NOT NULL AS student_history_exists;
  ```
- **Expected Result**:
  Both boolean columns return `true`.

---

### 5. `supabase/migrations/20261019_email_templates_and_automation.sql`
- **Purpose**: Establishes `public.email_templates` seeded with default templates for all 12 events; enhances `public.email_log` with retry tracking (`retry_count`, `next_retry_at`, `body_preview`, `metadata`); creates `public.email_unsubscribes` for CAN-SPAM one-click unsubscribe links; creates `public.student_monthly_notes` for teacher monthly progress notes per student/course.
- **Check Query**:
  ```sql
  SELECT 
      to_regclass('public.email_templates') IS NOT NULL AS templates_table_exists,
      to_regclass('public.email_unsubscribes') IS NOT NULL AS unsubscribes_table_exists,
      to_regclass('public.student_monthly_notes') IS NOT NULL AS monthly_notes_table_exists,
      (SELECT COUNT(*) FROM public.email_templates) AS seeded_templates_count;
  ```
- **Expected Result**:
  - `templates_table_exists = true`
  - `unsubscribes_table_exists = true`
  - `monthly_notes_table_exists = true`
  - `seeded_templates_count >= 14`

---

### 6. `supabase/migrations/20261020_growth_engagement_and_referrals.sql`
- **Purpose**: Establishes `public.referral_codes` with RLS privacy (owning parent & admin only); `public.referrals` for referred student tracking and manual reward notes; enhances `public.campaigns` with audience segmentation, scheduling, and sent/failed/unsubscribed summaries; adds `referred_by_code` to students; adds growth engagement toggles to institute settings; seeds templates for welcome series (weeks 1-3), we miss you (14 days), upsell suggestions, and campaign broadcasts.
- **Check Query**:
  ```sql
  SELECT 
      to_regclass('public.referral_codes') IS NOT NULL AS referral_codes_table_exists,
      to_regclass('public.referrals') IS NOT NULL AS referrals_table_exists,
      to_regclass('public.campaigns') IS NOT NULL AS campaigns_table_exists,
      (SELECT COUNT(*) FROM public.email_templates WHERE key IN ('WELCOME_SERIES_WEEK_1', 'WE_MISS_YOU_14_DAYS', 'UPSELL_SUGGESTION')) AS growth_templates_count;
  ```
- **Expected Result**:
  - `referral_codes_table_exists = true`
  - `referrals_table_exists = true`
  - `campaigns_table_exists = true`
  - `growth_templates_count >= 3`

