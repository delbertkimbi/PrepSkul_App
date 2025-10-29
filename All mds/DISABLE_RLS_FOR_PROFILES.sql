-- ============================================
-- TEMPORARY FIX: Disable RLS on profiles table
-- This allows the admin login to work
-- We'll add proper policies later
-- ============================================

-- Disable RLS on profiles table temporarily
ALTER TABLE profiles DISABLE ROW LEVEL SECURITY;

-- Verify admin user
SELECT id, email, is_admin, user_type 
FROM profiles 
WHERE email = 'prepskul@gmail.com';

-- ============================================
-- Try logging in now!
-- ============================================

