-- ===================================
-- ADD user_id COLUMN TO LEARNER_PROFILES
-- Quick fix - run this now!
-- ===================================

-- Add user_id column to learner_profiles
ALTER TABLE learner_profiles 
ADD COLUMN IF NOT EXISTS user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE;

-- Create index for performance
CREATE INDEX IF NOT EXISTS idx_learner_profiles_user_id ON learner_profiles(user_id);

-- Add unique constraint (one profile per user)
ALTER TABLE learner_profiles 
DROP CONSTRAINT IF EXISTS learner_profiles_user_id_key;

ALTER TABLE learner_profiles 
ADD CONSTRAINT learner_profiles_user_id_key UNIQUE(user_id);

-- Do the same for parent_profiles
ALTER TABLE parent_profiles 
ADD COLUMN IF NOT EXISTS user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE;

CREATE INDEX IF NOT EXISTS idx_parent_profiles_user_id ON parent_profiles(user_id);

ALTER TABLE parent_profiles 
DROP CONSTRAINT IF EXISTS parent_profiles_user_id_key;

ALTER TABLE parent_profiles 
ADD CONSTRAINT parent_profiles_user_id_key UNIQUE(user_id);

-- Success!
SELECT 'user_id columns added successfully! ✅' AS status;

