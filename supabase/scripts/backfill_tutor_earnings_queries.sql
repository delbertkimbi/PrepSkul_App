-- Backfill helper queries (run in Supabase SQL editor)
-- Prerequisite: migration 087_payments_sessions_earnings_messaging.sql applied

-- 1) Find paid payment_requests missing tutor_earnings allocation
SELECT
  pr.id AS payment_request_id,
  pr.tutor_id,
  pr.amount,
  pr.paid_at,
  pr.recurring_session_id,
  rs.payment_plan,
  rs.frequency,
  (SELECT COUNT(*) FROM individual_sessions s
   WHERE s.recurring_session_id = pr.recurring_session_id
     AND s.status = 'scheduled') AS scheduled_count,
  (rs.frequency * CASE
    WHEN LOWER(COALESCE(rs.payment_plan, 'monthly')) IN ('weekly') THEN 1
    WHEN LOWER(COALESCE(rs.payment_plan, 'monthly')) IN ('biweekly', 'bi-weekly') THEN 2
    ELSE 4
  END) AS expected_session_count
FROM payment_requests pr
JOIN recurring_sessions rs ON rs.id = pr.recurring_session_id
WHERE pr.status = 'paid'
  AND NOT EXISTS (
    SELECT 1 FROM tutor_earnings te WHERE te.payment_request_id = pr.id
  )
ORDER BY pr.paid_at DESC;

-- 2) Cancel excess scheduled sessions for a recurring_session (example: keep first 8)
-- Replace :recurring_session_id and adjust LIMIT offset via subquery as needed.
/*
WITH ranked AS (
  SELECT id, ROW_NUMBER() OVER (ORDER BY scheduled_date ASC, scheduled_time ASC) AS rn
  FROM individual_sessions
  WHERE recurring_session_id = ':recurring_session_id'
    AND status = 'scheduled'
)
UPDATE individual_sessions s
SET status = 'cancelled', updated_at = NOW()
FROM ranked r
WHERE s.id = r.id AND r.rn > 8;
*/

-- 3) After running admin API backfill, verify tutor pending balance source rows
/*
SELECT te.id, te.session_id, te.tutor_earnings, te.earnings_status, te.payment_request_id
FROM tutor_earnings te
WHERE te.payment_request_id = ':payment_request_id';
*/
