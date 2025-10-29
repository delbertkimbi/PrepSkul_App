-- ============================================
-- PrepSkul Admin Setup SQL
-- Run these commands in Supabase SQL Editor
-- ============================================

-- Step 1: Add admin column to profiles table
ALTER TABLE profiles 
ADD COLUMN IF NOT EXISTS is_admin BOOLEAN DEFAULT FALSE;

-- Step 2: Add review columns to tutor_profiles table
ALTER TABLE tutor_profiles 
ADD COLUMN IF NOT EXISTS status TEXT DEFAULT 'pending';

ALTER TABLE tutor_profiles
ADD COLUMN IF NOT EXISTS reviewed_by UUID;

ALTER TABLE tutor_profiles
ADD COLUMN IF NOT EXISTS reviewed_at TIMESTAMPTZ;

ALTER TABLE tutor_profiles
ADD COLUMN IF NOT EXISTS admin_review_notes TEXT;

-- Step 3: Make your user admin (CHANGE EMAIL!)
UPDATE profiles 
SET is_admin = TRUE 
WHERE email = 'prepskul@gmail.com';

-- Step 4: Verify admin was set correctly
SELECT id, email, is_admin, created_at 
FROM profiles 
WHERE is_admin = TRUE;

-- ============================================
-- Done! You should see your email listed above
-- ============================================

