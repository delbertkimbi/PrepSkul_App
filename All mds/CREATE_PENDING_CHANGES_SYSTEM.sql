-- Create system to track pending tutor profile changes for admin review
-- This allows admin to see what changed and approve/reject before applying

-- 1. Add pending_changes JSONB column to store changes
ALTER TABLE tutor_profiles
ADD COLUMN IF NOT EXISTS pending_changes JSONB DEFAULT NULL;

-- 2. Add index for faster queries
CREATE INDEX IF NOT EXISTS idx_tutor_profiles_pending_changes 
ON tutor_profiles(has_pending_update) 
WHERE has_pending_update = TRUE;

-- 3. Add comment
COMMENT ON COLUMN tutor_profiles.pending_changes IS 'Stores pending profile changes as JSONB with field names as keys and new values. Only applied after admin approval.';

-- Example structure of pending_changes:
-- {
--   "highest_education_level": "PhD",
--   "bio": "Updated bio text",
--   "availability": {...}
-- }

