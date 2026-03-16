-- ======================================================
-- MIGRATION 072: skulMate usage metering + cost attribution
-- Tracks estimated AI resource usage per user/event for pricing and analytics
-- ======================================================

CREATE TABLE IF NOT EXISTS public.skulmate_usage_events (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  child_id UUID REFERENCES public.profiles(id) ON DELETE SET NULL,
  event_type TEXT NOT NULL CHECK (
    event_type IN ('generate_game', 'flashcard_explain', 'extract_entities', 'challenge_from_session')
  ),
  source_type TEXT,
  game_type TEXT,
  game_id UUID REFERENCES public.skulmate_games(id) ON DELETE SET NULL,
  success BOOLEAN NOT NULL DEFAULT true,
  estimated_cost_usd NUMERIC(10, 6) NOT NULL DEFAULT 0,
  estimated_credits INTEGER NOT NULL DEFAULT 0 CHECK (estimated_credits >= 0),
  metadata JSONB NOT NULL DEFAULT '{}'::jsonb,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_skulmate_usage_events_user_created
  ON public.skulmate_usage_events(user_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_skulmate_usage_events_event_type
  ON public.skulmate_usage_events(event_type);
CREATE INDEX IF NOT EXISTS idx_skulmate_usage_events_game_id
  ON public.skulmate_usage_events(game_id);

ALTER TABLE public.skulmate_usage_events ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Users can view own skulmate usage events" ON public.skulmate_usage_events;
CREATE POLICY "Users can view own skulmate usage events"
  ON public.skulmate_usage_events
  FOR SELECT
  USING (auth.uid() = user_id);

DROP POLICY IF EXISTS "Service role can manage skulmate usage events" ON public.skulmate_usage_events;
CREATE POLICY "Service role can manage skulmate usage events"
  ON public.skulmate_usage_events
  FOR ALL
  USING (auth.jwt()->>'role' = 'service_role')
  WITH CHECK (auth.jwt()->>'role' = 'service_role');

-- Optional helper view for quick per-user billing reports
CREATE OR REPLACE VIEW public.skulmate_usage_monthly AS
SELECT
  user_id,
  date_trunc('month', created_at) AS month,
  count(*) AS events_count,
  sum(estimated_credits) AS total_estimated_credits,
  sum(estimated_cost_usd) AS total_estimated_cost_usd
FROM public.skulmate_usage_events
GROUP BY user_id, date_trunc('month', created_at);

COMMENT ON TABLE public.skulmate_usage_events IS
'Per-request skulMate usage events for cost attribution and monetization analytics.';
COMMENT ON VIEW public.skulmate_usage_monthly IS
'Monthly per-user estimated cost and credits from skulMate usage events.';
-- ======================================================
-- MIGRATION 072: skulMate usage metering + cost attribution
-- Tracks estimated AI resource usage per user/event for pricing and analytics
-- ======================================================

CREATE TABLE IF NOT EXISTS public.skulmate_usage_events (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  child_id UUID REFERENCES public.profiles(id) ON DELETE SET NULL,
  event_type TEXT NOT NULL CHECK (
    event_type IN ('generate_game', 'flashcard_explain', 'extract_entities', 'challenge_from_session')
  ),
  source_type TEXT,
  game_type TEXT,
  game_id UUID REFERENCES public.skulmate_games(id) ON DELETE SET NULL,
  success BOOLEAN NOT NULL DEFAULT true,
  estimated_cost_usd NUMERIC(10, 6) NOT NULL DEFAULT 0,
  estimated_credits INTEGER NOT NULL DEFAULT 0 CHECK (estimated_credits >= 0),
  metadata JSONB NOT NULL DEFAULT '{}'::jsonb,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_skulmate_usage_events_user_created
  ON public.skulmate_usage_events(user_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_skulmate_usage_events_event_type
  ON public.skulmate_usage_events(event_type);
CREATE INDEX IF NOT EXISTS idx_skulmate_usage_events_game_id
  ON public.skulmate_usage_events(game_id);

ALTER TABLE public.skulmate_usage_events ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Users can view own skulmate usage events" ON public.skulmate_usage_events;
CREATE POLICY "Users can view own skulmate usage events"
  ON public.skulmate_usage_events
  FOR SELECT
  USING (auth.uid() = user_id);

DROP POLICY IF EXISTS "Service role can manage skulmate usage events" ON public.skulmate_usage_events;
CREATE POLICY "Service role can manage skulmate usage events"
  ON public.skulmate_usage_events
  FOR ALL
  USING (auth.jwt()->>'role' = 'service_role')
  WITH CHECK (auth.jwt()->>'role' = 'service_role');

-- Optional helper view for quick per-user billing reports
CREATE OR REPLACE VIEW public.skulmate_usage_monthly AS
SELECT
  user_id,
  date_trunc('month', created_at) AS month,
  count(*) AS events_count,
  sum(estimated_credits) AS total_estimated_credits,
  sum(estimated_cost_usd) AS total_estimated_cost_usd
FROM public.skulmate_usage_events
GROUP BY user_id, date_trunc('month', created_at);

COMMENT ON TABLE public.skulmate_usage_events IS
'Per-request skulMate usage events for cost attribution and monetization analytics.';
COMMENT ON VIEW public.skulmate_usage_monthly IS
'Monthly per-user estimated cost and credits from skulMate usage events.';
