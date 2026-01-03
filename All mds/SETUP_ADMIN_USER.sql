-- ============================================
-- SETUP ADMIN USER: prepskul@gmail.com
-- Password: DE12$kimb
-- ============================================
-- Run this entire script in Supabase SQL Editor
-- ============================================

-- Step 1: Ensure is_admin column exists
ALTER TABLE profiles 
ADD COLUMN IF NOT EXISTS is_admin BOOLEAN DEFAULT FALSE;

-- Step 2: Update user_type constraint to allow 'admin' (if needed)
DO $$
BEGIN
  -- Drop existing constraint if it exists
  IF EXISTS (
    SELECT 1 FROM pg_constraint 
    WHERE conname = 'profiles_user_type_check'
  ) THEN
    ALTER TABLE profiles DROP CONSTRAINT profiles_user_type_check;
  END IF;
  
  -- Add new constraint that includes 'admin'
  ALTER TABLE profiles 
  ADD CONSTRAINT profiles_user_type_check 
  CHECK (user_type IN ('learner', 'tutor', 'parent', 'admin'));
EXCEPTION
  WHEN duplicate_object THEN NULL;
END $$;

-- Step 3: Check if user exists in auth.users
DO $$
DECLARE
  user_exists BOOLEAN;
  user_id UUID;
BEGIN
  -- Check if user exists
  SELECT EXISTS(SELECT 1 FROM auth.users WHERE email = 'prepskul@gmail.com') INTO user_exists;
  
  IF user_exists THEN
    -- Get the user ID
    SELECT id INTO user_id FROM auth.users WHERE email = 'prepskul@gmail.com';
    
    RAISE NOTICE 'User exists in auth.users with ID: %', user_id;
    
    -- Create or update profile with admin permissions
    INSERT INTO profiles (id, email, full_name, is_admin, user_type, created_at, updated_at)
    VALUES (
      user_id,
      'prepskul@gmail.com',
      'PrepSkul Admin',
      TRUE,
      'admin',
      NOW(),
      NOW()
    )
    ON CONFLICT (id) DO UPDATE 
    SET 
      is_admin = TRUE,
      user_type = 'admin',
      full_name = 'PrepSkul Admin',
      email = 'prepskul@gmail.com',
      updated_at = NOW();
    
    RAISE NOTICE 'Profile created/updated with admin permissions';
  ELSE
    RAISE NOTICE 'User does NOT exist in auth.users. You need to create it first!';
    RAISE NOTICE 'Go to: Supabase Dashboard → Authentication → Users → Add User';
    RAISE NOTICE 'Email: prepskul@gmail.com';
    RAISE NOTICE 'Password: DE12$kimb';
    RAISE NOTICE 'IMPORTANT: Check "Auto Confirm User"';
  END IF;
END $$;

-- Step 4: Verify admin setup
SELECT 
  p.id,
  p.email,
  p.full_name,
  p.is_admin,
  p.user_type,
  CASE 
    WHEN u.id IS NOT NULL THEN 'User exists in auth.users ✅'
    ELSE 'User NOT in auth.users ❌'
  END as auth_status
FROM profiles p
LEFT JOIN auth.users u ON p.id = u.id
WHERE p.email = 'prepskul@gmail.com';

-- Step 5: Ensure RLS policies allow admin access
-- Allow users to read their own profile (needed for admin check)
DROP POLICY IF EXISTS "Users can read own profile" ON profiles;

CREATE POLICY "Users can read own profile"
ON profiles
FOR SELECT
USING (auth.uid() = id);

-- Allow admins to read all profiles (for admin dashboard)
DROP POLICY IF EXISTS "Admins can read all profiles" ON profiles;

CREATE POLICY "Admins can read all profiles"
ON profiles
FOR SELECT
USING (
  EXISTS (
    SELECT 1 FROM profiles p2 
    WHERE p2.id = auth.uid() 
    AND p2.is_admin = TRUE
  )
);

-- ============================================
-- IMPORTANT: SET PASSWORD IN SUPABASE DASHBOARD
-- ============================================
-- 
-- Since passwords are encrypted, you MUST set the password via Supabase Dashboard:
--
-- 1. Go to: https://app.supabase.com
-- 2. Select your PrepSkul project
-- 3. Navigate to: Authentication → Users
-- 4. Find or create user with email: prepskul@gmail.com
-- 5. If user doesn't exist:
--    - Click "Add User" (green button)
--    - Email: prepskul@gmail.com
--    - Password: DE12$kimb
--    - ✅ Check "Auto Confirm User"
--    - Click "Create User"
-- 6. If user exists:
--    - Click on the user row
--    - Click "Reset Password" or "Update User"
--    - Set password to: DE12$kimb
--    - Save changes
--
-- ============================================
-- VERIFICATION CHECKLIST:
-- ============================================
-- ✅ User exists in auth.users (check Step 4 output)
-- ✅ Profile exists with is_admin = TRUE (check Step 4 output)
-- ✅ Password set in Supabase Dashboard
-- ✅ User is auto-confirmed
--
-- Then try logging in at: http://localhost:3000/admin/login
-- Email: prepskul@gmail.com
-- Password: DE12$kimb
-- ============================================

