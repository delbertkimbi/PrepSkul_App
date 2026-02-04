-- ======================================================
-- MIGRATION 050: Parent learners (multiple children) and booking_group_id for trial_sessions
-- Supports "My children" and multi-learner same-tutor booking with per-learner accept/decline
-- ======================================================

-- 1. Parent learners: one row per child linked to a parent (user_id)
CREATE TABLE IF NOT EXISTS public.parent_learners (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  parent_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  name TEXT NOT NULL,
  education_level TEXT,
  class_level TEXT,
  display_order INTEGER NOT NULL DEFAULT 0,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_parent_learners_parent_id ON public.parent_learners(parent_id);

COMMENT ON TABLE public.parent_learners IS 'Children/learners linked to a parent for booking (who is this for?)';
COMMENT ON COLUMN public.parent_learners.parent_id IS 'Parent user id (auth.users)';
COMMENT ON COLUMN public.parent_learners.name IS 'Child display name';
COMMENT ON COLUMN public.parent_learners.education_level IS 'E.g. Primary, Secondary, University';
COMMENT ON COLUMN public.parent_learners.class_level IS 'E.g. Form 5, Primary 3';
COMMENT ON COLUMN public.parent_learners.display_order IS 'Order in My children list';

-- RLS
ALTER TABLE public.parent_learners ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Users can view own parent learners" ON public.parent_learners;
DROP POLICY IF EXISTS "Users can insert own parent learners" ON public.parent_learners;
DROP POLICY IF EXISTS "Users can update own parent learners" ON public.parent_learners;
DROP POLICY IF EXISTS "Users can delete own parent learners" ON public.parent_learners;

CREATE POLICY "Users can view own parent learners"
  ON public.parent_learners FOR SELECT
  USING (auth.uid() = parent_id);

CREATE POLICY "Users can insert own parent learners"
  ON public.parent_learners FOR INSERT
  WITH CHECK (auth.uid() = parent_id);

CREATE POLICY "Users can update own parent learners"
  ON public.parent_learners FOR UPDATE
  USING (auth.uid() = parent_id)
  WITH CHECK (auth.uid() = parent_id);

CREATE POLICY "Users can delete own parent learners"
  ON public.parent_learners FOR DELETE
  USING (auth.uid() = parent_id);

-- 2. booking_group_id on trial_sessions: link N trials when parent books same tutor for 2+ children
ALTER TABLE public.trial_sessions
  ADD COLUMN IF NOT EXISTS booking_group_id UUID;

COMMENT ON COLUMN public.trial_sessions.booking_group_id IS 'When set, this trial is part of a multi-learner same-tutor booking; all trials in the group share this UUID';

-- Optional: learner_label for display (child name when learner_id is parent)
ALTER TABLE public.trial_sessions
  ADD COLUMN IF NOT EXISTS learner_label TEXT;

COMMENT ON COLUMN public.trial_sessions.learner_label IS 'Display name for learner (e.g. child name) when parent books for a child';
