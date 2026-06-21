-- Phase D1: Turn-by-turn lesson paths (Path mode).

CREATE TABLE IF NOT EXISTS public.skulmate_lessons (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  child_id UUID,
  source_game_id UUID REFERENCES public.skulmate_games(id) ON DELETE SET NULL,
  topic TEXT NOT NULL,
  steps JSONB NOT NULL DEFAULT '[]'::jsonb,
  current_step INT NOT NULL DEFAULT 0 CHECK (current_step >= 0),
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_skulmate_lessons_user
  ON public.skulmate_lessons (user_id, updated_at DESC);

CREATE INDEX IF NOT EXISTS idx_skulmate_lessons_user_child
  ON public.skulmate_lessons (user_id, child_id, updated_at DESC);

COMMENT ON TABLE public.skulmate_lessons IS
  'Ordered lesson paths for SkulMate Path mode (Phase D1). Steps stored as jsonb array.';

ALTER TABLE public.skulmate_lessons ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Users read own lessons" ON public.skulmate_lessons;
CREATE POLICY "Users read own lessons"
  ON public.skulmate_lessons FOR SELECT TO authenticated
  USING (auth.uid() = user_id);

DROP POLICY IF EXISTS "Users insert own lessons" ON public.skulmate_lessons;
CREATE POLICY "Users insert own lessons"
  ON public.skulmate_lessons FOR INSERT TO authenticated
  WITH CHECK (auth.uid() = user_id);

DROP POLICY IF EXISTS "Users update own lessons" ON public.skulmate_lessons;
CREATE POLICY "Users update own lessons"
  ON public.skulmate_lessons FOR UPDATE TO authenticated
  USING (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);

DROP POLICY IF EXISTS "Service role manages lessons" ON public.skulmate_lessons;
CREATE POLICY "Service role manages lessons"
  ON public.skulmate_lessons FOR ALL TO service_role
  USING (true) WITH CHECK (true);
