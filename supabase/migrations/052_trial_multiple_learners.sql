-- ======================================================
-- MIGRATION 052: Support multiple learners in ONE trial session
-- When parent books trial for 2+ children, it's ONE session, ONE price
-- Store learner names as JSONB array for display
-- ======================================================

ALTER TABLE public.trial_sessions
  ADD COLUMN IF NOT EXISTS learner_labels JSONB;

COMMENT ON COLUMN public.trial_sessions.learner_labels IS 'Array of learner names when parent books trial for multiple children. E.g. ["Emma", "James"]. Single child uses learner_label.';

-- Update comment for learner_label to clarify it's for single child or comma-separated fallback
COMMENT ON COLUMN public.trial_sessions.learner_label IS 'Display name for single learner (e.g. child name). For multiple learners, use learner_labels JSONB array instead.';

-- Note: booking_group_id is no longer needed for trials (was for multiple separate trials)
-- But we keep it for backward compatibility and potential future use
