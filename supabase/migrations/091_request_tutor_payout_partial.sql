-- Accurate partial payout reservation: only deduct requested amount from active earnings.

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
  v_take NUMERIC;
  v_row_amount NUMERIC;
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

    v_row_amount := r.tutor_earnings;
    v_take := LEAST(v_row_amount, v_remaining);

    IF v_take >= v_row_amount THEN
      UPDATE public.tutor_earnings
      SET
        earnings_status = 'paid_out',
        payout_request_id = v_payout_id,
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
        v_payout_id,
        NOW(),
        NOW(),
        NOW()
      FROM public.tutor_earnings te
      WHERE te.id = r.id;
    END IF;

    v_remaining := v_remaining - v_take;
  END LOOP;

  RETURN (
    SELECT to_jsonb(pr.*)
    FROM public.payout_requests pr
    WHERE pr.id = v_payout_id
  );
END;
$$;

COMMENT ON FUNCTION public.request_tutor_payout IS
  'Creates payout_requests and reserves exactly p_amount from active tutor_earnings only (never pending). Supports partial row split.';
