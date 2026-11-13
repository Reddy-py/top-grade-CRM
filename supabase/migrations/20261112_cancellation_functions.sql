-- =========================================================================
-- TopGrade Learning CRM: Cancellation & Slot Management RPCs
-- =========================================================================

-- 1. CANCEL BOOKING FUNCTION (cancel_booking)
CREATE OR REPLACE FUNCTION public.cancel_booking(
  p_booking_id UUID,
  p_cancelled_by UUID DEFAULT NULL,
  p_reason TEXT DEFAULT NULL
)
RETURNS TABLE (
  success BOOLEAN,
  tokens_released NUMERIC,
  policy_applied TEXT,
  error_message TEXT
)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE
  v_booking RECORD;
  v_slot RECORD;
  v_hours_until_start NUMERIC;
  v_released NUMERIC := 0.00;
  v_policy TEXT;
BEGIN
  -- 1. Lock booking row
  SELECT * INTO v_booking FROM public.bookings WHERE id = p_booking_id FOR UPDATE;
  IF NOT FOUND THEN
    RETURN QUERY SELECT false, 0.00::NUMERIC, NULL::TEXT, 'Booking not found.';
    RETURN;
  END IF;

  IF v_booking.status = 'cancelled' THEN
    RETURN QUERY SELECT false, 0.00::NUMERIC, NULL::TEXT, 'Booking is already cancelled.';
    RETURN;
  END IF;

  -- 2. Lock slot row
  SELECT * INTO v_slot FROM public.schedule_slots WHERE id = v_booking.slot_id FOR UPDATE;
  IF NOT FOUND THEN
    RETURN QUERY SELECT false, 0.00::NUMERIC, NULL::TEXT, 'Associated class slot not found.';
    RETURN;
  END IF;

  -- 3. Calculate hours until class start
  v_hours_until_start := EXTRACT(EPOCH FROM (v_slot.start_at - now())) / 3600.0;

  -- Cancellation policy:
  -- If cancelled >= 24h prior, release tokens back
  IF v_hours_until_start >= 24.0 THEN
    v_released := v_booking.tokens_reserved;
    v_policy := 'Full release (>= 24h notice)';
    
    INSERT INTO public.token_ledger (
      student_id,
      course_id,
      hours,
      type,
      ref_booking_id,
      note,
      created_by
    ) VALUES (
      v_booking.student_id,
      v_slot.course_id,
      v_booking.tokens_reserved,
      'release',
      p_booking_id,
      COALESCE(p_reason, 'Booking cancelled >= 24h before class - hours restored'),
      'system'
    );
  ELSE
    v_released := 0.00;
    v_policy := 'Forfeited (< 24h notice)';
  END IF;

  -- 4. Mark booking cancelled
  UPDATE public.bookings 
  SET status = 'cancelled', cancelled_at = now()
  WHERE id = p_booking_id;

  -- 5. Mark attendance cancelled
  UPDATE public.attendance 
  SET status = 'cancelled'
  WHERE booking_id = p_booking_id;

  -- 6. If slot was full, reopen it
  IF v_slot.status = 'full' THEN
    UPDATE public.schedule_slots 
    SET status = 'open' 
    WHERE id = v_slot.id;
  END IF;

  RETURN QUERY SELECT true, v_released, v_policy, NULL::TEXT;
END;
$$;

-- 2. CANCEL SCHEDULE SLOT FUNCTION (cancel_schedule_slot)
CREATE OR REPLACE FUNCTION public.cancel_schedule_slot(
  p_slot_id UUID,
  p_cancelled_by UUID DEFAULT NULL,
  p_reason TEXT DEFAULT NULL
)
RETURNS TABLE (
  success BOOLEAN,
  bookings_cancelled INTEGER,
  total_tokens_released NUMERIC,
  error_message TEXT
)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE
  v_slot RECORD;
  v_booking RECORD;
  v_count INTEGER := 0;
  v_total_released NUMERIC := 0.00;
BEGIN
  SELECT * INTO v_slot FROM public.schedule_slots WHERE id = p_slot_id FOR UPDATE;
  IF NOT FOUND THEN
    RETURN QUERY SELECT false, 0, 0.00::NUMERIC, 'Schedule slot not found.';
    RETURN;
  END IF;

  IF v_slot.status = 'cancelled' THEN
    RETURN QUERY SELECT false, 0, 0.00::NUMERIC, 'Schedule slot is already cancelled.';
    RETURN;
  END IF;

  -- Update slot to cancelled
  UPDATE public.schedule_slots 
  SET status = 'cancelled', updated_at = now() 
  WHERE id = p_slot_id;

  -- Iterate through all active bookings for this slot and release tokens
  FOR v_booking IN 
    SELECT * FROM public.bookings WHERE slot_id = p_slot_id AND status = 'booked'
  LOOP
    INSERT INTO public.token_ledger (
      student_id,
      course_id,
      hours,
      type,
      ref_booking_id,
      note,
      created_by
    ) VALUES (
      v_booking.student_id,
      v_slot.course_id,
      v_booking.tokens_reserved,
      'release',
      v_booking.id,
      COALESCE(p_reason, 'Class slot cancelled by institute - hours restored'),
      'system'
    );

    v_total_released := v_total_released + v_booking.tokens_reserved;
    v_count := v_count + 1;
  END LOOP;

  -- Cancel all bookings and attendance
  UPDATE public.bookings 
  SET status = 'cancelled', cancelled_at = now() 
  WHERE slot_id = p_slot_id AND status = 'booked';

  UPDATE public.attendance 
  SET status = 'cancelled' 
  WHERE slot_id = p_slot_id AND status = 'scheduled';

  RETURN QUERY SELECT true, v_count, v_total_released, NULL::TEXT;
END;
$$;

