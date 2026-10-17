-- ============================================================================
-- Rollback Migration: 20261016_institute_settings_rollback.sql
-- ============================================================================

DROP POLICY IF EXISTS institute_settings_admin_all ON public.institute_settings;
DROP POLICY IF EXISTS institute_settings_admin_select ON public.institute_settings;
DROP POLICY IF EXISTS institute_settings_admin_insert ON public.institute_settings;
DROP POLICY IF EXISTS institute_settings_admin_update ON public.institute_settings;
DROP POLICY IF EXISTS institute_settings_admin_delete ON public.institute_settings;

DROP TABLE IF EXISTS public.institute_settings;
