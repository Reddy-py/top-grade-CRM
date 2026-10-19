# TopGrade CRM Database Migration Run Order

This document specifies the exact migrations and their definitive execution order for fresh setups, resets (`npm run reset:supabase`), and live deployments.

---

## Complete Migration Run Order (Fresh Database & Reset Order)

For a fresh Supabase database or a schema reset (`npm run reset:supabase`), execute all 17 migrations in the exact numerical/chronological order below:

1. `supabase/migrations/20260812_rbac_setup.sql`
   - Baseline RBAC setup: core roles, permissions, initial profiles, students, teachers, courses, attendance, fees, teacher assignments.
2. `supabase/migrations/20260812_seed_test_accounts.sql`
   - Seeding helper and initial test roles.
3. `supabase/migrations/20260817_core_architecture.sql`
   - Native enum types, admissions, dossiers, leads, token wallets, token ledger.
4. `supabase/migrations/20260910_schedules_and_history.sql`
   - Early schedules, history, and lead interactions.
5. `supabase/migrations/20260914_exam_date_and_addresses.sql`
   - Student address extensions and exam dates.
6. `supabase/migrations/20261010_role_access_lockdown.sql`
   - Strict RLS lockdown: admin all, teachers own classes/roster, parents own children only, students self only.
7. `supabase/migrations/20261011_student_dossiers.sql`
   - Student dossiers table and RLS policies.
8. `supabase/migrations/20261012_email_log.sql`
   - Email dispatch log and audit trail.
9. `supabase/migrations/20261013_tokens_and_slot_claims.sql`
   - Lesson token balance tracking, token orders, and teacher open slot claims.
10. `supabase/migrations/20261014_attendance_records.sql`
    - Attendance roll-call records and daily status logging.
11. `supabase/migrations/20261015_schedules_and_single_store.sql`
    - Supabase as the single store of truth for schedules, roster mappings, and teacher availability.
12. `supabase/migrations/20261016_institute_settings.sql`
    - Singleton `institute_settings` table holding timezone, business contact, currency, and settings.
13. `supabase/migrations/20261017_hour_based_classes_and_enrollments.sql`
    - Hour-based and package course enrollments with claim-based automated expiry tracking.
14. `supabase/migrations/20261018_task4_students_teachers_courses_schedule.sql`
    - Centers and partner schools `locations` table, program types, course categories, and student notes.
15. `supabase/migrations/20261019_email_templates_and_automation.sql`
    - Seeded email templates for all 12 system events, retry tracking, email unsubscribes, and monthly progress notes.
16. `supabase/migrations/20261020_growth_engagement_and_referrals.sql`
    - Referral codes with privacy, referred student tracking, audience campaigns, and engagement sequences.
17. `supabase/migrations/20261021_task8b_hardening_and_password_change.sql`
    - Forced password change flag `must_change_password` on `public.profiles` for accounts provisioned with shared initial passwords.

---

## Verification Check Query

To verify that all tables and columns are properly configured after running all 17 migrations:

```sql
SELECT
    to_regclass('public.profiles') IS NOT NULL AS profiles_exists,
    to_regclass('public.courses') IS NOT NULL AS courses_exists,
    to_regclass('public.teachers') IS NOT NULL AS teachers_exists,
    to_regclass('public.students') IS NOT NULL AS students_exists,
    to_regclass('public.schedules') IS NOT NULL AS schedules_exists,
    to_regclass('public.locations') IS NOT NULL AS locations_exists,
    to_regclass('public.institute_settings') IS NOT NULL AS settings_exists,
    to_regclass('public.student_enrollments') IS NOT NULL AS enrollments_exists,
    to_regclass('public.email_templates') IS NOT NULL AS templates_exists,
    to_regclass('public.referral_codes') IS NOT NULL AS referrals_exists,
    EXISTS (
        SELECT 1 FROM information_schema.columns
        WHERE table_schema = 'public'
          AND table_name = 'profiles'
          AND column_name = 'must_change_password'
    ) AS must_change_password_column_exists;
```

**Expected Result**: All boolean columns return `true`.
