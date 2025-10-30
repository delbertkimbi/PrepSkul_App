-- ======================================================
-- MIGRATION 006: Complete parent_profiles Setup
-- Consolidates all parent_profiles fixes
-- ======================================================

-- 1. Add ALL missing columns to parent_profiles
ALTER TABLE public.parent_profiles 
ADD COLUMN IF NOT EXISTS city TEXT,
ADD COLUMN IF NOT EXISTS quarter TEXT,
ADD COLUMN IF NOT EXISTS child_name TEXT,
ADD COLUMN IF NOT EXISTS child_date_of_birth DATE,
ADD COLUMN IF NOT EXISTS child_gender TEXT,
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
ADD COLUMN IF NOT EXISTS child_confidence_level TEXT,
ADD COLUMN IF NOT EXISTS learning_goals TEXT[],
ADD COLUMN IF NOT EXISTS challenges TEXT[];

-- 2. Set default UUID generation for id column
ALTER TABLE public.parent_profiles 
ALTER COLUMN id SET DEFAULT gen_random_uuid();

-- 3. Enable RLS
ALTER TABLE public.parent_profiles ENABLE ROW LEVEL SECURITY;

-- 4. Drop existing policies if they exist
DROP POLICY IF EXISTS "Users can view own parent profile" ON public.parent_profiles;
DROP POLICY IF EXISTS "Users can insert own parent profile" ON public.parent_profiles;
DROP POLICY IF EXISTS "Users can update own parent profile" ON public.parent_profiles;

-- 5. Create RLS policies
CREATE POLICY "Users can view own parent profile"
  ON public.parent_profiles
  FOR SELECT
  USING (auth.uid() = user_id);

CREATE POLICY "Users can insert own parent profile"
  ON public.parent_profiles
  FOR INSERT
  WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update own parent profile"
  ON public.parent_profiles
  FOR UPDATE
  USING (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);

-- 6. Add column comments for documentation
COMMENT ON COLUMN public.parent_profiles.city IS 'City where parent lives';
COMMENT ON COLUMN public.parent_profiles.quarter IS 'Quarter/neighborhood';
COMMENT ON COLUMN public.parent_profiles.child_name IS 'Name of the child';
COMMENT ON COLUMN public.parent_profiles.child_date_of_birth IS 'Date of birth of the child';
COMMENT ON COLUMN public.parent_profiles.child_gender IS 'Gender of the child';
COMMENT ON COLUMN public.parent_profiles.learning_path IS 'Child learning path (school/university/skills/exams)';
COMMENT ON COLUMN public.parent_profiles.child_confidence_level IS 'Child confidence level in learning';
COMMENT ON COLUMN public.parent_profiles.challenges IS 'Learning challenges faced by the child';

-- ======================================================
-- Verification
-- ======================================================
SELECT 
  'parent_profiles setup complete!' AS status,
  COUNT(*) AS total_columns
FROM information_schema.columns 
WHERE table_name = 'parent_profiles' 
AND table_schema = 'public';

