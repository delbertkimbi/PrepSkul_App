-- ============================================
-- FIX PARENTS INCORRECTLY CHANGED TO LEARNER
-- This script finds and fixes parents whose user_type was incorrectly changed
-- ============================================

-- STEP 1: Find parents who were incorrectly changed to 'learner'
-- These are users who have parent_id set in trial_sessions but user_type = 'learner'
SELECT 
  'Parents Changed to Learner' as check_type,
  p.id,
  p.email,
  p.full_name,
  p.user_type,
  COUNT(ts.id) as trial_sessions_as_parent,
  'This user has trial sessions as parent but user_type is learner' as issue
FROM profiles p
JOIN trial_sessions ts ON ts.parent_id = p.id
WHERE p.user_type = 'learner'
GROUP BY p.id, p.email, p.full_name, p.user_type
ORDER BY trial_sessions_as_parent DESC;

-- STEP 2: Find users who have parent_id in trial_sessions but user_type is not 'parent'
SELECT 
  'Users with Parent Role in Sessions' as check_type,
  p.id,
  p.email,
  p.full_name,
  p.user_type as current_user_type,
  COUNT(DISTINCT ts.id) as sessions_as_parent,
  'Should be user_type = parent' as recommendation
FROM profiles p
JOIN trial_sessions ts ON ts.parent_id = p.id
WHERE p.user_type != 'parent'
GROUP BY p.id, p.email, p.full_name, p.user_type
ORDER BY sessions_as_parent DESC;

-- STEP 3: Find users who have requester_id in trial_sessions with parent_id set
-- These are likely parents who made the booking
SELECT 
  'Likely Parents (Requesters with Parent ID)' as check_type,
  p.id,
  p.email,
  p.full_name,
  p.user_type,
  COUNT(DISTINCT ts.id) as bookings_made,
  CASE 
    WHEN p.user_type != 'parent' THEN 'Should be user_type = parent'
    ELSE '✅ Correct user_type'
  END as status
FROM profiles p
JOIN trial_sessions ts ON ts.requester_id = p.id
WHERE ts.parent_id IS NOT NULL
  AND ts.parent_id = p.id  -- Requester is also the parent
GROUP BY p.id, p.email, p.full_name, p.user_type
ORDER BY bookings_made DESC;

-- STEP 4: Fix parents who were incorrectly changed to 'learner'
-- Only fix users who have trial_sessions as parent_id
UPDATE profiles p
SET 
  user_type = 'parent',
  updated_at = NOW()
WHERE p.user_type = 'learner'
  AND EXISTS (
    SELECT 1 FROM trial_sessions ts
    WHERE ts.parent_id = p.id
  )
  AND NOT EXISTS (
    -- Don't change if they also have sessions as learner_id (they might be both)
    SELECT 1 FROM trial_sessions ts2
    WHERE ts2.learner_id = p.id
    AND ts2.parent_id != p.id  -- Exclude cases where parent_id = learner_id (same person)
  );

-- STEP 5: Fix users who are requesters with parent_id set in their trial sessions
-- These are definitely parents
UPDATE profiles p
SET 
  user_type = 'parent',
  updated_at = NOW()
WHERE p.user_type != 'parent'
  AND EXISTS (
    SELECT 1 FROM trial_sessions ts
    WHERE ts.requester_id = p.id
      AND ts.parent_id = p.id  -- They are both requester and parent
  );

-- STEP 6: Verify the fixes
SELECT 
  'Verification After Fix' as check_type,
  p.user_type,
  COUNT(DISTINCT p.id) as user_count,
  COUNT(ts.id) as trial_sessions_count
FROM profiles p
LEFT JOIN trial_sessions ts ON ts.parent_id = p.id OR ts.requester_id = p.id
WHERE p.user_type = 'parent'
GROUP BY p.user_type;

-- STEP 7: Show any remaining issues
SELECT 
  'Remaining Issues' as check_type,
  p.id,
  p.email,
  p.user_type,
  COUNT(ts.id) as parent_sessions,
  'Still has wrong user_type' as issue
FROM profiles p
JOIN trial_sessions ts ON ts.parent_id = p.id
WHERE p.user_type != 'parent'
GROUP BY p.id, p.email, p.user_type;

-- ============================================
-- DONE!
-- ============================================
-- 
-- This script:
-- 1. ✅ Finds parents incorrectly changed to 'learner'
-- 2. ✅ Finds users with parent role in sessions but wrong user_type
-- 3. ✅ Finds requesters who are also parents
-- 4. ✅ Fixes parents who were incorrectly changed
-- 5. ✅ Verifies the fixes
-- 6. ✅ Shows any remaining issues
--
-- After running this, parents should have user_type = 'parent'
-- and be able to book trial sessions!
--
-- ============================================

