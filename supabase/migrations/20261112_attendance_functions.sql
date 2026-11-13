-- =========================================================================
-- TopGrade Learning CRM: Attendance Marking & Token Accounting RPC
-- =========================================================================

CREATE OR REPLACE FUNCTION public.mark_attendance(
  p_attendance_id UUID,
  p_status TEXT,
  p_marked_by UUID DEFAULT NULL,
  p_remarks TEXT DEFAULT NULL
)
RETURNS TABLE (
  success BOOLEAN,
  new_status TEXT,
  slot_completed BOOLEAN,
  tokens_affected NUMERIC,
  error_message TEXT
)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE
  v_att RECORD;
  v_booking RECORD;
  v_slot RECORD;
  v_unmarked_count INTEGER;
  v_tokens NUMERIC := 0.00;
  v_is_completed BOOLEAN := false;
BEGIN
  -- Validate status
  IF p_status NOT IN ('present', 'absent', 'late', 'excused') THEN
    RETURN QUERY SELECT false, NULL::TEXT, false, 0.00::NUMERIC, 'Invalid attendance status. Must be present, absent, late, or excused.';
    RETURN;
  END IF;

  -- 1. Lock attendance row
  SELECT * INTO v_att FROM public.attendance WHERE id = p_attendance_id FOR UPDATE;
  IF NOT FOUND THEN
    RETURN QUERY SELECT false, NULL::TEXT, false, 0.00::NUMERIC, 'Attendance record not found.';
    RETURN;
  END IF;

  -- 2. Lock booking row
  SELECT * INTO v_booking FROM public.bookings WHERE id = v_att.booking_id FOR UPDATE;
  IF NOT FOUND THEN
    RETURN QUERY SELECT false, NULL::TEXT, false, 0.00::NUMERIC, 'Associated booking not found.';
    RETURN;
  END IF;

  -- 3. Lock slot row
  SELECT * INTO v_slot FROM public.schedule_slots WHERE id = v_att.slot_id FOR UPDATE;
  IF NOT FOUND THEN
    RETURN QUERY SELECT false, NULL::TEXT, false, 0.00::NUMERIC, 'Associated class slot not found.';
    RETURN;
  END IF;

  -- 4. Apply Token Accounting Rules
  -- Rule A: If previously 'excused' and now changed to 'present', 'late', or 'absent', re-reserve tokens
  IF v_att.status = 'excused' AND p_status IN ('present', 'late', 'absent') THEN
    v_tokens := -v_booking.tokens_reserved;
    INSERT INTO public.token_ledger (
      student_id,
      course_id,
      hours,
      type,
      ref_booking_id,
      note,
      created_by
    ) VALUES (
      v_att.student_id,
      v_slot.course_id,
      -v_booking.tokens_reserved,
      'reserve',
      v_booking.id,
      COALESCE(p_remarks, 'Hours re-reserved: excused status updated to ' || p_status),
      COALESCE(p_marked_by::TEXT, 'faculty')
    );
  -- Rule B: If previously NOT 'excused' and now marked 'excused', release tokens back to student
  ELSIF v_att.status != 'excused' AND p_status = 'excused' THEN
    v_tokens := v_booking.tokens_reserved;
    INSERT INTO public.token_ledger (
      student_id,
      course_id,
      hours,
      type,
      ref_booking_id,
      note,
      created_by
    ) VALUES (
      v_att.student_id,
      v_slot.course_id,
      v_booking.tokens_reserved,
      'release',
      v_booking.id,
      COALESCE(p_remarks, 'Absence excused by faculty - hours restored'),
      COALESCE(p_marked_by::TEXT, 'faculty')
    );
  -- Rule C: 'present' / 'late' consumes tokens (net-zero since already reserved upon booking)
  -- Rule D: 'absent' tokens stay consumed (policy default)
  END IF;

  -- 5. Update attendance row
  UPDATE public.attendance
  SET 
    status = p_status,
    marked_by = p_marked_by,
    marked_at = now()
  WHERE id = p_attendance_id;

  -- 6. Check if all bookings for this slot have now been marked
  SELECT COUNT(*) INTO v_unmarked_count
  FROM public.attendance
  WHERE slot_id = v_att.slot_id AND status = 'scheduled';

  IF v_unmarked_count = 0 THEN
    UPDATE public.schedule_slots
    SET status = 'completed'
    WHERE id = v_att.slot_id AND status != 'cancelled';
    v_is_completed := true;
  END IF;

  RETURN QUERY SELECT true, p_status, v_is_completed, v_tokens, NULL::TEXT;
END;
$$;

