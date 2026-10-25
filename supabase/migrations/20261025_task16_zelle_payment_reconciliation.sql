-- ============================================================================
-- Migration: 20261025_task16_zelle_payment_reconciliation.sql
-- Goal:
-- 1. Add Zelle configuration fields to institute_settings.
-- 2. Upgrade token_orders for bank-verified Zelle reconciliation (reference_code,
--    expires_at, bank_transaction_id, confirmed_by, confirmed_at, amount_received,
--    mismatch_note, plan, and updated status constraint).
-- 3. Create bank_transactions table with deduplication constraints, safe parsing storage,
--    and admin-only RLS.
-- 4. Create atomic database function for order confirmation & hour credit.
-- Idempotency: Safe to run multiple times.
-- ============================================================================

-- 1. Institute Settings additions for Zelle
ALTER TABLE public.institute_settings ADD COLUMN IF NOT EXISTS zelle_display_name TEXT DEFAULT 'Top Grade Learning LLC';
ALTER TABLE public.institute_settings ADD COLUMN IF NOT EXISTS zelle_tag TEXT DEFAULT '';
ALTER TABLE public.institute_settings ADD COLUMN IF NOT EXISTS zelle_email TEXT DEFAULT 'billing@topgradelearning.com';
ALTER TABLE public.institute_settings ADD COLUMN IF NOT EXISTS zelle_phone TEXT DEFAULT '';
ALTER TABLE public.institute_settings ADD COLUMN IF NOT EXISTS payment_instructions_note TEXT DEFAULT 'Pay in your bank app using Zelle and write this code in the memo.';
ALTER TABLE public.institute_settings ADD COLUMN IF NOT EXISTS pending_order_expiry_days INT DEFAULT 7;
ALTER TABLE public.institute_settings ADD COLUMN IF NOT EXISTS auto_confirm_strong_matches BOOLEAN DEFAULT FALSE;
ALTER TABLE public.institute_settings ADD COLUMN IF NOT EXISTS saved_bank_csv_mapping JSONB DEFAULT NULL;

-- 2. Bank Transactions Table
CREATE TABLE IF NOT EXISTS public.bank_transactions (
  id               UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  bank_tx_id       TEXT,
  transaction_date DATE NOT NULL,
  amount           NUMERIC(12, 2) NOT NULL CHECK (amount > 0),
  sender_name      TEXT NOT NULL DEFAULT '',
  memo             TEXT NOT NULL DEFAULT '',
  row_hash         TEXT NOT NULL UNIQUE,
  status           TEXT NOT NULL DEFAULT 'UNMATCHED' CHECK (status IN ('UNMATCHED', 'MATCHED', 'MANUAL_MATCHED', 'IGNORED')),
  matched_order_id UUID,
  matched_at       TIMESTAMPTZ,
  matched_by       TEXT,
  is_manual        BOOLEAN DEFAULT FALSE,
  raw_data         JSONB DEFAULT '{}'::jsonb,
  imported_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
  imported_by      TEXT
);

CREATE UNIQUE INDEX IF NOT EXISTS bank_transactions_row_hash_idx ON public.bank_transactions (row_hash);
CREATE UNIQUE INDEX IF NOT EXISTS bank_transactions_bank_tx_id_idx ON public.bank_transactions (bank_tx_id) WHERE bank_tx_id IS NOT NULL AND bank_tx_id <> '';
CREATE INDEX IF NOT EXISTS bank_transactions_status_idx ON public.bank_transactions (status);
CREATE INDEX IF NOT EXISTS bank_transactions_date_idx ON public.bank_transactions (transaction_date DESC);

-- 3. Upgrade token_orders
ALTER TABLE public.token_orders ADD COLUMN IF NOT EXISTS reference_code TEXT;
ALTER TABLE public.token_orders ADD COLUMN IF NOT EXISTS expires_at TIMESTAMPTZ;
ALTER TABLE public.token_orders ADD COLUMN IF NOT EXISTS bank_transaction_id UUID;
ALTER TABLE public.token_orders ADD COLUMN IF NOT EXISTS confirmed_by TEXT;
ALTER TABLE public.token_orders ADD COLUMN IF NOT EXISTS confirmed_at TIMESTAMPTZ;
ALTER TABLE public.token_orders ADD COLUMN IF NOT EXISTS amount_received NUMERIC(12, 2);
ALTER TABLE public.token_orders ADD COLUMN IF NOT EXISTS mismatch_note TEXT;
ALTER TABLE public.token_orders ADD COLUMN IF NOT EXISTS plan TEXT DEFAULT 'HOURS' CHECK (plan IN ('HOURS', 'PACKAGE'));

-- Foreign key link from token_orders to bank_transactions
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint WHERE conname = 'token_orders_bank_transaction_id_fkey'
  ) THEN
    ALTER TABLE public.token_orders
      ADD CONSTRAINT token_orders_bank_transaction_id_fkey
      FOREIGN KEY (bank_transaction_id) REFERENCES public.bank_transactions(id) ON DELETE SET NULL;
  END IF;
END $$;

-- Foreign key link from bank_transactions to token_orders
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint WHERE conname = 'bank_transactions_matched_order_id_fkey'
  ) THEN
    ALTER TABLE public.bank_transactions
      ADD CONSTRAINT bank_transactions_matched_order_id_fkey
      FOREIGN KEY (matched_order_id) REFERENCES public.token_orders(id) ON DELETE SET NULL;
  END IF;
END $$;

-- Migrate legacy status values if any exist
UPDATE public.token_orders SET status = 'PENDING_PAYMENT' WHERE status = 'PENDING';

-- Update status check constraint
DO $$
BEGIN
  ALTER TABLE public.token_orders DROP CONSTRAINT IF EXISTS token_orders_status_check;
  ALTER TABLE public.token_orders ADD CONSTRAINT token_orders_status_check
    CHECK (status IN ('PENDING_PAYMENT', 'PAID', 'PARTIAL', 'EXPIRED', 'CANCELLED', 'FAILED'));
EXCEPTION WHEN OTHERS THEN
  NULL;
END $$;

-- Update provider check constraint (allow ZELLE, CASH, BANK_TRANSFER, CHEQUE, STRIPE, OTHER)
DO $$
BEGIN
  ALTER TABLE public.token_orders DROP CONSTRAINT IF EXISTS token_orders_provider_check;
  ALTER TABLE public.token_orders ADD CONSTRAINT token_orders_provider_check
    CHECK (provider IN ('ZELLE', 'CASH', 'BANK_TRANSFER', 'CHEQUE', 'STRIPE', 'OTHER'));
EXCEPTION WHEN OTHERS THEN
  NULL;
END $$;

CREATE UNIQUE INDEX IF NOT EXISTS token_orders_reference_code_idx ON public.token_orders (reference_code) WHERE reference_code IS NOT NULL;
CREATE INDEX IF NOT EXISTS token_orders_status_idx ON public.token_orders (status);
CREATE INDEX IF NOT EXISTS token_orders_expires_at_idx ON public.token_orders (expires_at);

-- 4. Row-Level Security for bank_transactions
ALTER TABLE public.bank_transactions ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS bank_transactions_admin_all ON public.bank_transactions;
CREATE POLICY bank_transactions_admin_all ON public.bank_transactions
  FOR ALL TO authenticated
  USING (public.get_current_user_role() = 'ADMIN')
  WITH CHECK (public.get_current_user_role() = 'ADMIN');

-- 5. Atomic confirmation function
CREATE OR REPLACE FUNCTION public.zelle_confirm_order(
  p_order_id UUID,
  p_bank_tx_id UUID,
  p_admin_id TEXT,
  p_amount_received NUMERIC,
  p_status TEXT,
  p_credit_hours INT,
  p_mismatch_note TEXT DEFAULT NULL,
  p_is_manual BOOLEAN DEFAULT FALSE
)
RETURNS TABLE (out_success BOOLEAN, out_message TEXT, out_balance INTEGER)
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_order RECORD;
  v_bank_tx RECORD;
  v_apply_res RECORD;
  v_final_balance INT := 0;
BEGIN
  -- 1. Lock and fetch order
  SELECT * INTO v_order FROM public.token_orders WHERE id = p_order_id FOR UPDATE;
  IF NOT FOUND THEN
    RETURN QUERY SELECT FALSE, 'Order not found'::TEXT, 0;
    RETURN;
  END IF;

  IF v_order.status = 'PAID' THEN
    RETURN QUERY SELECT FALSE, 'Order already confirmed paid'::TEXT, 0;
    RETURN;
  END IF;

  IF v_order.status NOT IN ('PENDING_PAYMENT', 'PARTIAL') THEN
    RETURN QUERY SELECT FALSE, ('Cannot confirm order in status: ' || v_order.status)::TEXT, 0;
    RETURN;
  END IF;

  -- 2. Lock and verify bank transaction if linked
  IF p_bank_tx_id IS NOT NULL THEN
    SELECT * INTO v_bank_tx FROM public.bank_transactions WHERE id = p_bank_tx_id FOR UPDATE;
    IF NOT FOUND THEN
      RETURN QUERY SELECT FALSE, 'Bank transaction not found'::TEXT, 0;
      RETURN;
    END IF;

    IF v_bank_tx.status = 'MATCHED' AND v_bank_tx.matched_order_id <> p_order_id THEN
      RETURN QUERY SELECT FALSE, 'Bank transaction already matched to another order'::TEXT, 0;
      RETURN;
    END IF;

    UPDATE public.bank_transactions
       SET status = CASE WHEN p_is_manual THEN 'MANUAL_MATCHED' ELSE 'MATCHED' END,
           matched_order_id = p_order_id,
           matched_at = now(),
           matched_by = p_admin_id,
           is_manual = p_is_manual
     WHERE id = p_bank_tx_id;
  END IF;

  -- 3. Update Order
  UPDATE public.token_orders
     SET status = p_status,
         paid_at = CASE WHEN p_status IN ('PAID', 'PARTIAL') THEN now() ELSE paid_at END,
         confirmed_at = now(),
         confirmed_by = p_admin_id,
         amount_received = p_amount_received,
         mismatch_note = p_mismatch_note,
         bank_transaction_id = COALESCE(p_bank_tx_id, bank_transaction_id)
   WHERE id = p_order_id;

  -- 4. Credit tokens using idempotent token_apply if positive hours
  IF p_credit_hours > 0 THEN
    SELECT out_applied, out_balance INTO v_apply_res
      FROM public.token_apply(
        v_order.student_id,
        v_order.course_id,
        p_credit_hours,
        'PURCHASE',
        v_order.order_number,
        COALESCE(p_mismatch_note, 'Zelle order payment confirmed: ' || v_order.order_number),
        p_admin_id
      );
    v_final_balance := COALESCE(v_apply_res.out_balance, 0);
  END IF;

  RETURN QUERY SELECT TRUE, 'Order confirmed successfully'::TEXT, v_final_balance;
END $$;

REVOKE ALL ON FUNCTION public.zelle_confirm_order(UUID, UUID, TEXT, NUMERIC, TEXT, INT, TEXT, BOOLEAN) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.zelle_confirm_order(UUID, UUID, TEXT, NUMERIC, TEXT, INT, TEXT, BOOLEAN) TO service_role;
