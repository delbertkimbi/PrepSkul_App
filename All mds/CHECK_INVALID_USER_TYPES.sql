-- ============================================
-- CHECK FOR INVALID user_type VALUES
-- Run this first to see what's wrong
-- ============================================

-- Check 1: See all unique user_type values in the table
SELECT 
  user_type,
  COUNT(*) as count,
  CASE 
    WHEN user_type IN ('learner', 'tutor', 'parent', 'admin') THEN '✅ Valid'
    WHEN user_type IS NULL THEN '❌ NULL (Invalid)'
    WHEN user_type = '' THEN '❌ Empty (Invalid)'
    ELSE '❌ Invalid value'
  END as status
FROM profiles
GROUP BY user_type
ORDER BY count DESC;

-- Check 2: Show rows with invalid user_type values
SELECT 
  id,
  email,
  full_name,
  user_type,
  CASE 
    WHEN user_type IS NULL THEN 'NULL'
    WHEN user_type = '' THEN 'Empty string'
    WHEN user_type NOT IN ('learner', 'tutor', 'parent', 'admin') THEN 'Invalid: ' || user_type
    ELSE 'Valid'
  END as issue
FROM profiles
WHERE user_type IS NULL 
   OR user_type = '' 
   OR user_type NOT IN ('learner', 'tutor', 'parent', 'admin')
ORDER BY user_type;

-- Check 3: Current constraint (if exists)
SELECT 
  conname as constraint_name,
  pg_get_constraintdef(oid) as constraint_definition
FROM pg_constraint
WHERE conname = 'profiles_user_type_check';

-- ============================================
-- After running this, you'll see:
-- 1. What user_type values exist
-- 2. Which ones are invalid
-- 3. How many rows have invalid values
--
-- Then run: All mds/FIX_ADMIN_PERMISSIONS_NOW.sql
-- ============================================

