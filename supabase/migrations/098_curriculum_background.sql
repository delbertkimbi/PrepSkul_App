-- Phase B0: Curriculum data (background enrichment only — never blocks generation).

CREATE TABLE IF NOT EXISTS public.curriculum_frameworks (
  id TEXT PRIMARY KEY,
  country_code TEXT NOT NULL DEFAULT 'GLOBAL',
  education_subsystem TEXT,
  label_en TEXT NOT NULL,
  label_fr TEXT NOT NULL,
  exam_board TEXT,
  is_active BOOLEAN NOT NULL DEFAULT true,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS public.curriculum_nodes (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  framework_id TEXT NOT NULL REFERENCES public.curriculum_frameworks(id) ON DELETE CASCADE,
  subject_code TEXT NOT NULL,
  topic_id TEXT NOT NULL UNIQUE,
  title_en TEXT NOT NULL,
  title_fr TEXT NOT NULL,
  grade_levels TEXT[] NOT NULL DEFAULT '{}',
  objectives JSONB NOT NULL DEFAULT '[]'::jsonb,
  parent_topic_id TEXT,
  sort_order INT NOT NULL DEFAULT 0,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_curriculum_nodes_framework
  ON public.curriculum_nodes(framework_id);
CREATE INDEX IF NOT EXISTS idx_curriculum_nodes_subject
  ON public.curriculum_nodes(subject_code);

-- Internal only: alignment + learner snapshot at generation time (not shown in learner UI).
ALTER TABLE public.skulmate_games
  ADD COLUMN IF NOT EXISTS generation_context JSONB NOT NULL DEFAULT '{}'::jsonb;

COMMENT ON COLUMN public.skulmate_games.generation_context IS
  'Background generation metadata (learnerContext, optional curriculum alignment). Not surfaced in learner UI.';

INSERT INTO public.curriculum_frameworks (id, country_code, education_subsystem, label_en, label_fr, exam_board)
VALUES
  ('open_learning', 'GLOBAL', 'open', 'Open learning', 'Apprentissage libre', NULL),
  ('cm_gce_ol', 'CM', 'anglophone', 'GCE Ordinary Level', 'GCE niveau O', 'GCE_OL'),
  ('cm_gce_al', 'CM', 'anglophone', 'GCE Advanced Level', 'GCE niveau A', 'GCE_AL'),
  ('cm_francophone', 'CM', 'francophone', 'Francophone secondary', 'Secondaire francophone', 'BEPC_PROBATOIRE'),
  ('waec', 'GLOBAL', 'anglophone', 'WAEC', 'WAEC', 'WAEC'),
  ('steam', 'GLOBAL', 'open', 'STEAM', 'STEAM', NULL)
ON CONFLICT (id) DO NOTHING;

ALTER TABLE public.curriculum_frameworks ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.curriculum_nodes ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Anyone authenticated can read curriculum frameworks" ON public.curriculum_frameworks;
CREATE POLICY "Anyone authenticated can read curriculum frameworks"
  ON public.curriculum_frameworks FOR SELECT TO authenticated USING (true);

DROP POLICY IF EXISTS "Anyone authenticated can read curriculum nodes" ON public.curriculum_nodes;
CREATE POLICY "Anyone authenticated can read curriculum nodes"
  ON public.curriculum_nodes FOR SELECT TO authenticated USING (true);

DROP POLICY IF EXISTS "Service role manages curriculum frameworks" ON public.curriculum_frameworks;
CREATE POLICY "Service role manages curriculum frameworks"
  ON public.curriculum_frameworks FOR ALL TO service_role USING (true) WITH CHECK (true);

DROP POLICY IF EXISTS "Service role manages curriculum nodes" ON public.curriculum_nodes;
CREATE POLICY "Service role manages curriculum nodes"
  ON public.curriculum_nodes FOR ALL TO service_role USING (true) WITH CHECK (true);
