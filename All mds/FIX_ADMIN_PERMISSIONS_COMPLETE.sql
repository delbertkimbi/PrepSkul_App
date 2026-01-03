-- ============================================
-- COMPLETE ADMIN PERMISSIONS FIX
-- Run this in Supabase SQL Editor
-- This will diagnose AND fix the issue
-- ============================================

-- STEP 1: Ensure is_admin column exists
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_schema = 'public' 
    AND table_name = 'profiles' 
    AND column_name = 'is_admin'
  ) THEN
    ALTER TABLE profiles ADD COLUMN is_admin BOOLEAN DEFAULT FALSE;
    RAISE NOTICE '✅ Created is_admin column';
  ELSE
    RAISE NOTICE '✅ is_admin column already exists';
  END IF;
END $$;

-- STEP 2: Check current state (DIAGNOSIS)
SELECT 
  '🔍 DIAGNOSIS' as step,
  u.id as auth_user_id,
  u.email as auth_email,
  u.email_confirmed_at,
  p.id as profile_id,
  p.email as profile_email,
  p.is_admin,
  p.user_type,
  CASE 
    WHEN u.id IS NULL THEN '❌ User NOT in auth.users'
    WHEN p.id IS NULL THEN '❌ Profile MISSING'
    WHEN u.id != p.id THEN '❌ IDs DO NOT MATCH'
    WHEN p.is_admin IS NULL THEN '❌ is_admin is NULL'
    WHEN p.is_admin = FALSE THEN '❌ is_admin is FALSE'
    WHEN p.is_admin = TRUE THEN '✅ is_admin is TRUE (GOOD!)'
    ELSE '❓ Unknown state'
  END as status
FROM auth.users u
LEFT JOIN profiles p ON u.id = p.id
WHERE u.email = 'prepskul@gmail.com';

-- STEP 3: Fix user_type constraint (if needed)
DO $$
BEGIN
  -- Drop constraint if it exists
  IF EXISTS (
    SELECT 1 FROM pg_constraint 
    WHERE conname = 'profiles_user_type_check'
  ) THEN
    ALTER TABLE profiles DROP CONSTRAINT profiles_user_type_check;
    RAISE NOTICE '✅ Dropped user_type constraint';
  END IF;
  
  -- Fix any invalid user_type values
  UPDATE profiles 
  SET user_type = 'learner' 
  WHERE user_type IS NULL 
     OR user_type = '' 
     OR LOWER(user_type) = 'student'
     OR user_type NOT IN ('learner', 'tutor', 'parent', 'admin');
  
  -- Re-add constraint with 'admin' included
  ALTER TABLE profiles 
  ADD CONSTRAINT profiles_user_type_check 
  CHECK (user_type IN ('learner', 'tutor', 'parent', 'admin'));
  
  RAISE NOTICE '✅ Fixed user_type constraint';
END $$;

-- STEP 4: Fix admin permissions (WORKS FOR ALL CASES)
-- This handles: missing profile, existing profile, wrong is_admin value
INSERT INTO profiles (id, email, full_name, is_admin, user_type, created_at, updated_at)
SELECT 
  u.id,
  u.email,
  COALESCE(p.full_name, 'PrepSkul Admin'),
  TRUE,  -- FORCE is_admin = TRUE
  COALESCE(p.user_type, 'admin'),  -- Set user_type = 'admin' if missing
  COALESCE(p.created_at, NOW()),
  NOW()
FROM auth.users u
LEFT JOIN profiles p ON u.id = p.id
WHERE u.email = 'prepskul@gmail.com'
ON CONFLICT (id) DO UPDATE 
SET 
  is_admin = TRUE,  -- FORCE is_admin to TRUE (overwrites any FALSE/NULL)
  user_type = COALESCE(EXCLUDED.user_type, 'admin'),  -- Ensure user_type is 'admin'
  email = EXCLUDED.email,
  full_name = COALESCE(profiles.full_name, EXCLUDED.full_name, 'PrepSkul Admin'),
  updated_at = NOW();

-- STEP 5: Verify the fix
SELECT 
  '✅ VERIFICATION' as step,
  p.id,
  p.email,
  p.full_name,
  p.is_admin,
  p.user_type,
  CASE 
    WHEN p.is_admin = TRUE THEN '✅ SUCCESS - is_admin is now TRUE'
    ELSE '❌ FAILED - is_admin is still not TRUE'
  END as final_status
FROM profiles p
WHERE p.email = 'prepskul@gmail.com';

-- STEP 6: Double-check with auth.users join
SELECT 
  '✅ FINAL CHECK' as step,
  u.email as auth_email,
  p.email as profile_email,
  u.id = p.id as ids_match,
  p.is_admin,
  p.user_type,
  CASE 
    WHEN u.id = p.id AND p.is_admin = TRUE THEN '✅ PERFECT - Ready to login!'
    WHEN u.id != p.id THEN '❌ IDs do not match - contact support'
    WHEN p.is_admin != TRUE THEN '❌ is_admin is not TRUE - run this script again'
    ELSE '❓ Unknown issue'
  END as final_status
FROM auth.users u
INNER JOIN profiles p ON u.id = p.id
WHERE u.email = 'prepskul@gmail.com';

-- ============================================
-- DONE! 
-- ============================================
-- 
-- If you see "✅ PERFECT - Ready to login!" above,
-- then you should be able to log in now.
--
-- If you still see errors:
-- 1. Make sure the user exists in auth.users
-- 2. Make sure you're using the correct email
-- 3. Try logging out and logging back in
-- 4. Clear browser cache/cookies
--
-- ============================================

