-- Payout: request only creates pending row; earnings reserved when admin processes (Fapshi).

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
  v_pending_payouts NUMERIC;
  v_available NUMERIC;
  v_payout_id UUID;
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

  SELECT COALESCE(SUM(amount), 0)
  INTO v_pending_payouts
  FROM public.payout_requests
  WHERE tutor_id = v_tutor_id
    AND status IN ('pending', 'processing');

  v_available := v_active - v_pending_payouts;

  IF p_amount > v_available THEN
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

  RETURN (
    SELECT to_jsonb(pr.*)
    FROM public.payout_requests pr
    WHERE pr.id = v_payout_id
  );
END;
$$;

COMMENT ON FUNCTION public.request_tutor_payout IS
  'Creates pending payout_requests only. Active tutor_earnings unchanged until reserve_tutor_payout_earnings runs on admin approval.';

-- Called by admin /payouts/process (service role or admin JWT) before Fapshi disbursement.
CREATE OR REPLACE FUNCTION public.reserve_tutor_payout_earnings(p_payout_request_id UUID)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_row public.payout_requests%ROWTYPE;
  v_remaining NUMERIC;
  r RECORD;
  v_take NUMERIC;
  v_row_amount NUMERIC;
BEGIN
  SELECT * INTO v_row
  FROM public.payout_requests
  WHERE id = p_payout_request_id
  FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'payout_not_found';
  END IF;

  IF v_row.status NOT IN ('pending', 'processing') THEN
    RAISE EXCEPTION 'payout_not_pending';
  END IF;

  IF EXISTS (
    SELECT 1 FROM public.tutor_earnings
    WHERE payout_request_id = p_payout_request_id
      AND earnings_status = 'paid_out'
    LIMIT 1
  ) THEN
    RETURN jsonb_build_object('already_reserved', true, 'payout_request_id', p_payout_request_id);
  END IF;

  v_remaining := v_row.amount;

  FOR r IN
    SELECT id, tutor_earnings
    FROM public.tutor_earnings
    WHERE tutor_id = v_row.tutor_id
      AND earnings_status = 'active'
    ORDER BY created_at ASC
    FOR UPDATE
  LOOP
    EXIT WHEN v_remaining <= 0;
    IF r.tutor_earnings IS NULL OR r.tutor_earnings <= 0 THEN
      CONTINUE;
    END IF;

    v_row_amount := r.tutor_earnings;
    v_take := LEAST(v_row_amount, v_remaining);

    IF v_take >= v_row_amount THEN
      UPDATE public.tutor_earnings
      SET
        earnings_status = 'paid_out',
        payout_request_id = p_payout_request_id,
        paid_out_at = NOW(),
        updated_at = NOW()
      WHERE id = r.id;
    ELSE
      UPDATE public.tutor_earnings
      SET
        tutor_earnings = v_row_amount - v_take,
        updated_at = NOW()
      WHERE id = r.id;

      INSERT INTO public.tutor_earnings (
        tutor_id,
        session_id,
        session_payment_id,
        recurring_session_id,
        session_fee,
        platform_fee,
        tutor_earnings,
        earnings_status,
        payout_request_id,
        paid_out_at,
        created_at,
        updated_at
      )
      SELECT
        te.tutor_id,
        te.session_id,
        te.session_payment_id,
        te.recurring_session_id,
        ROUND(te.session_fee * (v_take / NULLIF(v_row_amount, 0)), 2),
        ROUND(te.platform_fee * (v_take / NULLIF(v_row_amount, 0)), 2),
        v_take,
        'paid_out',
        p_payout_request_id,
        NOW(),
        NOW(),
        NOW()
      FROM public.tutor_earnings te
      WHERE te.id = r.id;
    END IF;

    v_remaining := v_remaining - v_take;
  END LOOP;

  IF v_remaining > 0.01 THEN
    RAISE EXCEPTION 'insufficient_active_earnings';
  END IF;

  UPDATE public.payout_requests
  SET status = 'processing', updated_at = NOW()
  WHERE id = p_payout_request_id;

  RETURN jsonb_build_object(
    'reserved', true,
    'payout_request_id', p_payout_request_id,
    'amount', v_row.amount
  );
END;
$$;

REVOKE ALL ON FUNCTION public.reserve_tutor_payout_earnings(UUID) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.reserve_tutor_payout_earnings(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION public.reserve_tutor_payout_earnings(UUID) TO service_role;
