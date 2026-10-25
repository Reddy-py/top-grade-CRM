-- ============================================================================
-- Migration Rollback: 20261025_task16b_dual_payments_stripe_and_zelle_rollback.sql
-- ============================================================================

DROP TABLE IF EXISTS public.stripe_processed_events CASCADE;

ALTER TABLE public.token_orders DROP COLUMN IF EXISTS stripe_session_id;
ALTER TABLE public.token_orders DROP COLUMN IF EXISTS stripe_payment_intent_id;
ALTER TABLE public.token_orders DROP COLUMN IF EXISTS card_last4;
ALTER TABLE public.token_orders DROP COLUMN IF EXISTS card_brand;
ALTER TABLE public.token_orders DROP COLUMN IF EXISTS refunded_at;
ALTER TABLE public.token_orders DROP COLUMN IF EXISTS refund_reason;
ALTER TABLE public.token_orders DROP COLUMN IF EXISTS refunded_amount;
ALTER TABLE public.token_orders DROP COLUMN IF EXISTS disputed_at;
ALTER TABLE public.token_orders DROP COLUMN IF EXISTS dispute_status;

ALTER TABLE public.institute_settings DROP COLUMN IF EXISTS zelle_enabled;
ALTER TABLE public.institute_settings DROP COLUMN IF EXISTS card_enabled;
