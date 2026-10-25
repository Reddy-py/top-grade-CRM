-- ============================================================================
-- Migration: 20261025_task16b_dual_payments_stripe_and_zelle.sql
-- Task 16b: Keep card payments (Stripe Checkout) next to Zelle.
-- 1. Adds card_enabled and zelle_enabled toggle switches to institute_settings.
-- 2. Adds dispute_status, disputed_at, refund tracking, and card metadata to token_orders.
-- 3. Adds stripe_processed_events table for idempotent webhook event deduplication.
-- ============================================================================

-- 1. Institute Settings additions for payment method controls
ALTER TABLE public.institute_settings ADD COLUMN IF NOT EXISTS card_enabled BOOLEAN DEFAULT TRUE;
ALTER TABLE public.institute_settings ADD COLUMN IF NOT EXISTS zelle_enabled BOOLEAN DEFAULT TRUE;

-- 2. Upgrade token_orders for Stripe Card metadata, refunds, and disputes
ALTER TABLE public.token_orders ADD COLUMN IF NOT EXISTS dispute_status TEXT DEFAULT 'NONE';
DO $$
BEGIN
  ALTER TABLE public.token_orders DROP CONSTRAINT IF EXISTS token_orders_dispute_status_check;
  ALTER TABLE public.token_orders ADD CONSTRAINT token_orders_dispute_status_check
    CHECK (dispute_status IN ('NONE', 'DISPUTED', 'RESOLVED', 'LOST'));
EXCEPTION WHEN OTHERS THEN
  NULL;
END $$;

ALTER TABLE public.token_orders ADD COLUMN IF NOT EXISTS disputed_at TIMESTAMPTZ;
ALTER TABLE public.token_orders ADD COLUMN IF NOT EXISTS refunded_amount NUMERIC(12, 2) DEFAULT 0;
ALTER TABLE public.token_orders ADD COLUMN IF NOT EXISTS refund_reason TEXT;
ALTER TABLE public.token_orders ADD COLUMN IF NOT EXISTS refunded_at TIMESTAMPTZ;
ALTER TABLE public.token_orders ADD COLUMN IF NOT EXISTS card_brand TEXT;
ALTER TABLE public.token_orders ADD COLUMN IF NOT EXISTS card_last4 TEXT;
ALTER TABLE public.token_orders ADD COLUMN IF NOT EXISTS stripe_payment_intent_id TEXT;
ALTER TABLE public.token_orders ADD COLUMN IF NOT EXISTS stripe_session_id TEXT;

CREATE INDEX IF NOT EXISTS token_orders_dispute_status_idx ON public.token_orders (dispute_status);
CREATE INDEX IF NOT EXISTS token_orders_stripe_session_id_idx ON public.token_orders (stripe_session_id);
CREATE INDEX IF NOT EXISTS token_orders_stripe_pi_idx ON public.token_orders (stripe_payment_intent_id);

-- 3. Stripe Processed Webhook Events Table (strictly idempotent by event_id)
CREATE TABLE IF NOT EXISTS public.stripe_processed_events (
  event_id     TEXT PRIMARY KEY,
  event_type   TEXT NOT NULL,
  processed_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS stripe_processed_events_processed_at_idx ON public.stripe_processed_events (processed_at DESC);

-- Enable RLS on stripe_processed_events (Admin / Service Role only)
ALTER TABLE public.stripe_processed_events ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS stripe_events_admin_all ON public.stripe_processed_events;
CREATE POLICY stripe_events_admin_all ON public.stripe_processed_events
  FOR ALL TO authenticated
  USING (public.get_current_user_role() = 'ADMIN')
  WITH CHECK (public.get_current_user_role() = 'ADMIN');

