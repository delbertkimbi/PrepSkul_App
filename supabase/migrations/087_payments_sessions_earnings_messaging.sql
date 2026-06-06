-- Payments, sessions, earnings & messaging fixes (plan 087)

-- Admin attendance review on individual sessions
ALTER TABLE public.individual_sessions
  ADD COLUMN IF NOT EXISTS attendance_admin_status TEXT
    CHECK (attendance_admin_status IS NULL OR attendance_admin_status IN ('pending', 'approved', 'rejected'));

ALTER TABLE public.individual_sessions
  ADD COLUMN IF NOT EXISTS attendance_admin_reviewed_at TIMESTAMPTZ;

ALTER TABLE public.individual_sessions
  ADD COLUMN IF NOT EXISTS attendance_admin_reviewed_by UUID REFERENCES auth.users(id);

CREATE INDEX IF NOT EXISTS idx_individual_sessions_attendance_admin_status
  ON public.individual_sessions(attendance_admin_status)
  WHERE attendance_admin_status IS NOT NULL;

COMMENT ON COLUMN public.individual_sessions.attendance_admin_status IS
  'Admin review of tutor onsite check-in/selfie: pending | approved | rejected';

-- Link tutor earnings to payment requests (pre-allocation on Fapshi payment)
ALTER TABLE public.tutor_earnings
  ADD COLUMN IF NOT EXISTS payment_request_id UUID REFERENCES public.payment_requests(id) ON DELETE SET NULL;

CREATE INDEX IF NOT EXISTS idx_tutor_earnings_payment_request
  ON public.tutor_earnings(payment_request_id)
  WHERE payment_request_id IS NOT NULL;

CREATE UNIQUE INDEX IF NOT EXISTS idx_tutor_earnings_payment_session_unique
  ON public.tutor_earnings(payment_request_id, session_id)
  WHERE payment_request_id IS NOT NULL AND session_id IS NOT NULL;

-- Message send idempotency (client-generated UUID)
ALTER TABLE public.messages
  ADD COLUMN IF NOT EXISTS client_message_id TEXT;

CREATE UNIQUE INDEX IF NOT EXISTS idx_messages_client_idempotency
  ON public.messages(conversation_id, client_message_id)
  WHERE client_message_id IS NOT NULL;

-- Tutor profile scheduled session count (denormalized)
ALTER TABLE public.tutor_profiles
  ADD COLUMN IF NOT EXISTS scheduled_sessions_count INTEGER NOT NULL DEFAULT 0;

-- Sync tutor public stats (completed + scheduled counts)
CREATE OR REPLACE FUNCTION public.refresh_tutor_public_stats(p_tutor_user_id UUID)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_completed INTEGER;
  v_scheduled INTEGER;
  v_students INTEGER;
BEGIN
  SELECT COUNT(*)::INTEGER INTO v_completed
  FROM public.individual_sessions s
  WHERE s.tutor_id = p_tutor_user_id
    AND s.status IN ('completed', 'evaluated');

  SELECT COUNT(*)::INTEGER INTO v_scheduled
  FROM public.individual_sessions s
  WHERE s.tutor_id = p_tutor_user_id
    AND s.status = 'scheduled'
    AND s.scheduled_date >= CURRENT_DATE;

  SELECT COUNT(DISTINCT COALESCE(s.learner_id, s.parent_id))::INTEGER INTO v_students
  FROM public.individual_sessions s
  WHERE s.tutor_id = p_tutor_user_id
    AND s.status IN ('completed', 'evaluated')
    AND COALESCE(s.learner_id, s.parent_id) IS NOT NULL;

  UPDATE public.tutor_profiles
  SET
    total_sessions_completed = v_completed,
    scheduled_sessions_count = v_scheduled,
    total_students = GREATEST(COALESCE(total_students, 0), v_students),
    updated_at = NOW()
  WHERE user_id = p_tutor_user_id;
END;
$$;

COMMENT ON FUNCTION public.refresh_tutor_public_stats(UUID) IS
  'Recompute tutor_profiles.total_sessions_completed and scheduled_sessions_count from individual_sessions.';

-- Trigger to refresh tutor stats when sessions change
CREATE OR REPLACE FUNCTION public.trg_refresh_tutor_stats_on_session()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF TG_OP = 'DELETE' THEN
    PERFORM public.refresh_tutor_public_stats(OLD.tutor_id);
    RETURN OLD;
  END IF;
  PERFORM public.refresh_tutor_public_stats(NEW.tutor_id);
  IF TG_OP = 'UPDATE' AND OLD.tutor_id IS DISTINCT FROM NEW.tutor_id THEN
    PERFORM public.refresh_tutor_public_stats(OLD.tutor_id);
  END IF;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS refresh_tutor_stats_on_session ON public.individual_sessions;
CREATE TRIGGER refresh_tutor_stats_on_session
  AFTER INSERT OR UPDATE OF status, tutor_id, scheduled_date OR DELETE
  ON public.individual_sessions
  FOR EACH ROW
  EXECUTE FUNCTION public.trg_refresh_tutor_stats_on_session();

-- Update payment eligibility: onsite/hybrid require admin attendance approval
CREATE OR REPLACE VIEW public.session_eligible_for_payment AS
SELECT
  s.id AS session_id,
  s.status = 'completed' AS is_completed,
  EXISTS (
    SELECT 1 FROM public.session_attendance a
    WHERE a.session_id = s.id AND a.user_type = 'tutor'
      AND a.check_in_time IS NOT NULL
  ) AS tutor_checked_in,
  COALESCE(
    (SELECT f.session_took_place
     FROM public.session_feedback f
     WHERE f.session_id = s.id AND f.session_id IS NOT NULL
     ORDER BY f.student_feedback_submitted_at DESC NULLS LAST
     LIMIT 1),
    'pending'
  ) AS feedback_took_place,
  (s.session_ended_at IS NOT NULL AND s.session_ended_at + INTERVAL '7 days' <= now()) AS no_feedback_grace_passed,
  (
    s.status = 'completed'
    AND EXISTS (
      SELECT 1 FROM public.session_attendance a
      WHERE a.session_id = s.id AND a.user_type = 'tutor'
        AND a.check_in_time IS NOT NULL
    )
    AND (
      NOT EXISTS (
        SELECT 1 FROM public.session_feedback f
        WHERE f.session_id = s.id AND f.session_took_place = 'no'
      )
      AND (
        EXISTS (
          SELECT 1 FROM public.session_feedback f
          WHERE f.session_id = s.id AND f.session_took_place = 'yes'
        )
        OR (s.session_ended_at IS NOT NULL AND s.session_ended_at + INTERVAL '7 days' <= now())
      )
    )
    AND (
      LOWER(COALESCE(s.location, 'online')) NOT IN ('onsite', 'hybrid')
      OR s.attendance_admin_status = 'approved'
    )
  ) AS eligible
FROM public.individual_sessions s
WHERE s.status = 'completed';

COMMENT ON VIEW public.session_eligible_for_payment IS
  'Payment release eligibility: check-in, completed, no dispute; onsite/hybrid also require attendance_admin_status=approved.';
