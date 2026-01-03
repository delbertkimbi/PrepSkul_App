-- ======================================================
-- MIGRATION 034: skulMate Social Features
-- Creates tables for friendships, leaderboards, and challenges
-- ======================================================

-- 1. Create friendships table
CREATE TABLE IF NOT EXISTS public.skulmate_friendships (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  friend_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  status TEXT NOT NULL CHECK (status IN ('pending', 'accepted', 'blocked')),
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  -- Ensure unique friendship pairs
  UNIQUE(user_id, friend_id),
  -- Prevent self-friendship
  CHECK (user_id != friend_id)
);

-- 2. Create leaderboards table (stores aggregated stats for leaderboard display)
CREATE TABLE IF NOT EXISTS public.skulmate_leaderboards (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  period TEXT NOT NULL CHECK (period IN ('daily', 'weekly', 'monthly', 'all_time')),
  period_start TIMESTAMPTZ NOT NULL,
  period_end TIMESTAMPTZ,
  total_xp INTEGER DEFAULT 0,
  games_played INTEGER DEFAULT 0,
  perfect_scores INTEGER DEFAULT 0,
  average_score DECIMAL(5, 2) DEFAULT 0,
  rank INTEGER,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  UNIQUE(user_id, period, period_start)
);

-- 3. Create challenges table
CREATE TABLE IF NOT EXISTS public.skulmate_challenges (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  challenger_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  challengee_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  game_id UUID REFERENCES public.skulmate_games(id) ON DELETE SET NULL,
  challenge_type TEXT NOT NULL CHECK (challenge_type IN ('score', 'time', 'perfect_score')),
  target_value INTEGER, -- Target score, time in seconds, or 1 for perfect score
  status TEXT NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'accepted', 'completed', 'declined', 'expired')),
  challenger_result JSONB, -- Store challenger's game session result
  challengee_result JSONB, -- Store challengee's game session result
  winner_id UUID REFERENCES public.profiles(id),
  expires_at TIMESTAMPTZ NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  CHECK (challenger_id != challengee_id)
);

-- 4. Create indexes for better query performance
CREATE INDEX IF NOT EXISTS idx_skulmate_friendships_user_id ON public.skulmate_friendships(user_id);
CREATE INDEX IF NOT EXISTS idx_skulmate_friendships_friend_id ON public.skulmate_friendships(friend_id);
CREATE INDEX IF NOT EXISTS idx_skulmate_friendships_status ON public.skulmate_friendships(status);
CREATE INDEX IF NOT EXISTS idx_skulmate_leaderboards_user_id ON public.skulmate_leaderboards(user_id);
CREATE INDEX IF NOT EXISTS idx_skulmate_leaderboards_period ON public.skulmate_leaderboards(period, period_start);
CREATE INDEX IF NOT EXISTS idx_skulmate_leaderboards_rank ON public.skulmate_leaderboards(period, period_start, rank);
CREATE INDEX IF NOT EXISTS idx_skulmate_challenges_challenger ON public.skulmate_challenges(challenger_id);
CREATE INDEX IF NOT EXISTS idx_skulmate_challenges_challengee ON public.skulmate_challenges(challengee_id);
CREATE INDEX IF NOT EXISTS idx_skulmate_challenges_status ON public.skulmate_challenges(status);
CREATE INDEX IF NOT EXISTS idx_skulmate_challenges_expires ON public.skulmate_challenges(expires_at);

-- 5. Enable Row Level Security
ALTER TABLE public.skulmate_friendships ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.skulmate_leaderboards ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.skulmate_challenges ENABLE ROW LEVEL SECURITY;

-- 6. Create RLS policies for skulmate_friendships
DROP POLICY IF EXISTS "Users can view own friendships" ON public.skulmate_friendships;
DROP POLICY IF EXISTS "Users can create own friendships" ON public.skulmate_friendships;
DROP POLICY IF EXISTS "Users can update own friendships" ON public.skulmate_friendships;

CREATE POLICY "Users can view own friendships"
  ON public.skulmate_friendships FOR SELECT
  USING (auth.uid() = user_id OR auth.uid() = friend_id);

CREATE POLICY "Users can create own friendships"
  ON public.skulmate_friendships FOR INSERT
  WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update own friendships"
  ON public.skulmate_friendships FOR UPDATE
  USING (auth.uid() = user_id OR auth.uid() = friend_id);

-- 7. Create RLS policies for skulmate_leaderboards
DROP POLICY IF EXISTS "Users can view all leaderboards" ON public.skulmate_leaderboards;
DROP POLICY IF EXISTS "Users can insert own leaderboard entries" ON public.skulmate_leaderboards;
DROP POLICY IF EXISTS "Users can update own leaderboard entries" ON public.skulmate_leaderboards;

CREATE POLICY "Users can view all leaderboards"
  ON public.skulmate_leaderboards FOR SELECT
  USING (true); -- Leaderboards are public

CREATE POLICY "Users can insert own leaderboard entries"
  ON public.skulmate_leaderboards FOR INSERT
  WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update own leaderboard entries"
  ON public.skulmate_leaderboards FOR UPDATE
  USING (auth.uid() = user_id);

-- 8. Create RLS policies for skulmate_challenges
DROP POLICY IF EXISTS "Users can view own challenges" ON public.skulmate_challenges;
DROP POLICY IF EXISTS "Users can create own challenges" ON public.skulmate_challenges;
DROP POLICY IF EXISTS "Users can update own challenges" ON public.skulmate_challenges;

CREATE POLICY "Users can view own challenges"
  ON public.skulmate_challenges FOR SELECT
  USING (auth.uid() = challenger_id OR auth.uid() = challengee_id);

CREATE POLICY "Users can create own challenges"
  ON public.skulmate_challenges FOR INSERT
  WITH CHECK (auth.uid() = challenger_id);

CREATE POLICY "Users can update own challenges"
  ON public.skulmate_challenges FOR UPDATE
  USING (auth.uid() = challenger_id OR auth.uid() = challengee_id);

-- 9. Create function to update updated_at timestamp
CREATE OR REPLACE FUNCTION update_skulmate_social_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- 10. Create triggers for updated_at
DROP TRIGGER IF EXISTS update_skulmate_friendships_updated_at ON public.skulmate_friendships;
DROP TRIGGER IF EXISTS update_skulmate_leaderboards_updated_at ON public.skulmate_leaderboards;
DROP TRIGGER IF EXISTS update_skulmate_challenges_updated_at ON public.skulmate_challenges;

CREATE TRIGGER update_skulmate_friendships_updated_at
  BEFORE UPDATE ON public.skulmate_friendships
  FOR EACH ROW
  EXECUTE FUNCTION update_skulmate_social_updated_at();

CREATE TRIGGER update_skulmate_leaderboards_updated_at
  BEFORE UPDATE ON public.skulmate_leaderboards
  FOR EACH ROW
  EXECUTE FUNCTION update_skulmate_social_updated_at();

CREATE TRIGGER update_skulmate_challenges_updated_at
  BEFORE UPDATE ON public.skulmate_challenges
  FOR EACH ROW
  EXECUTE FUNCTION update_skulmate_social_updated_at();

-- 11. Create function to update leaderboard rankings
CREATE OR REPLACE FUNCTION update_leaderboard_rankings()
RETURNS TRIGGER AS $$
BEGIN
  -- Update rankings for the same period
  WITH ranked_users AS (
    SELECT 
      id,
      ROW_NUMBER() OVER (ORDER BY total_xp DESC, games_played DESC) as new_rank
    FROM public.skulmate_leaderboards
    WHERE period = NEW.period 
      AND period_start = NEW.period_start
  )
  UPDATE public.skulmate_leaderboards l
  SET rank = r.new_rank
  FROM ranked_users r
  WHERE l.id = r.id;
  
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- 12. Create trigger to auto-update rankings
DROP TRIGGER IF EXISTS trigger_update_leaderboard_rankings ON public.skulmate_leaderboards;
CREATE TRIGGER trigger_update_leaderboard_rankings
  AFTER INSERT OR UPDATE OF total_xp, games_played ON public.skulmate_leaderboards
  FOR EACH ROW
  EXECUTE FUNCTION update_leaderboard_rankings();





-- MIGRATION 034: skulMate Social Features
-- Creates tables for friendships, leaderboards, and challenges
-- ======================================================

-- 1. Create friendships table
CREATE TABLE IF NOT EXISTS public.skulmate_friendships (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  friend_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  status TEXT NOT NULL CHECK (status IN ('pending', 'accepted', 'blocked')),
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  -- Ensure unique friendship pairs
  UNIQUE(user_id, friend_id),
  -- Prevent self-friendship
  CHECK (user_id != friend_id)
);

-- 2. Create leaderboards table (stores aggregated stats for leaderboard display)
CREATE TABLE IF NOT EXISTS public.skulmate_leaderboards (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  period TEXT NOT NULL CHECK (period IN ('daily', 'weekly', 'monthly', 'all_time')),
  period_start TIMESTAMPTZ NOT NULL,
  period_end TIMESTAMPTZ,
  total_xp INTEGER DEFAULT 0,
  games_played INTEGER DEFAULT 0,
  perfect_scores INTEGER DEFAULT 0,
  average_score DECIMAL(5, 2) DEFAULT 0,
  rank INTEGER,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  UNIQUE(user_id, period, period_start)
);

-- 3. Create challenges table
CREATE TABLE IF NOT EXISTS public.skulmate_challenges (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  challenger_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  challengee_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  game_id UUID REFERENCES public.skulmate_games(id) ON DELETE SET NULL,
  challenge_type TEXT NOT NULL CHECK (challenge_type IN ('score', 'time', 'perfect_score')),
  target_value INTEGER, -- Target score, time in seconds, or 1 for perfect score
  status TEXT NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'accepted', 'completed', 'declined', 'expired')),
  challenger_result JSONB, -- Store challenger's game session result
  challengee_result JSONB, -- Store challengee's game session result
  winner_id UUID REFERENCES public.profiles(id),
  expires_at TIMESTAMPTZ NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  CHECK (challenger_id != challengee_id)
);

-- 4. Create indexes for better query performance
CREATE INDEX IF NOT EXISTS idx_skulmate_friendships_user_id ON public.skulmate_friendships(user_id);
CREATE INDEX IF NOT EXISTS idx_skulmate_friendships_friend_id ON public.skulmate_friendships(friend_id);
CREATE INDEX IF NOT EXISTS idx_skulmate_friendships_status ON public.skulmate_friendships(status);
CREATE INDEX IF NOT EXISTS idx_skulmate_leaderboards_user_id ON public.skulmate_leaderboards(user_id);
CREATE INDEX IF NOT EXISTS idx_skulmate_leaderboards_period ON public.skulmate_leaderboards(period, period_start);
CREATE INDEX IF NOT EXISTS idx_skulmate_leaderboards_rank ON public.skulmate_leaderboards(period, period_start, rank);
CREATE INDEX IF NOT EXISTS idx_skulmate_challenges_challenger ON public.skulmate_challenges(challenger_id);
CREATE INDEX IF NOT EXISTS idx_skulmate_challenges_challengee ON public.skulmate_challenges(challengee_id);
CREATE INDEX IF NOT EXISTS idx_skulmate_challenges_status ON public.skulmate_challenges(status);
CREATE INDEX IF NOT EXISTS idx_skulmate_challenges_expires ON public.skulmate_challenges(expires_at);

-- 5. Enable Row Level Security
ALTER TABLE public.skulmate_friendships ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.skulmate_leaderboards ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.skulmate_challenges ENABLE ROW LEVEL SECURITY;

-- 6. Create RLS policies for skulmate_friendships
DROP POLICY IF EXISTS "Users can view own friendships" ON public.skulmate_friendships;
DROP POLICY IF EXISTS "Users can create own friendships" ON public.skulmate_friendships;
DROP POLICY IF EXISTS "Users can update own friendships" ON public.skulmate_friendships;

CREATE POLICY "Users can view own friendships"
  ON public.skulmate_friendships FOR SELECT
  USING (auth.uid() = user_id OR auth.uid() = friend_id);

CREATE POLICY "Users can create own friendships"
  ON public.skulmate_friendships FOR INSERT
  WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update own friendships"
  ON public.skulmate_friendships FOR UPDATE
  USING (auth.uid() = user_id OR auth.uid() = friend_id);

-- 7. Create RLS policies for skulmate_leaderboards
DROP POLICY IF EXISTS "Users can view all leaderboards" ON public.skulmate_leaderboards;
DROP POLICY IF EXISTS "Users can insert own leaderboard entries" ON public.skulmate_leaderboards;
DROP POLICY IF EXISTS "Users can update own leaderboard entries" ON public.skulmate_leaderboards;

CREATE POLICY "Users can view all leaderboards"
  ON public.skulmate_leaderboards FOR SELECT
  USING (true); -- Leaderboards are public

CREATE POLICY "Users can insert own leaderboard entries"
  ON public.skulmate_leaderboards FOR INSERT
  WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update own leaderboard entries"
  ON public.skulmate_leaderboards FOR UPDATE
  USING (auth.uid() = user_id);

-- 8. Create RLS policies for skulmate_challenges
DROP POLICY IF EXISTS "Users can view own challenges" ON public.skulmate_challenges;
DROP POLICY IF EXISTS "Users can create own challenges" ON public.skulmate_challenges;
DROP POLICY IF EXISTS "Users can update own challenges" ON public.skulmate_challenges;

CREATE POLICY "Users can view own challenges"
  ON public.skulmate_challenges FOR SELECT
  USING (auth.uid() = challenger_id OR auth.uid() = challengee_id);

CREATE POLICY "Users can create own challenges"
  ON public.skulmate_challenges FOR INSERT
  WITH CHECK (auth.uid() = challenger_id);

CREATE POLICY "Users can update own challenges"
  ON public.skulmate_challenges FOR UPDATE
  USING (auth.uid() = challenger_id OR auth.uid() = challengee_id);

-- 9. Create function to update updated_at timestamp
CREATE OR REPLACE FUNCTION update_skulmate_social_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- 10. Create triggers for updated_at
DROP TRIGGER IF EXISTS update_skulmate_friendships_updated_at ON public.skulmate_friendships;
DROP TRIGGER IF EXISTS update_skulmate_leaderboards_updated_at ON public.skulmate_leaderboards;
DROP TRIGGER IF EXISTS update_skulmate_challenges_updated_at ON public.skulmate_challenges;

CREATE TRIGGER update_skulmate_friendships_updated_at
  BEFORE UPDATE ON public.skulmate_friendships
  FOR EACH ROW
  EXECUTE FUNCTION update_skulmate_social_updated_at();

CREATE TRIGGER update_skulmate_leaderboards_updated_at
  BEFORE UPDATE ON public.skulmate_leaderboards
  FOR EACH ROW
  EXECUTE FUNCTION update_skulmate_social_updated_at();

CREATE TRIGGER update_skulmate_challenges_updated_at
  BEFORE UPDATE ON public.skulmate_challenges
  FOR EACH ROW
  EXECUTE FUNCTION update_skulmate_social_updated_at();

-- 11. Create function to update leaderboard rankings
CREATE OR REPLACE FUNCTION update_leaderboard_rankings()
RETURNS TRIGGER AS $$
BEGIN
  -- Update rankings for the same period
  WITH ranked_users AS (
    SELECT 
      id,
      ROW_NUMBER() OVER (ORDER BY total_xp DESC, games_played DESC) as new_rank
    FROM public.skulmate_leaderboards
    WHERE period = NEW.period 
      AND period_start = NEW.period_start
  )
  UPDATE public.skulmate_leaderboards l
  SET rank = r.new_rank
  FROM ranked_users r
  WHERE l.id = r.id;
  
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- 12. Create trigger to auto-update rankings
DROP TRIGGER IF EXISTS trigger_update_leaderboard_rankings ON public.skulmate_leaderboards;
CREATE TRIGGER trigger_update_leaderboard_rankings
  AFTER INSERT OR UPDATE OF total_xp, games_played ON public.skulmate_leaderboards
  FOR EACH ROW
  EXECUTE FUNCTION update_leaderboard_rankings();







