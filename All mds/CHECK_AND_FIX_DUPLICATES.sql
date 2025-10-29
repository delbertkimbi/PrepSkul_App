-- ============================================
-- Check for duplicate profiles
-- ============================================

-- 1. See all profiles with this email
SELECT id, email, is_admin, user_type, created_at 
FROM profiles 
WHERE email = 'prepskul@gmail.com'
ORDER BY created_at;

-- 2. Count them
SELECT COUNT(*) as profile_count 
FROM profiles 
WHERE email = 'prepskul@gmail.com';

-- ============================================
-- If there are duplicates, run this to keep only the first one:
-- ============================================

-- Delete duplicate profiles, keeping only the oldest one
DELETE FROM profiles 
WHERE email = 'prepskul@gmail.com'
AND id NOT IN (
  SELECT id 
  FROM profiles 
  WHERE email = 'prepskul@gmail.com'
  ORDER BY created_at ASC 
  LIMIT 1
);

-- 3. Make sure the remaining profile is admin
UPDATE profiles 
SET is_admin = TRUE, user_type = 'admin'
WHERE email = 'prepskul@gmail.com';

-- 4. Verify only one profile exists now
SELECT id, email, is_admin, user_type, created_at 
FROM profiles 
WHERE email = 'prepskul@gmail.com';

-- ============================================
-- DONE! Now try logging in
-- ============================================

