-- ============================================================================
-- Rollback Migration: 20261025_task16_zelle_payment_reconciliation_rollback.sql
-- Description: Reverses the Task 16 Zelle payment reconciliation migration.
-- ============================================================================

DROP FUNCTION IF EXISTS public.zelle_confirm_order(UUID, UUID, TEXT, NUMERIC, TEXT, INT, TEXT, BOOLEAN);

DROP POLICY IF EXISTS bank_transactions_admin_all ON public.bank_transactions;

ALTER TABLE IF EXISTS public.token_orders DROP CONSTRAINT IF EXISTS token_orders_bank_transaction_id_fkey;
ALTER TABLE IF EXISTS public.bank_transactions DROP CONSTRAINT IF EXISTS bank_transactions_matched_order_id_fkey;

DROP TABLE IF EXISTS public.bank_transactions CASCADE;

DROP INDEX IF EXISTS token_orders_reference_code_idx;
DROP INDEX IF EXISTS token_orders_status_idx;
DROP INDEX IF EXISTS token_orders_expires_at_idx;

ALTER TABLE public.token_orders DROP COLUMN IF EXISTS reference_code;
ALTER TABLE public.token_orders DROP COLUMN IF EXISTS expires_at;
ALTER TABLE public.token_orders DROP COLUMN IF EXISTS bank_transaction_id;
ALTER TABLE public.token_orders DROP COLUMN IF EXISTS confirmed_by;
ALTER TABLE public.token_orders DROP COLUMN IF EXISTS confirmed_at;
ALTER TABLE public.token_orders DROP COLUMN IF EXISTS amount_received;
ALTER TABLE public.token_orders DROP COLUMN IF EXISTS mismatch_note;
ALTER TABLE public.token_orders DROP COLUMN IF EXISTS plan;

ALTER TABLE public.institute_settings DROP COLUMN IF EXISTS zelle_display_name;
ALTER TABLE public.institute_settings DROP COLUMN IF EXISTS zelle_tag;
ALTER TABLE public.institute_settings DROP COLUMN IF EXISTS zelle_email;
ALTER TABLE public.institute_settings DROP COLUMN IF EXISTS zelle_phone;
ALTER TABLE public.institute_settings DROP COLUMN IF EXISTS payment_instructions_note;
ALTER TABLE public.institute_settings DROP COLUMN IF EXISTS pending_order_expiry_days;
ALTER TABLE public.institute_settings DROP COLUMN IF EXISTS auto_confirm_strong_matches;
ALTER TABLE public.institute_settings DROP COLUMN IF EXISTS saved_bank_csv_mapping;
