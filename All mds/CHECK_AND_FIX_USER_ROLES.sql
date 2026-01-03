-- ============================================
-- CHECK AND FIX USER ROLE SWITCHING ISSUE
-- Run this to diagnose and fix role confusion
-- ============================================

-- STEP 1: Check all users with their current user_type
SELECT 
  'Current User Types' as check_type,
  id,
  email,
  full_name,
  user_type,
  phone_number,
  created_at,
  updated_at
FROM profiles
ORDER BY updated_at DESC
LIMIT 50;

-- STEP 2: Find users with inconsistent or missing user_type
SELECT 
  'Users with Issues' as check_type,
  id,
  email,
  full_name,
  user_type,
  CASE 
    WHEN user_type IS NULL THEN '❌ user_type is NULL'
    WHEN user_type = '' THEN '❌ user_type is empty'
    WHEN user_type NOT IN ('learner', 'student', 'tutor', 'parent', 'admin') THEN '❌ Invalid user_type: ' || user_type
    WHEN user_type = 'student' THEN '⚠️ Using deprecated "student" (should be "learner")'
    ELSE '✅ Valid user_type'
  END as issue,
  updated_at
FROM profiles
WHERE user_type IS NULL 
   OR user_type = ''
   OR user_type NOT IN ('learner', 'student', 'tutor', 'parent', 'admin')
   OR user_type = 'student'
ORDER BY updated_at DESC;

-- STEP 3: Check for duplicate emails with different user_types
SELECT 
  'Duplicate Emails' as check_type,
  email,
  COUNT(*) as count,
  STRING_AGG(DISTINCT user_type::text, ', ') as user_types,
  STRING_AGG(id::text, ', ') as profile_ids
FROM profiles
WHERE email IS NOT NULL AND email != ''
GROUP BY email
HAVING COUNT(*) > 1;

-- STEP 4: Fix invalid user_types
-- Map 'student' to 'learner' (deprecated value)
UPDATE profiles
SET 
  user_type = 'learner',
  updated_at = NOW()
WHERE user_type = 'student';

-- STEP 5: Fix NULL or empty user_types (set to 'learner' as default)
-- BUT: Don't change users who are already acting as parents in trial_sessions
-- These should be set to 'parent' instead
UPDATE profiles
SET 
  user_type = 'parent',
  updated_at = NOW()
WHERE (user_type IS NULL OR user_type = '')
  AND EXISTS (
    SELECT 1 FROM trial_sessions ts
    WHERE ts.parent_id = profiles.id
      OR (ts.requester_id = profiles.id AND ts.parent_id = profiles.id)
  );

-- For other users with NULL/empty user_type, set to 'learner'
UPDATE profiles
SET 
  user_type = 'learner',
  updated_at = NOW()
WHERE (user_type IS NULL OR user_type = '')
  AND NOT EXISTS (
    SELECT 1 FROM trial_sessions ts
    WHERE ts.parent_id = profiles.id
      OR (ts.requester_id = profiles.id AND ts.parent_id = profiles.id)
  );

-- STEP 6: Verify the fixes
SELECT 
  'Verification' as check_type,
  user_type,
  COUNT(*) as count
FROM profiles
GROUP BY user_type
ORDER BY user_type;

-- ============================================
-- DONE!
-- ============================================
-- 
-- If you see role switching, check:
-- 1. Are there duplicate profiles with same email?
-- 2. Is user_type being changed somewhere in the code?
-- 3. Is the navigation reading from the correct source?
--
-- ============================================

