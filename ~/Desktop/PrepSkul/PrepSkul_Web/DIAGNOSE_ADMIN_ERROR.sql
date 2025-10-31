-- ============================================
-- DIAGNOSE ADMIN LOGIN ERROR
-- Run this in Supabase SQL Editor
-- ============================================

-- 1. Check for duplicate admin profiles
SELECT 
  id,
  email,
  is_admin,
  user_type,
  created_at,
  updated_at
FROM profiles 
WHERE email = 'prepskul@gmail.com'
ORDER BY created_at;

-- 2. Count how many profiles exist
SELECT 
  COUNT(*) as total_profiles,
  email
FROM profiles 
WHERE email = 'prepskul@gmail.com'
GROUP BY email;

-- 3. Check if auth user exists
SELECT 
  id,
  email,
  email_confirmed_at,
  created_at
FROM auth.users 
WHERE email = 'prepskul@gmail.com';

-- 4. Check if auth user has corresponding profile
SELECT 
  au.id as auth_id,
  au.email as auth_email,
  p.id as profile_id,
  p.is_admin,
  p.user_type
FROM auth.users au
LEFT JOIN profiles p ON au.id = p.id
WHERE au.email = 'prepskul@gmail.com';

-- 5. Check RLS status
SELECT 
  tablename,
  rowsecurity,
  schemaname
FROM pg_tables 
WHERE tablename = 'profiles' 
AND schemaname = 'public';

-- 6. List all RLS policies on profiles table
SELECT 
  schemaname,
  tablename,
  policyname,
  permissive,
  roles,
  cmd,
  qual,
  with_check
FROM pg_policies
WHERE tablename = 'profiles'
AND schemaname = 'public';

