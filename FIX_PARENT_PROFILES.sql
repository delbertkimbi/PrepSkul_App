-- ======================================================
-- COMPREHENSIVE FIX FOR parent_profiles TABLE
-- Run this in Supabase SQL Editor NOW
-- ======================================================

-- Add ALL missing columns to parent_profiles
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

-- Add comments for documentation
COMMENT ON COLUMN public.parent_profiles.city IS 'City where parent lives';
COMMENT ON COLUMN public.parent_profiles.quarter IS 'Quarter/neighborhood';
COMMENT ON COLUMN public.parent_profiles.child_name IS 'Name of the child';
COMMENT ON COLUMN public.parent_profiles.child_date_of_birth IS 'Date of birth of the child';
COMMENT ON COLUMN public.parent_profiles.child_gender IS 'Gender of the child';
COMMENT ON COLUMN public.parent_profiles.learning_path IS 'Child learning path (school/university/skills/exams)';
COMMENT ON COLUMN public.parent_profiles.child_confidence_level IS 'Child confidence level in learning';
COMMENT ON COLUMN public.parent_profiles.challenges IS 'Learning challenges faced by the child';

-- VERIFICATION QUERY
SELECT 
  'parent_profiles table fixed!' AS status,
  COUNT(*) AS total_columns
FROM information_schema.columns 
WHERE table_name = 'parent_profiles' 
AND table_schema = 'public';

-- Show all columns to verify
SELECT column_name, data_type, is_nullable
FROM information_schema.columns 
WHERE table_name = 'parent_profiles' 
AND table_schema = 'public'
ORDER BY column_name;

