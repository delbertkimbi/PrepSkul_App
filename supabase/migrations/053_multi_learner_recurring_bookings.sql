-- ======================================================
-- MIGRATION 053: Multi-learner support for recurring bookings
-- When parent books recurring sessions for 2+ children, apply discounts
-- Store learner names as JSONB array for display
-- ======================================================

-- Add learner_labels JSONB column to booking_requests
ALTER TABLE public.booking_requests
  ADD COLUMN IF NOT EXISTS learner_labels JSONB;

COMMENT ON COLUMN public.booking_requests.learner_labels IS 'Array of learner names when parent books recurring sessions for multiple children. E.g. ["Emma", "James"]. Single child uses student_name.';

-- Add learner_labels JSONB column to recurring_sessions
ALTER TABLE public.recurring_sessions
  ADD COLUMN IF NOT EXISTS learner_labels JSONB;

COMMENT ON COLUMN public.recurring_sessions.learner_labels IS 'Array of learner names for multi-learner recurring sessions. Copied from booking_requests when session is created.';
