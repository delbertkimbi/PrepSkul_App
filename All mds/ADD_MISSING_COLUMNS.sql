-- Add missing columns to profiles table

-- Add survey_completed column if it doesn't exist
ALTER TABLE profiles 
ADD COLUMN IF NOT EXISTS survey_completed BOOLEAN DEFAULT false;

-- Add is_admin column if it doesn't exist
ALTER TABLE profiles 
ADD COLUMN IF NOT EXISTS is_admin BOOLEAN DEFAULT false;

-- Add last_seen column if it doesn't exist (for active user tracking)
ALTER TABLE profiles 
ADD COLUMN IF NOT EXISTS last_seen TIMESTAMP WITH TIME ZONE DEFAULT NOW();

-- Verify the columns were added
SELECT column_name, data_type, is_nullable, column_default
FROM information_schema.columns 
WHERE table_name = 'profiles'
AND column_name IN ('survey_completed', 'is_admin', 'last_seen')
ORDER BY column_name;

