-- ======================================================
-- MIGRATION 045: Add Location and Session Type to Feedback
-- Adds location_type and session_type columns to session_feedback
-- ======================================================

-- Add location_type column (online, onsite)
ALTER TABLE public.session_feedback 
ADD COLUMN IF NOT EXISTS location_type TEXT CHECK (location_type IN ('online', 'onsite'));

-- Add session_type column (trial, recurrent)
ALTER TABLE public.session_feedback 
ADD COLUMN IF NOT EXISTS session_type TEXT CHECK (session_type IN ('trial', 'recurrent'));

-- Add learning outcomes fields
ALTER TABLE public.session_feedback 
ADD COLUMN IF NOT EXISTS learning_objectives_met BOOLEAN;

ALTER TABLE public.session_feedback 
ADD COLUMN IF NOT EXISTS student_progress_rating INTEGER CHECK (student_progress_rating BETWEEN 1 AND 5);

ALTER TABLE public.session_feedback 
ADD COLUMN IF NOT EXISTS would_continue_lessons BOOLEAN;

-- Create indexes for analytics queries
CREATE INDEX IF NOT EXISTS idx_session_feedback_location_type ON public.session_feedback(location_type);
CREATE INDEX IF NOT EXISTS idx_session_feedback_session_type ON public.session_feedback(session_type);
CREATE INDEX IF NOT EXISTS idx_session_feedback_location_session ON public.session_feedback(location_type, session_type);

COMMENT ON COLUMN public.session_feedback.location_type IS 'Location type: online or onsite';
COMMENT ON COLUMN public.session_feedback.session_type IS 'Session type: trial or recurrent';
COMMENT ON COLUMN public.session_feedback.learning_objectives_met IS 'Whether learning objectives were met';
COMMENT ON COLUMN public.session_feedback.student_progress_rating IS 'Student rating of their progress (1-5)';
COMMENT ON COLUMN public.session_feedback.would_continue_lessons IS 'Whether student would continue lessons';


