-- Fix missing columns in parent_profiles table

-- Add child info columns if they don't exist
ALTER TABLE public.parent_profiles 
ADD COLUMN IF NOT EXISTS child_name TEXT,
ADD COLUMN IF NOT EXISTS child_date_of_birth DATE,
ADD COLUMN IF NOT EXISTS child_gender TEXT;

-- Add learning columns if they don't exist
ALTER TABLE public.parent_profiles 
ADD COLUMN IF NOT EXISTS child_confidence_level TEXT,
ADD COLUMN IF NOT EXISTS challenges TEXT[];

-- Add comments for documentation
COMMENT ON COLUMN public.parent_profiles.child_name IS 'Name of the child';
COMMENT ON COLUMN public.parent_profiles.child_date_of_birth IS 'Date of birth of the child';
COMMENT ON COLUMN public.parent_profiles.child_gender IS 'Gender of the child';
COMMENT ON COLUMN public.parent_profiles.child_confidence_level IS 'Child''s confidence level in learning';
COMMENT ON COLUMN public.parent_profiles.challenges IS 'Learning challenges faced by the child';

-- Verify all columns were added
SELECT column_name, data_type, is_nullable
FROM information_schema.columns 
WHERE table_name = 'parent_profiles' 
AND table_schema = 'public'
AND column_name IN ('child_name', 'child_date_of_birth', 'child_gender', 'child_confidence_level', 'challenges')
ORDER BY column_name;

