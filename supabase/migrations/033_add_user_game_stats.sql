-- Migration: Add user game statistics table for gamification
-- This table stores XP, levels, streaks, and achievements for users

-- Create user_game_stats table
CREATE TABLE IF NOT EXISTS public.user_game_stats (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  total_xp INTEGER NOT NULL DEFAULT 0,
  level INTEGER NOT NULL DEFAULT 1,
  current_streak INTEGER NOT NULL DEFAULT 0,
  best_streak INTEGER NOT NULL DEFAULT 0,
  games_played INTEGER NOT NULL DEFAULT 0,
  perfect_scores INTEGER NOT NULL DEFAULT 0,
  total_correct_answers INTEGER NOT NULL DEFAULT 0,
  total_questions INTEGER NOT NULL DEFAULT 0,
  last_played_date TIMESTAMPTZ,
  achievements TEXT[] DEFAULT '{}',
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  
  -- Ensure one stats record per user
  UNIQUE(user_id)
);

-- Create index for faster lookups
CREATE INDEX IF NOT EXISTS idx_user_game_stats_user_id ON public.user_game_stats(user_id);
CREATE INDEX IF NOT EXISTS idx_user_game_stats_level ON public.user_game_stats(level DESC);

-- Create updated_at trigger
CREATE OR REPLACE FUNCTION update_user_game_stats_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER update_user_game_stats_updated_at
  BEFORE UPDATE ON public.user_game_stats
  FOR EACH ROW
  EXECUTE FUNCTION update_user_game_stats_updated_at();

-- Enable RLS
ALTER TABLE public.user_game_stats ENABLE ROW LEVEL SECURITY;

-- RLS Policies

-- Users can view their own stats
CREATE POLICY "Users can view their own game stats"
  ON public.user_game_stats
  FOR SELECT
  USING (auth.uid() = user_id);

-- Users can insert their own stats
CREATE POLICY "Users can insert their own game stats"
  ON public.user_game_stats
  FOR INSERT
  WITH CHECK (auth.uid() = user_id);

-- Users can update their own stats
CREATE POLICY "Users can update their own game stats"
  ON public.user_game_stats
  FOR UPDATE
  USING (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);

-- Add comment
COMMENT ON TABLE public.user_game_stats IS 'Stores user game statistics including XP, levels, streaks, and achievements for skulMate games';





-- This table stores XP, levels, streaks, and achievements for users

-- Create user_game_stats table
CREATE TABLE IF NOT EXISTS public.user_game_stats (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  total_xp INTEGER NOT NULL DEFAULT 0,
  level INTEGER NOT NULL DEFAULT 1,
  current_streak INTEGER NOT NULL DEFAULT 0,
  best_streak INTEGER NOT NULL DEFAULT 0,
  games_played INTEGER NOT NULL DEFAULT 0,
  perfect_scores INTEGER NOT NULL DEFAULT 0,
  total_correct_answers INTEGER NOT NULL DEFAULT 0,
  total_questions INTEGER NOT NULL DEFAULT 0,
  last_played_date TIMESTAMPTZ,
  achievements TEXT[] DEFAULT '{}',
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  
  -- Ensure one stats record per user
  UNIQUE(user_id)
);

-- Create index for faster lookups
CREATE INDEX IF NOT EXISTS idx_user_game_stats_user_id ON public.user_game_stats(user_id);
CREATE INDEX IF NOT EXISTS idx_user_game_stats_level ON public.user_game_stats(level DESC);

-- Create updated_at trigger
CREATE OR REPLACE FUNCTION update_user_game_stats_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER update_user_game_stats_updated_at
  BEFORE UPDATE ON public.user_game_stats
  FOR EACH ROW
  EXECUTE FUNCTION update_user_game_stats_updated_at();

-- Enable RLS
ALTER TABLE public.user_game_stats ENABLE ROW LEVEL SECURITY;

-- RLS Policies

-- Users can view their own stats
CREATE POLICY "Users can view their own game stats"
  ON public.user_game_stats
  FOR SELECT
  USING (auth.uid() = user_id);

-- Users can insert their own stats
CREATE POLICY "Users can insert their own game stats"
  ON public.user_game_stats
  FOR INSERT
  WITH CHECK (auth.uid() = user_id);

-- Users can update their own stats
CREATE POLICY "Users can update their own game stats"
  ON public.user_game_stats
  FOR UPDATE
  USING (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);

-- Add comment
COMMENT ON TABLE public.user_game_stats IS 'Stores user game statistics including XP, levels, streaks, and achievements for skulMate games';












