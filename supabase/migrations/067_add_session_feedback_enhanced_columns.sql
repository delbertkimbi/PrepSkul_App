-- ======================================================
-- MIGRATION 067: Add enhanced session feedback columns
-- ======================================================
-- These fields are written by SessionFeedbackService but were missing
-- from the base feedback table in some environments.

ALTER TABLE public.session_feedback
  ADD COLUMN IF NOT EXISTS location_type TEXT CHECK (location_type IN ('online', 'onsite')),
  ADD COLUMN IF NOT EXISTS session_type TEXT CHECK (session_type IN ('trial', 'recurrent')),
  ADD COLUMN IF NOT EXISTS learning_objectives_met BOOLEAN,
  ADD COLUMN IF NOT EXISTS student_progress_rating INTEGER CHECK (student_progress_rating BETWEEN 1 AND 5),
  ADD COLUMN IF NOT EXISTS would_continue_lessons BOOLEAN;

COMMENT ON COLUMN public.session_feedback.location_type IS 'Session location type captured at feedback time: online or onsite.';
COMMENT ON COLUMN public.session_feedback.session_type IS 'Session type captured at feedback time: trial or recurrent.';
COMMENT ON COLUMN public.session_feedback.learning_objectives_met IS 'Whether learner/parent reports learning objectives were met.';
COMMENT ON COLUMN public.session_feedback.student_progress_rating IS 'Learner self-reported progress/confidence rating (1-5).';
COMMENT ON COLUMN public.session_feedback.would_continue_lessons IS 'Trial conversion signal: whether learner/parent would continue lessons.';

CREATE INDEX IF NOT EXISTS idx_session_feedback_location_type
  ON public.session_feedback(location_type);

CREATE INDEX IF NOT EXISTS idx_session_feedback_session_type
  ON public.session_feedback(session_type);
