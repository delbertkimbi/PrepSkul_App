-- Phase C2: Link mastery rows to last played game for gentle resurfacing.

ALTER TABLE public.skulmate_concept_mastery
  ADD COLUMN IF NOT EXISTS last_game_id UUID REFERENCES public.skulmate_games(id) ON DELETE SET NULL;

CREATE INDEX IF NOT EXISTS idx_skulmate_concept_mastery_last_game
  ON public.skulmate_concept_mastery (last_game_id)
  WHERE last_game_id IS NOT NULL;
