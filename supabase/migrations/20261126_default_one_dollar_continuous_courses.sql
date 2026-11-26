-- Default all courses to $1.00/hour (1 token = $1/hr) and Continuous (no end date)
-- Plus synchronize historical token_ledger grants into token_wallets safely.

DO $$
BEGIN
  IF EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = 'public' AND table_name = 'courses' AND column_name = 'hourly_rate'
  ) THEN
    ALTER TABLE public.courses ALTER COLUMN hourly_rate SET DEFAULT 1;
    UPDATE public.courses
    SET hourly_rate = 1
    WHERE hourly_rate IS NULL OR hourly_rate <= 0;
  END IF;

  IF EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = 'public' AND table_name = 'courses' AND column_name = 'duration'
  ) THEN
    ALTER TABLE public.courses ALTER COLUMN duration SET DEFAULT 'Continuous (No End Date)';
    UPDATE public.courses
    SET duration = 'Continuous (No End Date)'
    WHERE duration IS NULL OR btrim(duration) = '';
  END IF;

  -- Backfill token_wallets where legacy token_ledger grants exist without wallet rows
  IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'token_wallets')
     AND EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'token_ledger') THEN
    INSERT INTO public.token_wallets (student_id, course_id, balance, total_purchased, total_used, updated_at)
    SELECT
      tl.student_id,
      tl.course_id::TEXT,
      COALESCE(SUM(COALESCE(tl.hours, tl.delta, 0)), 0)::NUMERIC AS balance,
      COALESCE(SUM(CASE WHEN COALESCE(tl.hours, tl.delta, 0) > 0 THEN COALESCE(tl.hours, tl.delta, 0) ELSE 0 END), 0)::NUMERIC AS total_purchased,
      COALESCE(SUM(CASE WHEN COALESCE(tl.hours, tl.delta, 0) < 0 THEN ABS(COALESCE(tl.hours, tl.delta, 0)) ELSE 0 END), 0)::NUMERIC AS total_used,
      now()
    FROM public.token_ledger tl
    WHERE tl.expires_at IS NULL OR tl.expires_at > now()
    GROUP BY tl.student_id, tl.course_id::TEXT
    ON CONFLICT (student_id, course_id) DO NOTHING;
  END IF;
END $$;
