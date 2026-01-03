-- ============================================
-- FIX EMAIL AND ROLE ISSUES
-- Run this AFTER running DIAGNOSE_EMAIL_AND_ROLE_ISSUES.sql
-- ============================================

DO $$
DECLARE
  duplicate_email TEXT;
  user_ids_array UUID[];
  correct_email TEXT;
  user_id_to_keep UUID;
  user_id_to_fix UUID;
  row_count INTEGER;
BEGIN
  RAISE NOTICE 'Starting email and role fixes...';

  -- STEP 1: Fix duplicate emails - keep the oldest profile, update others with auth.users email
  FOR duplicate_email, user_ids_array IN
    SELECT email, ARRAY_AGG(id ORDER BY created_at ASC)
    FROM profiles
    WHERE email IS NOT NULL AND email != ''
    GROUP BY email
    HAVING COUNT(*) > 1
  LOOP
    RAISE NOTICE 'Found duplicate email: % with % users', duplicate_email, array_length(user_ids_array, 1);
    
    -- Keep the first (oldest) user
    user_id_to_keep := user_ids_array[1];
    RAISE NOTICE 'Keeping user ID: % (oldest)', user_id_to_keep;
    
    -- Fix all other users
    FOR i IN 2..array_length(user_ids_array, 1) LOOP
      user_id_to_fix := user_ids_array[i];
      
      -- Get the correct email from auth.users
      SELECT email INTO correct_email
      FROM auth.users
      WHERE id = user_id_to_fix;
      
      IF correct_email IS NOT NULL AND correct_email != '' AND correct_email != duplicate_email THEN
        -- Update profile with correct email from auth.users
        UPDATE profiles
        SET email = correct_email, updated_at = NOW()
        WHERE id = user_id_to_fix;
        RAISE NOTICE '✅ Fixed user ID: % - set email to: %', user_id_to_fix, correct_email;
      ELSE
        -- If auth.users also has wrong email, generate a unique one
        correct_email := 'user_' || user_id_to_fix::TEXT || '@prepskul.fixed';
        UPDATE profiles
        SET email = correct_email, updated_at = NOW()
        WHERE id = user_id_to_fix;
        RAISE NOTICE '⚠️ Fixed user ID: % - generated unique email: %', user_id_to_fix, correct_email;
      END IF;
    END LOOP;
  END LOOP;

  -- STEP 2: Fix users with brianleke9@gmail.com (if it's not their actual email)
  FOR user_id_to_fix IN
    SELECT p.id
    FROM profiles p
    LEFT JOIN auth.users u ON u.id = p.id
    WHERE p.email = 'brianleke9@gmail.com'
      AND (u.email IS NULL OR u.email != 'brianleke9@gmail.com')
  LOOP
    -- Get correct email from auth.users
    SELECT email INTO correct_email
    FROM auth.users
    WHERE id = user_id_to_fix;
    
    IF correct_email IS NOT NULL AND correct_email != '' AND correct_email != 'brianleke9@gmail.com' THEN
      UPDATE profiles
      SET email = correct_email, updated_at = NOW()
      WHERE id = user_id_to_fix;
      RAISE NOTICE '✅ Fixed brianleke9@gmail.com for user ID: % - set to: %', user_id_to_fix, correct_email;
    ELSE
      -- Generate unique email
      correct_email := 'user_' || user_id_to_fix::TEXT || '@prepskul.fixed';
      UPDATE profiles
      SET email = correct_email, updated_at = NOW()
      WHERE id = user_id_to_fix;
      RAISE NOTICE '⚠️ Fixed brianleke9@gmail.com for user ID: % - generated: %', user_id_to_fix, correct_email;
    END IF;
  END LOOP;

  -- STEP 3: Fix NULL/empty emails by syncing from auth.users
  UPDATE profiles p
  SET email = COALESCE(u.email, 'user_' || p.id::TEXT || '@prepskul.fixed'), updated_at = NOW()
  FROM auth.users u
  WHERE p.id = u.id
    AND (p.email IS NULL OR p.email = '')
    AND u.email IS NOT NULL AND u.email != '';
  
  GET DIAGNOSTICS row_count = ROW_COUNT;
  RAISE NOTICE '✅ Fixed % profiles with NULL/empty emails', row_count;

  -- STEP 4: Fix incorrect user_type (parents marked as learners)
  UPDATE profiles p
  SET 
    user_type = 'parent',
    updated_at = NOW()
  WHERE p.user_type = 'learner'
    AND EXISTS (
      SELECT 1 FROM trial_sessions ts
      WHERE ts.parent_id = p.id
         OR (ts.requester_id = p.id AND ts.parent_id = p.id)
    );
  
  GET DIAGNOSTICS row_count = ROW_COUNT;
  RAISE NOTICE '✅ Fixed % parents incorrectly marked as learners', row_count;

  -- STEP 5: Ensure learner_id is not a parent
  -- If a parent is set as learner_id, we should keep it but ensure parent_id is also set
  -- This is a data integrity check, not a fix (as the relationship might be intentional)
  RAISE NOTICE 'ℹ️ Checking for parents set as learner_id...';
  
  FOR user_id_to_fix IN
    SELECT DISTINCT ts.learner_id
    FROM trial_sessions ts
    JOIN profiles p ON p.id = ts.learner_id
    WHERE p.user_type = 'parent'
      AND ts.parent_id IS NULL
  LOOP
    -- Set parent_id to learner_id if it's a parent
    UPDATE trial_sessions
    SET parent_id = learner_id, updated_at = NOW()
    WHERE learner_id = user_id_to_fix
      AND parent_id IS NULL;
    RAISE NOTICE '⚠️ Fixed trial_sessions: set parent_id = learner_id for parent user: %', user_id_to_fix;
  END LOOP;

  RAISE NOTICE '✅ Email and role fixes completed!';
END $$;

-- STEP 6: Verify fixes
SELECT 
  'VERIFICATION' as check_type,
  (SELECT COUNT(*) FROM profiles WHERE email = 'brianleke9@gmail.com') as remaining_brianleke,
  (SELECT COUNT(*) FROM profiles WHERE email IS NULL OR email = '') as remaining_missing_emails,
  (SELECT COUNT(*) FROM profiles p WHERE p.user_type = 'learner' AND EXISTS (SELECT 1 FROM trial_sessions WHERE parent_id = p.id)) as remaining_incorrect_roles,
  (SELECT COUNT(*) FROM profiles WHERE email LIKE '%@prepskul.fixed') as generated_emails;

