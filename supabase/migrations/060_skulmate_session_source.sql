-- Add 'session' to skulmate_games source_type for session-based challenges
-- Session challenges are generated from individual_sessions.session_summary + transcript

-- Drop existing CHECK constraint (name may vary by PostgreSQL version)
ALTER TABLE public.skulmate_games
  DROP CONSTRAINT IF EXISTS skulmate_games_source_type_check;

-- Add new constraint including 'session'
ALTER TABLE public.skulmate_games
  ADD CONSTRAINT skulmate_games_source_type_check
  CHECK (source_type IS NULL OR source_type IN ('pdf', 'image', 'text', 'session'));

-- Add individual_session_id for session-sourced games (optional; enables linking back)
ALTER TABLE public.skulmate_games
  ADD COLUMN IF NOT EXISTS individual_session_id UUID REFERENCES public.individual_sessions(id) ON DELETE SET NULL;

CREATE INDEX IF NOT EXISTS idx_skulmate_games_individual_session_id
  ON public.skulmate_games(individual_session_id)
  WHERE individual_session_id IS NOT NULL;

COMMENT ON COLUMN public.skulmate_games.individual_session_id IS 'Session that this game was generated from (source_type=session)';
