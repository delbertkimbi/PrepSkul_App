-- ======================================================
-- MIGRATION 074: SkulMate pricing + limits configuration
-- Central config for credits-per-generation and daily free limits.
-- Editable by admins, readable by authenticated users.
-- ======================================================

CREATE TABLE IF NOT EXISTS public.skulmate_pricing (
  id INTEGER PRIMARY KEY DEFAULT 1,

  -- Credits pricing (defaults chosen for value perception + margin)
  credits_per_manual_text_game INTEGER NOT NULL DEFAULT 2 CHECK (credits_per_manual_text_game >= 0),
  credits_per_doc_text_game INTEGER NOT NULL DEFAULT 5 CHECK (credits_per_doc_text_game >= 0),
  credits_per_image_game_base INTEGER NOT NULL DEFAULT 10 CHECK (credits_per_image_game_base >= 0),

  -- Limits
  free_doc_text_games_per_day INTEGER NOT NULL DEFAULT 2 CHECK (free_doc_text_games_per_day >= 0),
  free_image_games_per_day INTEGER NOT NULL DEFAULT 4 CHECK (free_image_games_per_day >= 0),
  max_images_per_prompt_paid INTEGER NOT NULL DEFAULT 5 CHECK (max_images_per_prompt_paid >= 1),

  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Ensure the singleton row exists
INSERT INTO public.skulmate_pricing (id)
VALUES (1)
ON CONFLICT (id) DO NOTHING;

ALTER TABLE public.skulmate_pricing ENABLE ROW LEVEL SECURITY;

-- Authenticated users can read pricing config
DROP POLICY IF EXISTS "Authenticated users can read skulmate pricing" ON public.skulmate_pricing;
CREATE POLICY "Authenticated users can read skulmate pricing"
  ON public.skulmate_pricing
  FOR SELECT
  USING (auth.uid() IS NOT NULL);

-- Admins can update pricing config (single row)
DROP POLICY IF EXISTS "Admins can update skulmate pricing" ON public.skulmate_pricing;
CREATE POLICY "Admins can update skulmate pricing"
  ON public.skulmate_pricing
  FOR UPDATE
  USING (
    EXISTS (
      SELECT 1
      FROM public.profiles p
      WHERE p.id = auth.uid() AND p.is_admin = TRUE
    )
  )
  WITH CHECK (
    EXISTS (
      SELECT 1
      FROM public.profiles p
      WHERE p.id = auth.uid() AND p.is_admin = TRUE
    )
  );

-- Service role can manage pricing config
DROP POLICY IF EXISTS "Service role can manage skulmate pricing" ON public.skulmate_pricing;
CREATE POLICY "Service role can manage skulmate pricing"
  ON public.skulmate_pricing
  FOR ALL
  USING (auth.jwt()->>'role' = 'service_role')
  WITH CHECK (auth.jwt()->>'role' = 'service_role');

COMMENT ON TABLE public.skulmate_pricing IS
'Singleton configuration row for SkulMate credits and daily free limits.';

