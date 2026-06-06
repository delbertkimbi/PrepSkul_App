-- Atomically create a payout request and reserve active tutor_earnings (FIFO).
-- Client-side updates were blocked by RLS (SELECT-only on tutor_earnings).

CREATE OR REPLACE FUNCTION public.request_tutor_payout(
  p_amount NUMERIC,
  p_phone_number TEXT,
  p_notes TEXT DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_tutor_id UUID := auth.uid();
  v_active NUMERIC;
  v_payout_id UUID;
  v_remaining NUMERIC;
  r RECORD;
BEGIN
  IF v_tutor_id IS NULL THEN
    RAISE EXCEPTION 'not_authenticated';
  END IF;

  IF p_amount IS NULL OR p_amount < 5000 THEN
    RAISE EXCEPTION 'minimum_payout';
  END IF;

  SELECT COALESCE(SUM(tutor_earnings), 0)
  INTO v_active
  FROM public.tutor_earnings
  WHERE tutor_id = v_tutor_id
    AND earnings_status = 'active';

  IF p_amount > v_active THEN
    RAISE EXCEPTION 'insufficient_balance';
  END IF;

  INSERT INTO public.payout_requests (
    tutor_id,
    amount,
    phone_number,
    status,
    notes,
    requested_at,
    created_at,
    updated_at
  )
  VALUES (
    v_tutor_id,
    p_amount,
    p_phone_number,
    'pending',
    p_notes,
    NOW(),
    NOW(),
    NOW()
  )
  RETURNING id INTO v_payout_id;

  v_remaining := p_amount;

  FOR r IN
    SELECT id, tutor_earnings
    FROM public.tutor_earnings
    WHERE tutor_id = v_tutor_id
      AND earnings_status = 'active'
    ORDER BY created_at ASC
    FOR UPDATE
  LOOP
    EXIT WHEN v_remaining <= 0;
    IF r.tutor_earnings IS NULL OR r.tutor_earnings <= 0 THEN
      CONTINUE;
    END IF;

    UPDATE public.tutor_earnings
    SET
      earnings_status = 'paid_out',
      payout_request_id = v_payout_id,
      paid_out_at = NOW(),
      updated_at = NOW()
    WHERE id = r.id;

    v_remaining := v_remaining - r.tutor_earnings;
  END LOOP;

  RETURN (
    SELECT to_jsonb(pr.*)
    FROM public.payout_requests pr
    WHERE pr.id = v_payout_id
  );
END;
$$;

REVOKE ALL ON FUNCTION public.request_tutor_payout(NUMERIC, TEXT, TEXT) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.request_tutor_payout(NUMERIC, TEXT, TEXT) TO authenticated;

COMMENT ON FUNCTION public.request_tutor_payout IS
  'Creates payout_requests row and marks active tutor_earnings as paid_out (FIFO) so wallet active balance decreases immediately.';
