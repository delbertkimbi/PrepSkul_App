-- ======================================================
-- MIGRATION 029: Tutor Onboarding Progress Tracking
-- Creates table to track tutor onboarding progress in real-time
-- ======================================================

-- 1. Create tutor_onboarding_progress table
CREATE TABLE IF NOT EXISTS public.tutor_onboarding_progress (
  user_id UUID PRIMARY KEY REFERENCES public.profiles(id) ON DELETE CASCADE,
  current_step INTEGER DEFAULT 0 NOT NULL,
  step_data JSONB DEFAULT '{}'::jsonb NOT NULL,
  completed_steps INTEGER[] DEFAULT '{}'::integer[] NOT NULL,
  is_complete BOOLEAN DEFAULT false NOT NULL,
  skipped_onboarding BOOLEAN DEFAULT false NOT NULL,
  created_at TIMESTAMPTZ DEFAULT NOW() NOT NULL,
  updated_at TIMESTAMPTZ DEFAULT NOW() NOT NULL
);

-- 2. Add onboarding_skipped column to profiles table
ALTER TABLE public.profiles 
ADD COLUMN IF NOT EXISTS onboarding_skipped BOOLEAN DEFAULT false;

-- 3. Create indexes for performance
CREATE INDEX IF NOT EXISTS idx_tutor_onboarding_progress_user_id 
ON public.tutor_onboarding_progress(user_id);

CREATE INDEX IF NOT EXISTS idx_tutor_onboarding_progress_is_complete 
ON public.tutor_onboarding_progress(is_complete) 
WHERE is_complete = false;

CREATE INDEX IF NOT EXISTS idx_tutor_onboarding_progress_skipped 
ON public.tutor_onboarding_progress(skipped_onboarding) 
WHERE skipped_onboarding = true;

-- 4. Create function to update updated_at timestamp
CREATE OR REPLACE FUNCTION update_tutor_onboarding_progress_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- 5. Create trigger to auto-update updated_at
DROP TRIGGER IF EXISTS trigger_update_tutor_onboarding_progress_updated_at 
ON public.tutor_onboarding_progress;

CREATE TRIGGER trigger_update_tutor_onboarding_progress_updated_at
BEFORE UPDATE ON public.tutor_onboarding_progress
FOR EACH ROW
EXECUTE FUNCTION update_tutor_onboarding_progress_updated_at();

-- 6. Enable RLS
ALTER TABLE public.tutor_onboarding_progress ENABLE ROW LEVEL SECURITY;

-- 7. Create RLS policies
-- Policy: Tutors can view their own progress
DROP POLICY IF EXISTS "Tutors can view own onboarding progress" 
ON public.tutor_onboarding_progress;

CREATE POLICY "Tutors can view own onboarding progress"
ON public.tutor_onboarding_progress
FOR SELECT
USING (
  auth.uid() = user_id
);

-- Policy: Tutors can insert their own progress
DROP POLICY IF EXISTS "Tutors can insert own onboarding progress" 
ON public.tutor_onboarding_progress;

CREATE POLICY "Tutors can insert own onboarding progress"
ON public.tutor_onboarding_progress
FOR INSERT
WITH CHECK (
  auth.uid() = user_id
);

-- Policy: Tutors can update their own progress
DROP POLICY IF EXISTS "Tutors can update own onboarding progress" 
ON public.tutor_onboarding_progress;

CREATE POLICY "Tutors can update own onboarding progress"
ON public.tutor_onboarding_progress
FOR UPDATE
USING (
  auth.uid() = user_id
)
WITH CHECK (
  auth.uid() = user_id
);

-- 8. Add comments for documentation
COMMENT ON TABLE public.tutor_onboarding_progress IS 'Tracks real-time progress of tutor onboarding survey';
COMMENT ON COLUMN public.tutor_onboarding_progress.user_id IS 'Foreign key to profiles.id';
COMMENT ON COLUMN public.tutor_onboarding_progress.current_step IS 'Current step number (0-indexed) the tutor is on';
COMMENT ON COLUMN public.tutor_onboarding_progress.step_data IS 'JSONB object storing all answers organized by step number';
COMMENT ON COLUMN public.tutor_onboarding_progress.completed_steps IS 'Array of step numbers that have been completed';
COMMENT ON COLUMN public.tutor_onboarding_progress.is_complete IS 'Whether the entire onboarding process is complete';
COMMENT ON COLUMN public.tutor_onboarding_progress.skipped_onboarding IS 'Whether the tutor chose to skip onboarding after signup';
COMMENT ON COLUMN public.profiles.onboarding_skipped IS 'Quick check flag for whether tutor skipped onboarding';

