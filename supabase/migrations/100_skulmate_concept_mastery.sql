-- Phase C1: Per-topic mastery graph (background signal for rerouting — not learner syllabus UI).

CREATE TABLE IF NOT EXISTS public.skulmate_concept_mastery (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  child_id UUID,
  topic_id TEXT NOT NULL,
  framework_id TEXT,
  mastery_score NUMERIC(5, 4) NOT NULL DEFAULT 0
    CHECK (mastery_score >= 0 AND mastery_score <= 1),
  attempts INT NOT NULL DEFAULT 0,
  correct_total INT NOT NULL DEFAULT 0,
  question_total INT NOT NULL DEFAULT 0,
  weak_streak INT NOT NULL DEFAULT 0,
  last_session_accuracy NUMERIC(5, 4),
  last_seen_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE UNIQUE INDEX IF NOT EXISTS idx_skulmate_concept_mastery_user_topic_no_child
  ON public.skulmate_concept_mastery (user_id, topic_id)
  WHERE child_id IS NULL;

CREATE UNIQUE INDEX IF NOT EXISTS idx_skulmate_concept_mastery_user_child_topic
  ON public.skulmate_concept_mastery (user_id, child_id, topic_id)
  WHERE child_id IS NOT NULL;

CREATE INDEX IF NOT EXISTS idx_skulmate_concept_mastery_weak
  ON public.skulmate_concept_mastery (user_id, mastery_score, weak_streak);

COMMENT ON TABLE public.skulmate_concept_mastery IS
  'Estimated mastery per curriculum/open topic. Powers weak-topic rerouting (Phase C).';

ALTER TABLE public.skulmate_concept_mastery ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Users read own concept mastery" ON public.skulmate_concept_mastery;
CREATE POLICY "Users read own concept mastery"
  ON public.skulmate_concept_mastery FOR SELECT TO authenticated
  USING (auth.uid() = user_id);

DROP POLICY IF EXISTS "Users insert own concept mastery" ON public.skulmate_concept_mastery;
CREATE POLICY "Users insert own concept mastery"
  ON public.skulmate_concept_mastery FOR INSERT TO authenticated
  WITH CHECK (auth.uid() = user_id);

DROP POLICY IF EXISTS "Users update own concept mastery" ON public.skulmate_concept_mastery;
CREATE POLICY "Users update own concept mastery"
  ON public.skulmate_concept_mastery FOR UPDATE TO authenticated
  USING (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);

DROP POLICY IF EXISTS "Service role manages concept mastery" ON public.skulmate_concept_mastery;
CREATE POLICY "Service role manages concept mastery"
  ON public.skulmate_concept_mastery FOR ALL TO service_role
  USING (true) WITH CHECK (true);
