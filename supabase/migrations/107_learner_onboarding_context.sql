-- Persist region-specific onboarding answers without forcing every market's
-- optional fields into a new relational column for each school system.
ALTER TABLE public.learner_profiles
  ADD COLUMN IF NOT EXISTS country_code TEXT,
  ADD COLUMN IF NOT EXISTS school_system TEXT,
  ADD COLUMN IF NOT EXISTS onboarding_context JSONB NOT NULL DEFAULT '{}'::jsonb;

ALTER TABLE public.parent_profiles
  ADD COLUMN IF NOT EXISTS country_code TEXT,
  ADD COLUMN IF NOT EXISTS school_system TEXT,
  ADD COLUMN IF NOT EXISTS onboarding_context JSONB NOT NULL DEFAULT '{}'::jsonb;

COMMENT ON COLUMN public.learner_profiles.onboarding_context IS
  'Versioned learner onboarding answers used to personalize SkulMate and tutor recommendations.';
COMMENT ON COLUMN public.parent_profiles.onboarding_context IS
  'Versioned learner onboarding answers supplied by a parent for personalization and tutor recommendations.';
