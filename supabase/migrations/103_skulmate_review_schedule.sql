-- Phase D4: Spaced repetition schedule per game item (SM-2 lite).

CREATE TABLE IF NOT EXISTS public.skulmate_review_items (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  child_id UUID,
  game_id UUID NOT NULL,
  item_index INT NOT NULL CHECK (item_index >= 0),
  concept_key TEXT,
  ease_factor NUMERIC(4, 2) NOT NULL DEFAULT 2.5
    CHECK (ease_factor >= 1.3 AND ease_factor <= 3.5),
  interval_days INT NOT NULL DEFAULT 0 CHECK (interval_days >= 0),
  repetitions INT NOT NULL DEFAULT 0 CHECK (repetitions >= 0),
  next_review_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  last_quality INT CHECK (last_quality >= 0 AND last_quality <= 5),
  last_reviewed_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE UNIQUE INDEX IF NOT EXISTS idx_skulmate_review_items_user_game_item_no_child
  ON public.skulmate_review_items (user_id, game_id, item_index)
  WHERE child_id IS NULL;

CREATE UNIQUE INDEX IF NOT EXISTS idx_skulmate_review_items_user_child_game_item
  ON public.skulmate_review_items (user_id, child_id, game_id, item_index)
  WHERE child_id IS NOT NULL;

CREATE INDEX IF NOT EXISTS idx_skulmate_review_items_due
  ON public.skulmate_review_items (user_id, next_review_at);

CREATE INDEX IF NOT EXISTS idx_skulmate_review_items_due_child
  ON public.skulmate_review_items (user_id, child_id, next_review_at);

COMMENT ON TABLE public.skulmate_review_items IS
  'Per-card spaced repetition schedule. Powers due queue, Scroll feed, and Next stop (Phase D4).';

ALTER TABLE public.skulmate_review_items ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Users read own review items" ON public.skulmate_review_items;
CREATE POLICY "Users read own review items"
  ON public.skulmate_review_items FOR SELECT TO authenticated
  USING (auth.uid() = user_id);

DROP POLICY IF EXISTS "Users insert own review items" ON public.skulmate_review_items;
CREATE POLICY "Users insert own review items"
  ON public.skulmate_review_items FOR INSERT TO authenticated
  WITH CHECK (auth.uid() = user_id);

DROP POLICY IF EXISTS "Users update own review items" ON public.skulmate_review_items;
CREATE POLICY "Users update own review items"
  ON public.skulmate_review_items FOR UPDATE TO authenticated
  USING (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);

DROP POLICY IF EXISTS "Service role manages review items" ON public.skulmate_review_items;
CREATE POLICY "Service role manages review items"
  ON public.skulmate_review_items FOR ALL TO service_role
  USING (true) WITH CHECK (true);
