-- ======================================================
-- MIGRATION 086: Split mobile child profiles from offline account links
--
-- Problem: PrepSkul_Web offline-ops migrations reused `parent_learners` and renamed
-- `parent_id` → `parent_user_id` for auth-account links (parent_user_id + learner_user_id).
-- PrepSkul_App uses `parent_learners` for child profile records (parent_id + name + survey fields).
--
-- Fix:
--   1. Create `parent_learner_account_links` for Web offline parent↔learner auth links
--   2. Migrate any existing link rows out of `parent_learners`
--   3. Restore `parent_learners` to the mobile-app schema and RLS
-- Safe to run multiple times.
-- ======================================================

-- ---------------------------------------------------------------------------
-- 1) Offline ops: parent auth user ↔ learner auth user links (Web only)
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.parent_learner_account_links (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  parent_user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  learner_user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  UNIQUE (parent_user_id, learner_user_id)
);

CREATE INDEX IF NOT EXISTS idx_parent_learner_account_links_parent
  ON public.parent_learner_account_links(parent_user_id);
CREATE INDEX IF NOT EXISTS idx_parent_learner_account_links_learner
  ON public.parent_learner_account_links(learner_user_id);

COMMENT ON TABLE public.parent_learner_account_links IS
  'Offline-ops: links a parent auth account to a learner auth account (Web admin onboarding).';
COMMENT ON TABLE public.parent_learners IS
  'Mobile app: child profile records for a parent (name, education, survey fields). Not auth-user links.';

ALTER TABLE public.parent_learner_account_links ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Service role full access parent_learner_account_links"
  ON public.parent_learner_account_links;
CREATE POLICY "Service role full access parent_learner_account_links"
  ON public.parent_learner_account_links
  FOR ALL TO service_role
  USING (true)
  WITH CHECK (true);

-- ---------------------------------------------------------------------------
-- 2) Move Web-style link rows out of parent_learners (if present)
-- ---------------------------------------------------------------------------
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.tables
    WHERE table_schema = 'public' AND table_name = 'parent_learners'
  ) THEN
    RETURN;
  END IF;

  IF EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = 'public' AND table_name = 'parent_learners' AND column_name = 'learner_user_id'
  ) AND EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = 'public' AND table_name = 'parent_learners' AND column_name = 'parent_user_id'
  ) THEN
    INSERT INTO public.parent_learner_account_links (parent_user_id, learner_user_id, created_at)
    SELECT pl.parent_user_id, pl.learner_user_id, COALESCE(pl.created_at, NOW())
    FROM public.parent_learners pl
    WHERE pl.learner_user_id IS NOT NULL
      AND pl.parent_user_id IS NOT NULL
    ON CONFLICT (parent_user_id, learner_user_id) DO NOTHING;

    DELETE FROM public.parent_learners pl
    WHERE pl.learner_user_id IS NOT NULL;
  END IF;

  IF EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = 'public' AND table_name = 'parent_learners' AND column_name = 'learner_user_id'
  ) AND EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = 'public' AND table_name = 'parent_learners' AND column_name = 'parent_id'
  ) THEN
    INSERT INTO public.parent_learner_account_links (parent_user_id, learner_user_id, created_at)
    SELECT pl.parent_id, pl.learner_user_id, COALESCE(pl.created_at, NOW())
    FROM public.parent_learners pl
    WHERE pl.learner_user_id IS NOT NULL
      AND pl.parent_id IS NOT NULL
    ON CONFLICT (parent_user_id, learner_user_id) DO NOTHING;

    DELETE FROM public.parent_learners pl
    WHERE pl.learner_user_id IS NOT NULL;
  END IF;
END $$;

-- Drop Web-only unique constraint / indexes on parent_learners if they exist
ALTER TABLE public.parent_learners
  DROP CONSTRAINT IF EXISTS parent_learners_parent_user_id_learner_user_id_key;
DROP INDEX IF EXISTS public.idx_parent_learners_parent;
DROP INDEX IF EXISTS public.idx_parent_learners_learner;

-- ---------------------------------------------------------------------------
-- 3) Restore mobile-app column name: parent_user_id → parent_id
-- ---------------------------------------------------------------------------
DO $$
BEGIN
  IF EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = 'public' AND table_name = 'parent_learners' AND column_name = 'parent_user_id'
  ) AND NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = 'public' AND table_name = 'parent_learners' AND column_name = 'parent_id'
  ) THEN
    ALTER TABLE public.parent_learners RENAME COLUMN parent_user_id TO parent_id;
  END IF;
END $$;

-- Remove offline-only columns from the child-profile table
ALTER TABLE public.parent_learners DROP COLUMN IF EXISTS learner_user_id;
ALTER TABLE public.parent_learners DROP COLUMN IF EXISTS learner_id;

-- ---------------------------------------------------------------------------
-- 4) Ensure mobile child-profile columns exist (050 + 055)
-- ---------------------------------------------------------------------------
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

ALTER TABLE public.parent_learners
  ADD COLUMN IF NOT EXISTS parent_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
  ADD COLUMN IF NOT EXISTS name TEXT,
  ADD COLUMN IF NOT EXISTS education_level TEXT,
  ADD COLUMN IF NOT EXISTS class_level TEXT,
  ADD COLUMN IF NOT EXISTS display_order INTEGER NOT NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS created_at TIMESTAMPTZ DEFAULT NOW(),
  ADD COLUMN IF NOT EXISTS updated_at TIMESTAMPTZ DEFAULT NOW(),
  ADD COLUMN IF NOT EXISTS date_of_birth DATE,
  ADD COLUMN IF NOT EXISTS gender TEXT,
  ADD COLUMN IF NOT EXISTS relationship_to_child TEXT,
  ADD COLUMN IF NOT EXISTS learning_path TEXT,
  ADD COLUMN IF NOT EXISTS stream TEXT,
  ADD COLUMN IF NOT EXISTS subjects TEXT[],
  ADD COLUMN IF NOT EXISTS university_courses TEXT,
  ADD COLUMN IF NOT EXISTS skill_category TEXT,
  ADD COLUMN IF NOT EXISTS skills TEXT[],
  ADD COLUMN IF NOT EXISTS exam_type TEXT,
  ADD COLUMN IF NOT EXISTS specific_exam TEXT,
  ADD COLUMN IF NOT EXISTS exam_subjects TEXT[],
  ADD COLUMN IF NOT EXISTS confidence_level TEXT,
  ADD COLUMN IF NOT EXISTS learning_goals TEXT[],
  ADD COLUMN IF NOT EXISTS challenges TEXT[],
  ADD COLUMN IF NOT EXISTS tutor_gender_preference TEXT,
  ADD COLUMN IF NOT EXISTS tutor_qualification_preference TEXT,
  ADD COLUMN IF NOT EXISTS preferred_location TEXT,
  ADD COLUMN IF NOT EXISTS preferred_schedule TEXT[];

CREATE INDEX IF NOT EXISTS idx_parent_learners_parent_id ON public.parent_learners(parent_id);
CREATE INDEX IF NOT EXISTS idx_parent_learners_learning_path ON public.parent_learners(learning_path);
CREATE INDEX IF NOT EXISTS idx_parent_learners_education_level ON public.parent_learners(education_level);

-- ---------------------------------------------------------------------------
-- 5) Restore mobile-app RLS on parent_learners
-- ---------------------------------------------------------------------------
ALTER TABLE public.parent_learners ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Service role full access parent_learners" ON public.parent_learners;
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

-- Service role can manage child profiles for admin/support tooling
CREATE POLICY "Service role full access parent_learners"
  ON public.parent_learners
  FOR ALL TO service_role
  USING (true)
  WITH CHECK (true);
