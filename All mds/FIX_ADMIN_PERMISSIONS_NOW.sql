-- ============================================
-- QUICK FIX: Set Admin Permissions
-- Run this if you see "You do not have admin permissions"
-- ============================================

-- Step 1: Ensure is_admin column exists
ALTER TABLE profiles 
ADD COLUMN IF NOT EXISTS is_admin BOOLEAN DEFAULT FALSE;

-- Step 2: DROP the constraint FIRST (so we can fix invalid values)
ALTER TABLE profiles 
DROP CONSTRAINT IF EXISTS profiles_user_type_check;

-- Step 3: Fix any invalid user_type values (now that constraint is dropped)
-- Map common variations to correct values
UPDATE profiles 
SET user_type = 'learner' 
WHERE user_type IS NULL 
   OR user_type = '' 
   OR LOWER(user_type) = 'student'  -- Handle 'Student', 'STUDENT', etc.
   OR user_type NOT IN ('learner', 'tutor', 'parent', 'admin');

-- Step 4: Add the constraint back with 'admin' included
ALTER TABLE profiles 
ADD CONSTRAINT profiles_user_type_check 
CHECK (user_type IN ('learner', 'tutor', 'parent', 'admin'));

-- Step 5: Fix admin permissions for prepskul@gmail.com
-- This will work whether profile exists or not
INSERT INTO profiles (id, email, full_name, is_admin, user_type, created_at, updated_at)
SELECT 
  u.id,
  u.email,
  COALESCE(p.full_name, 'PrepSkul Admin'),
  TRUE,  -- Set is_admin = TRUE
  COALESCE(p.user_type, 'admin'),  -- Set user_type = 'admin'
  COALESCE(p.created_at, NOW()),
  NOW()
FROM auth.users u
LEFT JOIN profiles p ON u.id = p.id
WHERE u.email = 'prepskul@gmail.com'
ON CONFLICT (id) DO UPDATE 
SET 
  is_admin = TRUE,  -- Force is_admin to TRUE
  user_type = 'admin',  -- Force user_type to 'admin'
  email = 'prepskul@gmail.com',
  full_name = COALESCE(profiles.full_name, 'PrepSkul Admin'),
  updated_at = NOW();

-- Step 6: Verify the fix
SELECT 
  'Verification' as check_type,
  p.id,
  p.email,
  p.full_name,
  p.is_admin,
  p.user_type,
  CASE 
    WHEN p.is_admin = TRUE THEN '✅ FIXED - is_admin is now TRUE'
    ELSE '❌ STILL BROKEN - is_admin is not TRUE'
  END as status
FROM profiles p
WHERE p.email = 'prepskul@gmail.com';

-- ============================================
-- DONE! Now try logging in again
-- ============================================
-- 
-- If you still see the error, check:
-- 1. User exists in auth.users (should be ✅)
-- 2. Profile exists with correct ID (should be ✅)
-- 3. is_admin = TRUE (should be ✅ after this script)
--
-- Run: All mds/DIAGNOSE_ADMIN_ISSUE.sql to verify
-- ============================================

