-- Fix missing columns in parent_profiles table

-- Add child_confidence_level column if it doesn't exist
ALTER TABLE public.parent_profiles 
ADD COLUMN IF NOT EXISTS child_confidence_level TEXT;

COMMENT ON COLUMN public.parent_profiles.child_confidence_level IS 'Child''s confidence level in learning';

-- Add challenges column if it doesn't exist  
ALTER TABLE public.parent_profiles 
ADD COLUMN IF NOT EXISTS challenges TEXT[];

COMMENT ON COLUMN public.parent_profiles.challenges IS 'Learning challenges faced by the child';

-- Verify columns were added
SELECT column_name, data_type, is_nullable
FROM information_schema.columns 
WHERE table_name = 'parent_profiles' 
AND table_schema = 'public'
AND column_name IN ('child_confidence_level', 'challenges')
ORDER BY column_name;

