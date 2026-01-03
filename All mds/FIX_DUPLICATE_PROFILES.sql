-- ============================================
-- FIX DUPLICATE PROFILES ISSUE
-- This script finds and fixes duplicate profiles that cause "multiple rows" errors
-- ============================================

-- STEP 1: Find duplicate profiles (same ID or same email)
SELECT 
  'Duplicate Profiles by ID' as check_type,
  id,
  COUNT(*) as count,
  STRING_AGG(user_type::text, ', ') as user_types,
  STRING_AGG(email::text, ', ') as emails
FROM profiles
GROUP BY id
HAVING COUNT(*) > 1
ORDER BY count DESC;

-- STEP 2: Find duplicate profiles by email
SELECT 
  'Duplicate Profiles by Email' as check_type,
  email,
  COUNT(*) as count,
  STRING_AGG(id::text, ', ') as profile_ids,
  STRING_AGG(user_type::text, ', ') as user_types
FROM profiles
WHERE email IS NOT NULL AND email != ''
GROUP BY email
HAVING COUNT(*) > 1
ORDER BY count DESC;

-- STEP 3: Check for profiles with same ID but different user_types (role switching issue)
SELECT 
  'Role Switching Profiles' as check_type,
  id,
  email,
  COUNT(*) as count,
  STRING_AGG(DISTINCT user_type::text, ', ') as user_types,
  STRING_AGG(DISTINCT full_name::text, ', ') as names
FROM profiles
GROUP BY id, email
HAVING COUNT(DISTINCT user_type) > 1
ORDER BY count DESC;

-- STEP 4: Fix duplicate profiles by keeping the most recent one
-- This will delete duplicate rows, keeping only the latest updated_at record
DO $$
DECLARE
  duplicate_id UUID;
  duplicate_count INT;
BEGIN
  RAISE NOTICE '========================================';
  RAISE NOTICE 'FIXING DUPLICATE PROFILES';
  RAISE NOTICE '========================================';

  -- Find and fix duplicates by ID (should never happen, but if it does...)
  FOR duplicate_id, duplicate_count IN
    SELECT id, COUNT(*)
    FROM profiles
    GROUP BY id
    HAVING COUNT(*) > 1
  LOOP
    RAISE NOTICE 'Found % duplicate profiles with ID: %', duplicate_count, duplicate_id;
    
    -- Keep the most recent profile (highest updated_at or created_at)
    DELETE FROM profiles
    WHERE id = duplicate_id
      AND (updated_at, created_at) NOT IN (
        SELECT updated_at, created_at
        FROM profiles
        WHERE id = duplicate_id
        ORDER BY updated_at DESC NULLS LAST, created_at DESC NULLS LAST
        LIMIT 1
      );
    
    RAISE NOTICE '✅ Removed duplicate profiles for ID: %', duplicate_id;
  END LOOP;

  -- If no duplicates found
  IF NOT FOUND THEN
    RAISE NOTICE '✅ No duplicate profiles by ID found';
  END IF;

END $$;

-- STEP 5: Verify the fix
SELECT 
  'Verification' as check_type,
  'Total profiles' as metric,
  COUNT(*) as count
FROM profiles;

SELECT 
  'Verification' as check_type,
  'Unique profile IDs' as metric,
  COUNT(DISTINCT id) as count
FROM profiles;

-- If these counts don't match, there are still duplicates
SELECT 
  CASE 
    WHEN (SELECT COUNT(*) FROM profiles) = (SELECT COUNT(DISTINCT id) FROM profiles)
    THEN '✅ No duplicate profiles found'
    ELSE '❌ Still have duplicate profiles - manual cleanup needed'
  END as status;

-- ============================================
-- DONE!
-- ============================================
-- 
-- After running this script:
-- 1. Check the output to see if duplicates were found and fixed
-- 2. If duplicates still exist, you may need to manually merge them
-- 3. The "multiple rows" error should be resolved
--
-- ============================================

