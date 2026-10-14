-- ============================================================================
-- Requirement 9: one class = one token, per course, bought through Stripe
-- Requirement 8: teachers choose their classes from slots the admin created
--
-- token_wallets : how many tokens a student has for each course (balance can go below 0 = tokens owed)
-- token_ledger  : every change, with who/why. The unique index makes every credit and every deduction
--                 happen exactly once (a repeated Stripe event or a repeated attendance save does nothing)
-- token_orders  : purchases (Stripe, Zelle, cash...) with the price the SERVER calculated
-- teacher_slot_claims : which teacher took which open slot (one teacher per slot, enforced by the primary key)
-- All writes come from the backend (service role). Parents can read their own children's rows.
-- ============================================================================

CREATE TABLE IF NOT EXISTS public.token_wallets (
  student_id       UUID NOT NULL REFERENCES public.students(id) ON DELETE CASCADE,
  course_id        TEXT NOT NULL,
  balance          INTEGER NOT NULL DEFAULT 0,
  total_purchased  INTEGER NOT NULL DEFAULT 0,
  total_used       INTEGER NOT NULL DEFAULT 0,
  updated_at       TIMESTAMPTZ NOT NULL DEFAULT now(),
  PRIMARY KEY (student_id, course_id)
);

CREATE TABLE IF NOT EXISTS public.token_ledger (
  id             UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  student_id     UUID NOT NULL REFERENCES public.students(id) ON DELETE CASCADE,
  course_id      TEXT NOT NULL,
  delta          INTEGER NOT NULL,
  reason         TEXT NOT NULL CHECK (reason IN ('PURCHASE','MANUAL_CREDIT','CLASS_ATTENDED','ADJUSTMENT','REFUND')),
  ref            TEXT,
  note           TEXT,
  created_by     TEXT,
  balance_after  INTEGER,
  created_at     TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE UNIQUE INDEX IF NOT EXISTS token_ledger_once ON public.token_ledger (reason, ref) WHERE ref IS NOT NULL;
CREATE INDEX IF NOT EXISTS token_ledger_student_idx ON public.token_ledger (student_id, created_at DESC);

CREATE TABLE IF NOT EXISTS public.token_orders (
  id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  order_number  TEXT NOT NULL UNIQUE,
  student_id    UUID NOT NULL REFERENCES public.students(id) ON DELETE CASCADE,
  course_id     TEXT NOT NULL,
  course_name   TEXT,
  quantity      INTEGER NOT NULL CHECK (quantity > 0),
  unit_price    NUMERIC(12,2) NOT NULL CHECK (unit_price >= 0),
  amount_total  NUMERIC(12,2) NOT NULL CHECK (amount_total >= 0),
  currency      TEXT NOT NULL DEFAULT 'usd',
  provider      TEXT NOT NULL CHECK (provider IN ('STRIPE','ZELLE','CASH','BANK_TRANSFER','CHEQUE','OTHER')),
  provider_ref  TEXT,
  status        TEXT NOT NULL DEFAULT 'PENDING' CHECK (status IN ('PENDING','PAID','FAILED','CANCELLED')),
  payer_email   TEXT,
  note          TEXT,
  created_by    TEXT,
  created_at    TIMESTAMPTZ NOT NULL DEFAULT now(),
  paid_at       TIMESTAMPTZ
);
CREATE UNIQUE INDEX IF NOT EXISTS token_orders_provider_ref ON public.token_orders (provider, provider_ref) WHERE provider_ref IS NOT NULL;

CREATE TABLE IF NOT EXISTS public.teacher_slot_claims (
  slot_id        TEXT PRIMARY KEY,
  teacher_id     TEXT NOT NULL,
  teacher_name   TEXT,
  teacher_email  TEXT,
  claimed_at     TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- ---------------------------------------------------------------------------
-- The one place tokens change. Atomic and repeat-safe.
--   returns out_applied = false when the same (reason, ref) was already applied (nothing changes).
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.token_apply(
  p_student UUID, p_course TEXT, p_delta INTEGER, p_reason TEXT,
  p_ref TEXT DEFAULT NULL, p_note TEXT DEFAULT NULL, p_by TEXT DEFAULT NULL
)
RETURNS TABLE (out_applied BOOLEAN, out_balance INTEGER)
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_id UUID;
  v_balance INTEGER;
BEGIN
  INSERT INTO token_wallets (student_id, course_id) VALUES (p_student, p_course)
  ON CONFLICT (student_id, course_id) DO NOTHING;

  BEGIN
    INSERT INTO token_ledger (student_id, course_id, delta, reason, ref, note, created_by)
    VALUES (p_student, p_course, p_delta, p_reason, p_ref, p_note, p_by)
    RETURNING id INTO v_id;
  EXCEPTION WHEN unique_violation THEN
    SELECT w.balance INTO v_balance FROM token_wallets w WHERE w.student_id = p_student AND w.course_id = p_course;
    RETURN QUERY SELECT FALSE, v_balance;
    RETURN;
  END;

  UPDATE token_wallets w
     SET balance = w.balance + p_delta,
         total_purchased = w.total_purchased + GREATEST(p_delta, 0),
         total_used = w.total_used + GREATEST(-p_delta, 0),
         updated_at = now()
   WHERE w.student_id = p_student AND w.course_id = p_course
   RETURNING w.balance INTO v_balance;

  UPDATE token_ledger l SET balance_after = v_balance WHERE l.id = v_id;
  RETURN QUERY SELECT TRUE, v_balance;
END $$;

REVOKE ALL ON FUNCTION public.token_apply(UUID, TEXT, INTEGER, TEXT, TEXT, TEXT, TEXT) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.token_apply(UUID, TEXT, INTEGER, TEXT, TEXT, TEXT, TEXT) TO service_role;

-- ---------------------------------------------------------------------------
-- Row-level security (needs the helper functions from migration 20261010)
-- ---------------------------------------------------------------------------
ALTER TABLE public.token_wallets ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.token_ledger ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.token_orders ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.teacher_slot_claims ENABLE ROW LEVEL SECURITY;

DO $$
DECLARE t TEXT;
BEGIN
  FOREACH t IN ARRAY ARRAY['token_wallets','token_ledger','token_orders','teacher_slot_claims'] LOOP
    EXECUTE format('DROP POLICY IF EXISTS "admin_all" ON public.%I', t);
    EXECUTE format(
      'CREATE POLICY "admin_all" ON public.%I FOR ALL TO authenticated
         USING (public.get_current_user_role() = ''ADMIN'') WITH CHECK (public.get_current_user_role() = ''ADMIN'')', t);
  END LOOP;
END $$;

DROP POLICY IF EXISTS "parent_wallets_read" ON public.token_wallets;
CREATE POLICY "parent_wallets_read" ON public.token_wallets FOR SELECT TO authenticated
  USING (public.get_current_user_role() = 'PARENT' AND student_id IN (SELECT public.my_student_ids()));
DROP POLICY IF EXISTS "parent_ledger_read" ON public.token_ledger;
CREATE POLICY "parent_ledger_read" ON public.token_ledger FOR SELECT TO authenticated
  USING (public.get_current_user_role() = 'PARENT' AND student_id IN (SELECT public.my_student_ids()));
DROP POLICY IF EXISTS "parent_orders_read" ON public.token_orders;
CREATE POLICY "parent_orders_read" ON public.token_orders FOR SELECT TO authenticated
  USING (public.get_current_user_role() = 'PARENT' AND student_id IN (SELECT public.my_student_ids()));
DROP POLICY IF EXISTS "teacher_claims_read" ON public.teacher_slot_claims;
CREATE POLICY "teacher_claims_read" ON public.teacher_slot_claims FOR SELECT TO authenticated
  USING (public.get_current_user_role() = 'TEACHER' AND lower(teacher_id) = ANY (public.my_teacher_keys()));
