-- ============================================
-- QUICK FIX FOR DUPLICATE PROFILES
-- This removes duplicate profiles that cause "multiple rows" errors
-- ============================================

-- STEP 1: Find duplicate profiles by ID (should never happen, but if it does...)
SELECT 
  'Duplicate Profiles by ID' as check_type,
  id,
  COUNT(*) as count,
  STRING_AGG(DISTINCT user_type::text, ', ') as user_types,
  STRING_AGG(DISTINCT email::text, ', ') as emails
FROM profiles
GROUP BY id
HAVING COUNT(*) > 1
ORDER BY count DESC;

-- STEP 2: Remove duplicate profiles, keeping the most recent one
DO $$
DECLARE
  duplicate_id UUID;
  duplicate_count INT;
  kept_count INT := 0;
BEGIN
  RAISE NOTICE '========================================';
  RAISE NOTICE 'REMOVING DUPLICATE PROFILES';
  RAISE NOTICE '========================================';

  -- Find and fix duplicates by ID
  FOR duplicate_id, duplicate_count IN
    SELECT id, COUNT(*)
    FROM profiles
    GROUP BY id
    HAVING COUNT(*) > 1
  LOOP
    RAISE NOTICE 'Found % duplicate profiles with ID: %', duplicate_count, duplicate_id;
    
    -- Keep the most recent profile (highest updated_at, then created_at)
    -- Delete all others
    WITH ranked_profiles AS (
      SELECT ctid, -- Physical row identifier
        ROW_NUMBER() OVER (
          ORDER BY 
            updated_at DESC NULLS LAST,
            created_at DESC NULLS LAST
        ) as rn
      FROM profiles
      WHERE id = duplicate_id
    )
    DELETE FROM profiles
    WHERE ctid IN (
      SELECT ctid FROM ranked_profiles WHERE rn > 1
    );
    
    kept_count := kept_count + 1;
    RAISE NOTICE '✅ Removed duplicates for ID: % (kept most recent)', duplicate_id;
  END LOOP;

  IF kept_count = 0 THEN
    RAISE NOTICE '✅ No duplicate profiles by ID found';
  ELSE
    RAISE NOTICE '';
    RAISE NOTICE '✅ Removed duplicates for % profile IDs', kept_count;
  END IF;

END $$;

-- STEP 3: Verify no duplicates remain
SELECT 
  'Verification' as check_type,
  CASE 
    WHEN (SELECT COUNT(*) FROM profiles) = (SELECT COUNT(DISTINCT id) FROM profiles)
    THEN '✅ No duplicate profiles by ID'
    ELSE '❌ Still have duplicate profiles - manual cleanup needed'
  END as status,
  (SELECT COUNT(*) FROM profiles) as total_profiles,
  (SELECT COUNT(DISTINCT id) FROM profiles) as unique_profile_ids;

-- ============================================
-- DONE!
-- ============================================
-- 
-- This script removes duplicate profiles that cause "multiple rows" errors.
-- After running this, try booking again as a parent.
--
-- ============================================

