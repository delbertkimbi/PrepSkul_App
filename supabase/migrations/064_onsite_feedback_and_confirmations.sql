-- Onsite session refinement: feedback "did session take place?" and optional parent/learner confirmations
-- Plan: Refine Onsite Session Management

-- 1. session_feedback: add onsite confirmation fields (for family-side confirmation / dispute)
ALTER TABLE public.session_feedback
  ADD COLUMN IF NOT EXISTS session_took_place TEXT CHECK (session_took_place IN ('yes', 'no', 'partially')),
  ADD COLUMN IF NOT EXISTS session_took_place_notes TEXT;

COMMENT ON COLUMN public.session_feedback.session_took_place IS 'Onsite only: family answer to "Did this session take place as scheduled?" (yes/no/partially). NULL for online or not yet answered.';
COMMENT ON COLUMN public.session_feedback.session_took_place_notes IS 'Optional notes when session_took_place is no or partially (e.g. tutor did not show, only 20 min).';

-- 2. individual_sessions: optional parent/learner confirm start/end (dual verification)
ALTER TABLE public.individual_sessions
  ADD COLUMN IF NOT EXISTS parent_confirmed_start_at TIMESTAMPTZ,
  ADD COLUMN IF NOT EXISTS parent_confirmed_end_at TIMESTAMPTZ,
  ADD COLUMN IF NOT EXISTS learner_confirmed_start_at TIMESTAMPTZ,
  ADD COLUMN IF NOT EXISTS learner_confirmed_end_at TIMESTAMPTZ;

COMMENT ON COLUMN public.individual_sessions.parent_confirmed_start_at IS 'Onsite: when parent confirmed tutor arrived and session started (optional).';
COMMENT ON COLUMN public.individual_sessions.parent_confirmed_end_at IS 'Onsite: when parent confirmed session ended as expected (optional).';
COMMENT ON COLUMN public.individual_sessions.learner_confirmed_start_at IS 'Onsite: when learner confirmed session started (optional).';
COMMENT ON COLUMN public.individual_sessions.learner_confirmed_end_at IS 'Onsite: when learner confirmed session ended (optional).';

-- Index for dispute/eligibility queries
CREATE INDEX IF NOT EXISTS idx_session_feedback_session_took_place
  ON public.session_feedback(session_took_place)
  WHERE session_took_place IS NOT NULL;
