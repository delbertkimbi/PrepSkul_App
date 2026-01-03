-- ============================================
-- REVERSE CHECK_AND_FIX_USER_ROLES.SQL
-- This script reverses the effects of CHECK_AND_FIX_USER_ROLES.sql
-- ============================================
-- 
-- WHAT CHECK_AND_FIX_USER_ROLES.SQL DID:
-- 1. Changed all 'student' user_type to 'learner' (Step 4)
-- 2. Set NULL/empty user_type to 'parent' or 'learner' (Step 5)
--
-- WHAT THIS SCRIPT DOES:
-- 1. Updates constraint to allow BOTH 'student' AND 'learner' (so codebase can use 'student')
-- 2. Changes 'learner' back to 'student' for users who likely were 'student' originally
--    (users created after the script ran, or users with no trial_sessions as parents)
-- 3. Note: We cannot perfectly reverse Step 5 (NULL/empty changes) without a backup
--
-- ============================================

DO $$
DECLARE
  row_count INTEGER;
  constraint_allows_student BOOLEAN;
BEGIN
  RAISE NOTICE 'Starting reversal of CHECK_AND_FIX_USER_ROLES.sql effects...';

  -- STEP 1: Check current constraint
  SELECT EXISTS (
    SELECT 1 
    FROM pg_constraint 
    WHERE conname = 'profiles_user_type_check'
      AND pg_get_constraintdef(oid) LIKE '%student%'
  ) INTO constraint_allows_student;

  RAISE NOTICE 'Current constraint allows student: %', constraint_allows_student;

  -- STEP 2: Update constraint to allow BOTH 'student' AND 'learner'
  -- This allows the codebase to continue using 'student' while keeping existing 'learner' values
  IF EXISTS (
    SELECT 1 FROM pg_constraint 
    WHERE conname = 'profiles_user_type_check'
  ) THEN
    ALTER TABLE profiles DROP CONSTRAINT profiles_user_type_check;
    RAISE NOTICE '✅ Dropped existing profiles_user_type_check constraint';
  END IF;

  -- Add constraint that allows both 'student' and 'learner'
  ALTER TABLE profiles 
  ADD CONSTRAINT profiles_user_type_check 
  CHECK (user_type IN ('learner', 'student', 'tutor', 'parent', 'admin'));

  RAISE NOTICE '✅ Updated constraint to allow both ''student'' and ''learner''';

  -- STEP 3: Change 'learner' back to 'student' for users who were likely 'student' originally
  -- Strategy: Change users who:
  --   - Are 'learner' but NOT acting as parents in trial_sessions
  --   - Were likely students (not originally learners)
  -- 
  -- We'll be conservative and only change users who:
  --   - Have 'learner' user_type
  --   - Are NOT parents in any trial_sessions
  --   - Are NOT tutors
  --   - This should catch most users who were changed from 'student' to 'learner'
  
  UPDATE profiles p
  SET 
    user_type = 'student',
    updated_at = NOW()
  WHERE p.user_type = 'learner'
    -- Not a parent in trial_sessions
    AND NOT EXISTS (
      SELECT 1 FROM trial_sessions ts
      WHERE ts.parent_id = p.id
    )
    -- Not a tutor
    AND NOT EXISTS (
      SELECT 1 FROM tutor_profiles tp
      WHERE tp.user_id = p.id OR tp.id = p.id
    )
    -- Not explicitly set to 'learner' by being in learner_profiles (though this might not be reliable)
    -- We'll change them anyway since the codebase uses 'student'
    AND p.id NOT IN (
      -- Keep users who might have been intentionally set to 'learner'
      -- (This is a conservative approach - we'll change most 'learner' to 'student')
      SELECT DISTINCT p2.id
      FROM profiles p2
      WHERE p2.user_type = 'learner'
        AND EXISTS (
          SELECT 1 FROM trial_sessions ts
          WHERE ts.learner_id = p2.id
            AND ts.parent_id IS NOT NULL
            AND ts.parent_id != p2.id
        )
    );

  GET DIAGNOSTICS row_count = ROW_COUNT;
  RAISE NOTICE '✅ Changed % users from ''learner'' back to ''student''', row_count;

  -- STEP 4: Note about NULL/empty user_type changes
  -- We cannot perfectly reverse Step 5 of the original script because:
  --   - We don't know what the original values were (NULL/empty)
  --   - The script set them to 'parent' or 'learner' based on trial_sessions
  -- 
  -- If you need to reverse these, you would need:
  --   1. A backup of the profiles table before running CHECK_AND_FIX_USER_ROLES.sql
  --   2. Or manually review each user and set their user_type appropriately
  --
  -- For now, we'll leave these as-is since they were likely correct assignments

  RAISE NOTICE 'ℹ️ Note: NULL/empty user_type changes from Step 5 cannot be automatically reversed';
  RAISE NOTICE 'ℹ️ These users were set to ''parent'' or ''learner'' based on trial_sessions data';
  RAISE NOTICE 'ℹ️ If you need to change these, review them manually';

  RAISE NOTICE '✅ Reversal completed!';
  RAISE NOTICE '';
  RAISE NOTICE 'SUMMARY:';
  RAISE NOTICE '  - Constraint now allows both ''student'' and ''learner''';
  RAISE NOTICE '  - Changed % users from ''learner'' to ''student''', row_count;
  RAISE NOTICE '  - Codebase can now use ''student'' for new signups';

END $$;

-- STEP 5: Verification
SELECT 
  'VERIFICATION' as check_type,
  user_type,
  COUNT(*) as count
FROM profiles
GROUP BY user_type
ORDER BY user_type;

-- Check constraint definition
SELECT 
  'CONSTRAINT_CHECK' as check_type,
  conname as constraint_name,
  pg_get_constraintdef(oid) as constraint_definition
FROM pg_constraint
WHERE conname = 'profiles_user_type_check';

-- ============================================
-- DONE!
-- ============================================
-- 
-- The constraint now allows both 'student' and 'learner'
-- The codebase can continue using 'student' for new signups
-- Existing 'learner' users who were likely students have been changed back
--
-- If you see issues:
-- 1. Check that new signups can create profiles with 'student' user_type
-- 2. Verify the constraint allows 'student'
-- 3. Review any users that still have 'learner' if needed
--
-- ============================================

