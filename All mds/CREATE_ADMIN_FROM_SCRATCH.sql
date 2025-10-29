-- ============================================
-- CREATE ADMIN USER FROM SCRATCH
-- Run this entire script in Supabase SQL Editor
-- ============================================

-- Step 1: Check if auth user exists
SELECT id, email FROM auth.users WHERE email = 'prepskul@gmail.com';

-- Step 2: If the above returns a user, create the profile
-- If not, you need to create the user in Supabase Auth Dashboard first

-- Step 3: Create the profile entry linked to the auth user
INSERT INTO profiles (id, email, full_name, is_admin, user_type, created_at, updated_at)
SELECT 
  id,
  email,
  'PrepSkul Admin',
  TRUE,
  'admin',
  NOW(),
  NOW()
FROM auth.users 
WHERE email = 'prepskul@gmail.com'
ON CONFLICT (id) DO UPDATE 
SET 
  is_admin = TRUE, 
  user_type = 'admin',
  full_name = 'PrepSkul Admin';

-- Step 4: Verify the profile was created
SELECT id, email, is_admin, user_type, created_at 
FROM profiles 
WHERE email = 'prepskul@gmail.com';

-- Step 5: Make sure RLS is disabled for testing
ALTER TABLE profiles DISABLE ROW LEVEL SECURITY;

-- ============================================
-- DONE! You should see 1 profile above
-- Now try logging in at http://localhost:3003/admin/login
-- ============================================

