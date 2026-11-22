-- ============================================================================
-- TOPGRADE CRM: TOKEN WALLETS & TOKEN APPLY RECOVERY MIGRATION
-- Migration: 20261123_token_wallets_and_apply_fix.sql
-- Paste and run this script in your Supabase SQL Editor.
-- ============================================================================

-- 1. Create token_wallets table if missing
CREATE TABLE IF NOT EXISTS public.token_wallets (
  student_id       UUID NOT NULL REFERENCES public.students(id) ON DELETE CASCADE,
  course_id        TEXT NOT NULL,
  balance          NUMERIC NOT NULL DEFAULT 0,
  total_purchased  NUMERIC NOT NULL DEFAULT 0,
  total_used       NUMERIC NOT NULL DEFAULT 0,
  updated_at       TIMESTAMPTZ NOT NULL DEFAULT now(),
  PRIMARY KEY (student_id, course_id)
);

-- 2. Ensure compatibility columns exist on token_ledger
ALTER TABLE public.token_ledger ADD COLUMN IF NOT EXISTS delta NUMERIC;
ALTER TABLE public.token_ledger ADD COLUMN IF NOT EXISTS reason TEXT;
ALTER TABLE public.token_ledger ADD COLUMN IF NOT EXISTS ref TEXT;
ALTER TABLE public.token_ledger ADD COLUMN IF NOT EXISTS balance_after NUMERIC;
ALTER TABLE public.token_ledger ADD COLUMN IF NOT EXISTS hours NUMERIC;
ALTER TABLE public.token_ledger ADD COLUMN IF NOT EXISTS type TEXT;

-- 3. Create index for repeat-safe idempotency
CREATE UNIQUE INDEX IF NOT EXISTS token_ledger_once ON public.token_ledger (reason, ref) WHERE ref IS NOT NULL;
CREATE INDEX IF NOT EXISTS token_ledger_student_idx ON public.token_ledger (student_id, created_at DESC);

-- 4. Create resilient token_apply function
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
  v_balance NUMERIC;
  v_course_uuid UUID;
  v_type TEXT;
BEGIN
  -- Ensure token_wallets entry exists
  INSERT INTO public.token_wallets (student_id, course_id) 
  VALUES (p_student, p_course)
  ON CONFLICT (student_id, course_id) DO NOTHING;

  -- Determine type for unified ledger
  IF p_delta < 0 OR p_reason = 'CLASS_ATTENDED' THEN
    v_type := 'consume';
  ELSIF p_reason = 'REFUND' THEN
    v_type := 'refund';
  ELSIF p_reason = 'ADJUSTMENT' THEN
    v_type := 'adjustment';
  ELSE
    v_type := 'grant';
  END IF;

  -- Resolve course UUID if available
  BEGIN
    v_course_uuid := p_course::UUID;
  EXCEPTION WHEN OTHERS THEN
    SELECT id INTO v_course_uuid FROM public.courses WHERE name ILIKE p_course LIMIT 1;
  END;

  -- Insert into token_ledger safely
  BEGIN
    INSERT INTO public.token_ledger (
      student_id, 
      course_id, 
      delta, 
      reason, 
      ref, 
      hours, 
      type, 
      note, 
      created_by
    )
    VALUES (
      p_student, 
      COALESCE(v_course_uuid, p_student), 
      p_delta, 
      p_reason, 
      p_ref, 
      p_delta, 
      v_type, 
      COALESCE(p_note, p_reason), 
      COALESCE(p_by, 'admin')
    )
    RETURNING id INTO v_id;
  EXCEPTION 
    WHEN unique_violation THEN
      SELECT COALESCE(w.balance, 0) INTO v_balance 
      FROM public.token_wallets w 
      WHERE w.student_id = p_student AND w.course_id = p_course;
      RETURN QUERY SELECT FALSE, v_balance::INTEGER;
      RETURN;
    WHEN OTHERS THEN
      NULL;
  END;

  -- Update token_wallets balance
  UPDATE public.token_wallets w
     SET balance = w.balance + p_delta,
         total_purchased = w.total_purchased + GREATEST(p_delta, 0),
         total_used = w.total_used + GREATEST(-p_delta, 0),
         updated_at = now()
   WHERE w.student_id = p_student AND w.course_id = p_course
  RETURNING w.balance INTO v_balance;

  RETURN QUERY SELECT TRUE, COALESCE(v_balance, p_delta)::INTEGER;
END;
$$;
