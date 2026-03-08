-- ======================================================
-- MIGRATION 066: Session timeline and risk views
-- ------------------------------------------------------
-- session_timeline_view: merged event timeline per session for admin/risk
-- session_risk_view: risk score (0-100) and flags per session
-- session_eligible_for_payment: eligibility for payment release (A)-(C)
-- ======================================================

-- ---------- 1. session_timeline_view ----------
-- Unified timeline of events per session (individual_sessions only).
CREATE OR REPLACE VIEW public.session_timeline_view AS
SELECT session_id, event_time, event_type, actor_role, summary
FROM (
  -- Session lifecycle (from individual_sessions)
  SELECT
    s.id AS session_id,
    s.created_at AS event_time,
    'booking_created'::text AS event_type,
    'system'::text AS actor_role,
    'Session created' AS summary
  FROM public.individual_sessions s
  UNION ALL
  SELECT
    s.id,
    s.session_started_at,
    'session_started',
    'tutor',
    'Session started'
  FROM public.individual_sessions s
  WHERE s.session_started_at IS NOT NULL
  UNION ALL
  SELECT
    s.id,
    s.session_ended_at,
    'session_ended',
    'tutor',
    'Session ended'
  FROM public.individual_sessions s
  WHERE s.session_ended_at IS NOT NULL
  -- Attendance: check-in / check-out
  UNION ALL
  SELECT
    a.session_id,
    a.check_in_time,
    'check_in',
    a.user_type,
    'Check-in' || CASE WHEN a.check_in_verified THEN ' (verified)' ELSE '' END
  FROM public.session_attendance a
  WHERE a.check_in_time IS NOT NULL
  UNION ALL
  SELECT
    a.session_id,
    a.check_out_time,
    'check_out',
    a.user_type,
    'Check-out'
  FROM public.session_attendance a
  WHERE a.check_out_time IS NOT NULL
  -- Safety incidents
  UNION ALL
  SELECT
    i.session_id,
    i.created_at,
    'safety_incident',
    i.role,
    i.type || ': ' || left(i.message, 80)
  FROM public.safety_incidents i
  -- Feedback (student submit + session_took_place when present)
  UNION ALL
  SELECT
    f.session_id,
    f.student_feedback_submitted_at,
    'feedback_submitted',
    'student',
    'Feedback submitted' || CASE
      WHEN f.session_took_place IS NOT NULL THEN ' (took place: ' || f.session_took_place || ')'
      ELSE ''
    END
  FROM public.session_feedback f
  WHERE f.student_feedback_submitted_at IS NOT NULL
) AS events;

COMMENT ON VIEW public.session_timeline_view IS 'Merged timeline of session events for admin dashboard and risk logic (individual_sessions only).';
GRANT SELECT ON public.session_timeline_view TO authenticated;
GRANT SELECT ON public.session_timeline_view TO service_role;

-- ---------- 2. session_risk_view ----------
-- Risk score 0-100 and flags. Rules: session_took_place no +50, partially +30;
-- tutor late >15min +10; deviation >100m +20; incident warning +20, critical +40; low rating <3 +15.
CREATE OR REPLACE VIEW public.session_risk_view AS
WITH base AS (
  SELECT
    s.id AS session_id,
    s.status,
    s.location,
    s.session_ended_at,
    s.tutor_id,
    s.learner_id,
    s.parent_id
  FROM public.individual_sessions s
),
feedback_risk AS (
  SELECT
    f.session_id,
    CASE f.session_took_place
      WHEN 'no' THEN 50
      WHEN 'partially' THEN 30
      ELSE 0
    END AS dispute_score,
    CASE WHEN f.student_rating IS NOT NULL AND f.student_rating < 3 THEN 15 ELSE 0 END AS low_rating_score
  FROM public.session_feedback f
  WHERE f.session_id IS NOT NULL
),
attendance_risk AS (
  SELECT
    a.session_id,
    CASE WHEN a.punctuality_status = 'late' OR (a.late_by_minutes IS NOT NULL AND a.late_by_minutes > 15) THEN 10 ELSE 0 END AS late_score,
    CASE
      WHEN a.location_deviations IS NOT NULL
        AND jsonb_array_length(a.location_deviations) > 0
        AND EXISTS (
          SELECT 1 FROM jsonb_array_elements(a.location_deviations) AS dev
          WHERE (dev->>'distance_meters')::numeric > 100
        )
      THEN 20 ELSE 0
    END AS deviation_score
  FROM public.session_attendance a
  WHERE a.user_type = 'tutor' AND a.session_id IS NOT NULL
),
incident_risk AS (
  SELECT
    i.session_id,
    SUM(CASE i.severity WHEN 'critical' THEN 40 WHEN 'warning' THEN 20 ELSE 0 END)::integer AS incident_score
  FROM public.safety_incidents i
  WHERE i.resolved IS NOT TRUE
  GROUP BY i.session_id
)
SELECT
  b.session_id,
  LEAST(100, COALESCE(f.dispute_score, 0) + COALESCE(f.low_rating_score, 0)
    + COALESCE(MAX(ar.late_score), 0) + COALESCE(MAX(ar.deviation_score), 0)
    + COALESCE(MAX(ir.incident_score), 0)) AS risk_score,
  CASE
    WHEN COALESCE(f.dispute_score, 0) + COALESCE(f.low_rating_score, 0)
      + COALESCE(MAX(ar.late_score), 0) + COALESCE(MAX(ar.deviation_score), 0)
      + COALESCE(MAX(ir.incident_score), 0) >= 50 THEN 'high'
    WHEN COALESCE(f.dispute_score, 0) + COALESCE(f.low_rating_score, 0)
      + COALESCE(MAX(ar.late_score), 0) + COALESCE(MAX(ar.deviation_score), 0)
      + COALESCE(MAX(ir.incident_score), 0) >= 20 THEN 'medium'
    ELSE 'low'
  END AS risk_bucket,
  (COALESCE(f.dispute_score, 0) > 0) AS parent_dispute,
  (COALESCE(f.low_rating_score, 0) > 0) AS low_rating,
  (COALESCE(MAX(ar.late_score), 0) > 0) AS tutor_late,
  (COALESCE(MAX(ar.deviation_score), 0) > 0) AS location_deviation,
  (COALESCE(MAX(ir.incident_score), 0) > 0) AS has_incident
FROM base b
LEFT JOIN feedback_risk f ON f.session_id = b.session_id
LEFT JOIN attendance_risk ar ON ar.session_id = b.session_id
LEFT JOIN incident_risk ir ON ir.session_id = b.session_id
GROUP BY b.session_id, b.status, b.location, b.session_ended_at, b.tutor_id, b.learner_id, b.parent_id,
  f.dispute_score, f.low_rating_score;

COMMENT ON VIEW public.session_risk_view IS 'Per-session risk score (0-100) and flags for admin triage and alerts.';
GRANT SELECT ON public.session_risk_view TO authenticated;
GRANT SELECT ON public.session_risk_view TO service_role;

-- ---------- 3. session_eligible_for_payment ----------
-- Session is eligible for payment when:
-- (A) Tutor has checked in (attendance with check_in_time / check_in_verified for tutor)
-- (B) Session status = completed
-- (C) No dispute: no feedback with session_took_place = 'no' (or 'partially' if we hold), or feedback = 'yes', or 7 days passed with no feedback
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
  ) AS eligible
FROM public.individual_sessions s
WHERE s.status = 'completed';

COMMENT ON VIEW public.session_eligible_for_payment IS 'Eligibility for payment release: tutor checked in, session completed, no dispute (session_took_place != no) or 7 days passed.';
GRANT SELECT ON public.session_eligible_for_payment TO authenticated;
GRANT SELECT ON public.session_eligible_for_payment TO service_role;

-- RPC for app/cron to check eligibility without querying view directly (RLS-friendly).
CREATE OR REPLACE FUNCTION public.is_session_eligible_for_payment(p_session_id UUID)
RETURNS BOOLEAN
LANGUAGE sql
SECURITY DEFINER
STABLE
SET search_path = public
AS $$
  SELECT COALESCE((SELECT eligible FROM public.session_eligible_for_payment WHERE session_id = p_session_id), false);
$$;
COMMENT ON FUNCTION public.is_session_eligible_for_payment(UUID) IS 'Returns true if session meets (A) tutor checked in, (B) completed, (C) no dispute or 7 days passed.';
