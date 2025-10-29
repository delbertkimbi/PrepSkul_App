-- ============================================
-- QUICK ADMIN SETUP - Copy and paste this entire file
-- Run in Supabase SQL Editor
-- ============================================

-- Step 1: Add is_admin column to profiles
ALTER TABLE profiles ADD COLUMN IF NOT EXISTS is_admin BOOLEAN DEFAULT FALSE;

-- Step 2: Update the user_type constraint to include 'admin'
ALTER TABLE profiles DROP CONSTRAINT IF EXISTS profiles_user_type_check;
ALTER TABLE profiles ADD CONSTRAINT profiles_user_type_check 
CHECK (user_type IN ('learner', 'tutor', 'parent', 'admin'));

-- Step 3: Create admin profile from existing auth user
-- This links to the existing auth.users entry
INSERT INTO profiles (id, email, full_name, is_admin, user_type)
SELECT 
  id, 
  email, 
  'PrepSkul Admin',
  TRUE,
  'admin'
FROM auth.users 
WHERE email = 'prepskul@gmail.com'
ON CONFLICT (id) DO UPDATE 
SET is_admin = TRUE, user_type = 'admin';

-- Step 4: Add review columns to tutor_profiles (for admin features)
ALTER TABLE tutor_profiles ADD COLUMN IF NOT EXISTS status TEXT DEFAULT 'pending';
ALTER TABLE tutor_profiles ADD COLUMN IF NOT EXISTS reviewed_by UUID REFERENCES profiles(id);
ALTER TABLE tutor_profiles ADD COLUMN IF NOT EXISTS reviewed_at TIMESTAMPTZ;
ALTER TABLE tutor_profiles ADD COLUMN IF NOT EXISTS admin_review_notes TEXT;

-- Step 5: Add last_seen for active user tracking
ALTER TABLE profiles ADD COLUMN IF NOT EXISTS last_seen TIMESTAMPTZ DEFAULT NOW();

-- Step 6: Verify admin was created
SELECT id, email, is_admin, user_type FROM profiles WHERE email = 'prepskul@gmail.com';

-- ============================================
-- DONE! You should see your admin user above.
-- 
-- NOW LOGIN:
-- URL: http://localhost:3003/admin/login
-- Email: prepskul@gmail.com
-- Password: (whatever you set in Supabase Auth)
-- ============================================

