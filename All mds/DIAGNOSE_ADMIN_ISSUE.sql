-- ============================================
-- DIAGNOSE ADMIN LOGIN ISSUE
-- Run this to see exactly what's wrong
-- ============================================

-- Check 1: Does user exist in auth.users?
SELECT 
  'auth.users check' as check_type,
  CASE 
    WHEN EXISTS(SELECT 1 FROM auth.users WHERE email = 'prepskul@gmail.com') 
    THEN '✅ User exists in auth.users'
    ELSE '❌ User NOT in auth.users'
  END as status,
  id,
  email,
  email_confirmed_at,
  created_at
FROM auth.users 
WHERE email = 'prepskul@gmail.com';

-- Check 2: Does profile exist in profiles table?
SELECT 
  'profiles check' as check_type,
  CASE 
    WHEN EXISTS(SELECT 1 FROM profiles WHERE email = 'prepskul@gmail.com') 
    THEN '✅ Profile exists'
    ELSE '❌ Profile MISSING'
  END as status,
  id,
  email,
  full_name,
  is_admin,
  user_type,
  created_at
FROM profiles 
WHERE email = 'prepskul@gmail.com';

-- Check 3: Are IDs matching?
SELECT 
  'ID matching check' as check_type,
  CASE 
    WHEN u.id = p.id THEN '✅ IDs match'
    WHEN u.id IS NULL THEN '❌ No auth user'
    WHEN p.id IS NULL THEN '❌ No profile'
    ELSE '❌ IDs DO NOT MATCH'
  END as status,
  u.id as auth_id,
  p.id as profile_id,
  u.email as auth_email,
  p.email as profile_email
FROM auth.users u
FULL OUTER JOIN profiles p ON u.id = p.id
WHERE u.email = 'prepskul@gmail.com' OR p.email = 'prepskul@gmail.com';

-- Check 4: Is is_admin set correctly?
SELECT 
  'Admin permission check' as check_type,
  CASE 
    WHEN p.is_admin = TRUE THEN '✅ is_admin = TRUE'
    WHEN p.is_admin = FALSE THEN '❌ is_admin = FALSE (THIS IS THE PROBLEM!)'
    WHEN p.is_admin IS NULL THEN '❌ is_admin = NULL (THIS IS THE PROBLEM!)'
    WHEN p.id IS NULL THEN '❌ Profile does not exist'
    ELSE '❌ Unknown issue'
  END as status,
  p.email,
  p.is_admin,
  p.user_type
FROM profiles p
WHERE p.email = 'prepskul@gmail.com';

-- Check 5: Does is_admin column exist?
SELECT 
  'Column existence check' as check_type,
  CASE 
    WHEN EXISTS (
      SELECT 1 FROM information_schema.columns 
      WHERE table_name = 'profiles' 
      AND column_name = 'is_admin'
    ) THEN '✅ is_admin column exists'
    ELSE '❌ is_admin column MISSING'
  END as status;

-- ============================================
-- SUMMARY: What to fix based on results
-- ============================================
-- 
-- If "Profile MISSING":
--   → Run: All mds/SETUP_ADMIN_USER.sql
--
-- If "is_admin = FALSE" or "is_admin = NULL":
--   → Run: UPDATE profiles SET is_admin = TRUE WHERE email = 'prepskul@gmail.com';
--
-- If "IDs DO NOT MATCH":
--   → Delete profile and recreate it with correct ID
--
-- If "is_admin column MISSING":
--   → Run: ALTER TABLE profiles ADD COLUMN is_admin BOOLEAN DEFAULT FALSE;
--
-- ============================================

