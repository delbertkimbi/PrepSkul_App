-- ======================================================
-- MIGRATION 067: Onsite confirmation RPC
-- ------------------------------------------------------
-- Allows parent/learner to set confirm start/end without full session UPDATE.
-- ======================================================

CREATE OR REPLACE FUNCTION public.confirm_onsite_session_started(p_session_id UUID)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_session RECORD;
  v_uid UUID := auth.uid();
BEGIN
  SELECT id, parent_id, learner_id, location, status
  INTO v_session
  FROM public.individual_sessions
  WHERE id = p_session_id;

  IF v_session.id IS NULL THEN
    RAISE EXCEPTION 'Session not found';
  END IF;
  IF v_session.location IS DISTINCT FROM 'onsite' THEN
    RAISE EXCEPTION 'Session is not onsite';
  END IF;
  IF v_session.status IS DISTINCT FROM 'in_progress' THEN
    RAISE EXCEPTION 'Session must be in progress to confirm start';
  END IF;

  IF v_session.parent_id = v_uid THEN
    UPDATE public.individual_sessions
    SET parent_confirmed_start_at = COALESCE(parent_confirmed_start_at, now()),
        updated_at = now()
    WHERE id = p_session_id;
    RETURN;
  END IF;
  IF v_session.learner_id = v_uid THEN
    UPDATE public.individual_sessions
    SET learner_confirmed_start_at = COALESCE(learner_confirmed_start_at, now()),
        updated_at = now()
    WHERE id = p_session_id;
    RETURN;
  END IF;

  RAISE EXCEPTION 'Only parent or learner for this session can confirm start';
END;
$$;

CREATE OR REPLACE FUNCTION public.confirm_onsite_session_ended(p_session_id UUID)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_session RECORD;
  v_uid UUID := auth.uid();
BEGIN
  SELECT id, parent_id, learner_id, location, status
  INTO v_session
  FROM public.individual_sessions
  WHERE id = p_session_id;

  IF v_session.id IS NULL THEN
    RAISE EXCEPTION 'Session not found';
  END IF;
  IF v_session.location IS DISTINCT FROM 'onsite' THEN
    RAISE EXCEPTION 'Session is not onsite';
  END IF;
  IF v_session.status IS DISTINCT FROM 'completed' THEN
    RAISE EXCEPTION 'Session must be completed to confirm end';
  END IF;

  IF v_session.parent_id = v_uid THEN
    UPDATE public.individual_sessions
    SET parent_confirmed_end_at = COALESCE(parent_confirmed_end_at, now()),
        updated_at = now()
    WHERE id = p_session_id;
    RETURN;
  END IF;
  IF v_session.learner_id = v_uid THEN
    UPDATE public.individual_sessions
    SET learner_confirmed_end_at = COALESCE(learner_confirmed_end_at, now()),
        updated_at = now()
    WHERE id = p_session_id;
    RETURN;
  END IF;

  RAISE EXCEPTION 'Only parent or learner for this session can confirm end';
END;
$$;

COMMENT ON FUNCTION public.confirm_onsite_session_started(UUID) IS 'Parent or learner confirms tutor arrived and session started (onsite, in_progress). Idempotent.';
COMMENT ON FUNCTION public.confirm_onsite_session_ended(UUID) IS 'Parent or learner confirms session ended as expected (onsite, completed). Idempotent.';
