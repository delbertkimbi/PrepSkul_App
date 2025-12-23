-- ======================================================
-- MIGRATION 030: skulMate Games Feature
-- Creates tables for storing interactive games generated from notes/documents
-- ======================================================

-- 1. Create skulmate_games table for game metadata
CREATE TABLE IF NOT EXISTS public.skulmate_games (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  child_id UUID REFERENCES public.profiles(id) ON DELETE CASCADE, -- For parents creating games for children
  title TEXT NOT NULL,
  game_type TEXT NOT NULL CHECK (game_type IN ('quiz', 'flashcards', 'matching', 'fill_blank')),
  document_url TEXT, -- URL of uploaded document/photo
  source_type TEXT CHECK (source_type IN ('pdf', 'image', 'text')), -- How the game was created
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  is_deleted BOOLEAN DEFAULT false
);

-- 2. Create skulmate_game_data table for game content
CREATE TABLE IF NOT EXISTS public.skulmate_game_data (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  game_id UUID NOT NULL REFERENCES public.skulmate_games(id) ON DELETE CASCADE,
  game_content JSONB NOT NULL, -- Stores questions, answers, items, etc. based on game type
  metadata JSONB, -- Stores difficulty, source info, generation details
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- 3. Create skulmate_game_sessions table for tracking game plays
CREATE TABLE IF NOT EXISTS public.skulmate_game_sessions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  game_id UUID NOT NULL REFERENCES public.skulmate_games(id) ON DELETE CASCADE,
  user_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  score INTEGER DEFAULT 0,
  total_questions INTEGER DEFAULT 0,
  correct_answers INTEGER DEFAULT 0,
  time_taken_seconds INTEGER, -- Time taken to complete game
  answers JSONB, -- Store user's answers for review
  completed_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- 4. Create indexes for better query performance
CREATE INDEX IF NOT EXISTS idx_skulmate_games_user_id ON public.skulmate_games(user_id);
CREATE INDEX IF NOT EXISTS idx_skulmate_games_child_id ON public.skulmate_games(child_id);
CREATE INDEX IF NOT EXISTS idx_skulmate_games_game_type ON public.skulmate_games(game_type);
CREATE INDEX IF NOT EXISTS idx_skulmate_games_created_at ON public.skulmate_games(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_skulmate_game_data_game_id ON public.skulmate_game_data(game_id);
CREATE INDEX IF NOT EXISTS idx_skulmate_game_sessions_game_id ON public.skulmate_game_sessions(game_id);
CREATE INDEX IF NOT EXISTS idx_skulmate_game_sessions_user_id ON public.skulmate_game_sessions(user_id);
CREATE INDEX IF NOT EXISTS idx_skulmate_game_sessions_created_at ON public.skulmate_game_sessions(created_at DESC);

-- 5. Enable Row Level Security
ALTER TABLE public.skulmate_games ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.skulmate_game_data ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.skulmate_game_sessions ENABLE ROW LEVEL SECURITY;

-- 6. Create RLS policies for skulmate_games
-- Drop existing policies if they exist (for idempotency)
DROP POLICY IF EXISTS "Users can view own games" ON public.skulmate_games;
DROP POLICY IF EXISTS "Users can create own games" ON public.skulmate_games;
DROP POLICY IF EXISTS "Users can update own games" ON public.skulmate_games;
DROP POLICY IF EXISTS "Users can delete own games" ON public.skulmate_games;

-- Users can view their own games
CREATE POLICY "Users can view own games"
  ON public.skulmate_games FOR SELECT
  USING (auth.uid() = user_id OR auth.uid() = child_id);

-- Users can insert their own games
CREATE POLICY "Users can create own games"
  ON public.skulmate_games FOR INSERT
  WITH CHECK (auth.uid() = user_id);

-- Users can update their own games
CREATE POLICY "Users can update own games"
  ON public.skulmate_games FOR UPDATE
  USING (auth.uid() = user_id);

-- Users can delete their own games (soft delete)
CREATE POLICY "Users can delete own games"
  ON public.skulmate_games FOR UPDATE
  USING (auth.uid() = user_id);

-- 7. Create RLS policies for skulmate_game_data
-- Drop existing policies if they exist (for idempotency)
DROP POLICY IF EXISTS "Users can view own game data" ON public.skulmate_game_data;
DROP POLICY IF EXISTS "Users can create own game data" ON public.skulmate_game_data;
DROP POLICY IF EXISTS "Users can update own game data" ON public.skulmate_game_data;

-- Users can view game data for their games
CREATE POLICY "Users can view own game data"
  ON public.skulmate_game_data FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM public.skulmate_games
      WHERE skulmate_games.id = skulmate_game_data.game_id
      AND (skulmate_games.user_id = auth.uid() OR skulmate_games.child_id = auth.uid())
    )
  );

-- Users can insert game data for their games
CREATE POLICY "Users can create own game data"
  ON public.skulmate_game_data FOR INSERT
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM public.skulmate_games
      WHERE skulmate_games.id = skulmate_game_data.game_id
      AND skulmate_games.user_id = auth.uid()
    )
  );

-- Users can update game data for their games
CREATE POLICY "Users can update own game data"
  ON public.skulmate_game_data FOR UPDATE
  USING (
    EXISTS (
      SELECT 1 FROM public.skulmate_games
      WHERE skulmate_games.id = skulmate_game_data.game_id
      AND skulmate_games.user_id = auth.uid()
    )
  );

-- 8. Create RLS policies for skulmate_game_sessions
-- Drop existing policies if they exist (for idempotency)
DROP POLICY IF EXISTS "Users can view own game sessions" ON public.skulmate_game_sessions;
DROP POLICY IF EXISTS "Users can create own game sessions" ON public.skulmate_game_sessions;
DROP POLICY IF EXISTS "Users can update own game sessions" ON public.skulmate_game_sessions;

-- Users can view their own game sessions
CREATE POLICY "Users can view own game sessions"
  ON public.skulmate_game_sessions FOR SELECT
  USING (auth.uid() = user_id);

-- Users can create their own game sessions
CREATE POLICY "Users can create own game sessions"
  ON public.skulmate_game_sessions FOR INSERT
  WITH CHECK (auth.uid() = user_id);

-- Users can update their own game sessions
CREATE POLICY "Users can update own game sessions"
  ON public.skulmate_game_sessions FOR UPDATE
  USING (auth.uid() = user_id);

-- 9. Create function to update updated_at timestamp
CREATE OR REPLACE FUNCTION update_skulmate_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- 10. Create triggers for updated_at
-- Drop existing triggers if they exist (for idempotency)
DROP TRIGGER IF EXISTS update_skulmate_games_updated_at ON public.skulmate_games;
DROP TRIGGER IF EXISTS update_skulmate_game_data_updated_at ON public.skulmate_game_data;

CREATE TRIGGER update_skulmate_games_updated_at
  BEFORE UPDATE ON public.skulmate_games
  FOR EACH ROW
  EXECUTE FUNCTION update_skulmate_updated_at();

CREATE TRIGGER update_skulmate_game_data_updated_at
  BEFORE UPDATE ON public.skulmate_game_data
  FOR EACH ROW
  EXECUTE FUNCTION update_skulmate_updated_at();

