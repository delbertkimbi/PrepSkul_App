-- ======================================================
-- MIGRATION 025: Fix learner_profiles learning_styles and payment_policy_agreed columns
-- Fixes the mismatch between code (learning_styles array) and database (learning_style text)
-- Also adds missing payment_policy_agreed column to both learner_profiles and parent_profiles
-- ======================================================

-- ======================================================
-- LEARNER_PROFILES TABLE FIXES
-- ======================================================

-- 1. Add learning_styles as TEXT[] (supports multiple selections)
ALTER TABLE public.learner_profiles 
ADD COLUMN IF NOT EXISTS learning_styles TEXT[];

-- 2. Add payment_policy_agreed column (for survey completion validation)
ALTER TABLE public.learner_profiles 
ADD COLUMN IF NOT EXISTS payment_policy_agreed BOOLEAN DEFAULT FALSE;

-- 3. Optionally migrate data from learning_style (TEXT) to learning_styles (TEXT[])
-- If learning_style has a value and learning_styles is empty, copy it
UPDATE public.learner_profiles 
SET learning_styles = ARRAY[learning_style]
WHERE learning_style IS NOT NULL 
  AND learning_style != ''
  AND (learning_styles IS NULL OR array_length(learning_styles, 1) IS NULL);

-- 4. Add comments for documentation
COMMENT ON COLUMN public.learner_profiles.learning_styles IS 'Preferred learning styles (array: Visual, Auditory, Kinesthetic, Reading/Writing, Mixed)';
COMMENT ON COLUMN public.learner_profiles.payment_policy_agreed IS 'Whether user agreed to payment policy during survey';

-- ======================================================
-- PARENT_PROFILES TABLE FIXES
-- ======================================================

-- 5. Add payment_policy_agreed column to parent_profiles (for survey completion validation)
ALTER TABLE public.parent_profiles 
ADD COLUMN IF NOT EXISTS payment_policy_agreed BOOLEAN DEFAULT FALSE;

-- 6. Add comment for documentation
COMMENT ON COLUMN public.parent_profiles.payment_policy_agreed IS 'Whether parent agreed to payment policy during survey';

-- ======================================================
-- Notes:
-- - We keep learning_style (singular) column in learner_profiles for backward compatibility
--   but the app should use learning_styles (plural, TEXT[]) going forward
-- - Both tables now have payment_policy_agreed column for survey validation
-- ======================================================
