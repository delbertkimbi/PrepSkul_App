-- ======================================================
-- MIGRATION 007: Complete learner_profiles Setup
-- Ensures student surveys work correctly
-- ======================================================

-- 1. Ensure learner_profiles table exists with all needed columns
-- (Skip if already created, but add any missing columns)

-- Add ALL columns that student survey needs
ALTER TABLE public.learner_profiles 
ADD COLUMN IF NOT EXISTS city TEXT,
ADD COLUMN IF NOT EXISTS quarter TEXT,
ADD COLUMN IF NOT EXISTS learning_path TEXT,
ADD COLUMN IF NOT EXISTS education_level TEXT,
ADD COLUMN IF NOT EXISTS class_level TEXT,
ADD COLUMN IF NOT EXISTS stream TEXT,
ADD COLUMN IF NOT EXISTS subjects TEXT[],
ADD COLUMN IF NOT EXISTS university_courses TEXT[],
ADD COLUMN IF NOT EXISTS skill_category TEXT,
ADD COLUMN IF NOT EXISTS skills TEXT[],
ADD COLUMN IF NOT EXISTS exam_type TEXT,
ADD COLUMN IF NOT EXISTS specific_exam TEXT,
ADD COLUMN IF NOT EXISTS exam_subjects TEXT[],
ADD COLUMN IF NOT EXISTS budget_min INTEGER,
ADD COLUMN IF NOT EXISTS budget_max INTEGER,
ADD COLUMN IF NOT EXISTS tutor_gender_preference TEXT,
ADD COLUMN IF NOT EXISTS tutor_qualification_preference TEXT,
ADD COLUMN IF NOT EXISTS preferred_location TEXT,
ADD COLUMN IF NOT EXISTS preferred_schedule TEXT[],
ADD COLUMN IF NOT EXISTS learning_style TEXT,
ADD COLUMN IF NOT EXISTS confidence_level TEXT,
ADD COLUMN IF NOT EXISTS learning_goals TEXT[],
ADD COLUMN IF NOT EXISTS challenges TEXT[];

-- 2. Set default UUID generation for id column
ALTER TABLE public.learner_profiles 
ALTER COLUMN id SET DEFAULT gen_random_uuid();

-- 3. Enable RLS
ALTER TABLE public.learner_profiles ENABLE ROW LEVEL SECURITY;

-- 4. Drop existing policies if they exist
DROP POLICY IF EXISTS "Users can view own learner profile" ON public.learner_profiles;
DROP POLICY IF EXISTS "Users can insert own learner profile" ON public.learner_profiles;
DROP POLICY IF EXISTS "Users can update own learner profile" ON public.learner_profiles;

-- 5. Create RLS policies
CREATE POLICY "Users can view own learner profile"
  ON public.learner_profiles
  FOR SELECT
  USING (auth.uid() = user_id);

CREATE POLICY "Users can insert own learner profile"
  ON public.learner_profiles
  FOR INSERT
  WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update own learner profile"
  ON public.learner_profiles
  FOR UPDATE
  USING (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);

-- 6. Add column comments for documentation
COMMENT ON COLUMN public.learner_profiles.city IS 'City where student lives';
COMMENT ON COLUMN public.learner_profiles.quarter IS 'Quarter/neighborhood';
COMMENT ON COLUMN public.learner_profiles.learning_path IS 'Student learning path (school/university/skills/exams)';
COMMENT ON COLUMN public.learner_profiles.learning_style IS 'Preferred learning style';
COMMENT ON COLUMN public.learner_profiles.confidence_level IS 'Student confidence level in learning';
COMMENT ON COLUMN public.learner_profiles.challenges IS 'Learning challenges faced by the student';

-- ======================================================
-- Verification
-- ======================================================
SELECT 
  'learner_profiles setup complete!' AS status,
  COUNT(*) AS total_columns
FROM information_schema.columns 
WHERE table_name = 'learner_profiles' 
AND table_schema = 'public';

