-- ============================================
-- FIX ADMIN LOGIN - RLS Policy Issue
-- Copy and paste this into Supabase SQL Editor
-- ============================================

-- Allow users to read their own profile (needed for admin check)
DROP POLICY IF EXISTS "Users can read own profile" ON profiles;

CREATE POLICY "Users can read own profile"
ON profiles
FOR SELECT
USING (auth.uid() = id);

-- Allow users to update their own profile
DROP POLICY IF EXISTS "Users can update own profile" ON profiles;

CREATE POLICY "Users can update own profile"
ON profiles
FOR UPDATE
USING (auth.uid() = id);

-- Verify the admin user exists and has correct permissions
SELECT id, email, is_admin, user_type 
FROM profiles 
WHERE email = 'prepskul@gmail.com';

-- ============================================
-- DONE! Now try logging in again
-- ============================================

