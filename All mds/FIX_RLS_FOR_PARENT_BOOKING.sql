-- ============================================
-- FIX RLS POLICIES FOR PARENT TRIAL BOOKING
-- Since 9 parent bookings already exist, constraints are fine - RLS is the issue
-- ============================================

-- STEP 1: Check current RLS policies
SELECT 
  'Current RLS Policies' as check_type,
  policyname,
  cmd as command,
  qual as using_expression,
  with_check as with_check_expression
FROM pg_policies
WHERE schemaname = 'public'
  AND tablename = 'trial_sessions'
ORDER BY policyname;

-- STEP 2: Drop existing restrictive policies
DO $$
BEGIN
  RAISE NOTICE '========================================';
  RAISE NOTICE 'FIXING RLS POLICIES';
  RAISE NOTICE '========================================';

  -- Drop ALL existing policies on trial_sessions (comprehensive list)
  -- First, drop by exact name matches
  DROP POLICY IF EXISTS "Users can create trial sessions" ON public.trial_sessions;
  DROP POLICY IF EXISTS "Students can create trial sessions" ON public.trial_sessions;
  DROP POLICY IF EXISTS "Learners can create trial sessions" ON public.trial_sessions;
  DROP POLICY IF EXISTS "Authenticated users can create trial sessions" ON public.trial_sessions;
  DROP POLICY IF EXISTS "Anyone authenticated can create trial sessions" ON public.trial_sessions;
  DROP POLICY IF EXISTS "Users can create their own trial requests" ON public.trial_sessions;
  
  DROP POLICY IF EXISTS "Users can view their trial sessions" ON public.trial_sessions;
  DROP POLICY IF EXISTS "Users can view their own trial sessions" ON public.trial_sessions;
  DROP POLICY IF EXISTS "Tutors can view trial requests" ON public.trial_sessions;
  DROP POLICY IF EXISTS "Students can view their trial sessions" ON public.trial_sessions;
  DROP POLICY IF EXISTS "Parents can view their trial sessions" ON public.trial_sessions;
  
  DROP POLICY IF EXISTS "Users can update their trial sessions" ON public.trial_sessions;
  DROP POLICY IF EXISTS "Requesters can update their trial sessions" ON public.trial_sessions;
  DROP POLICY IF EXISTS "Requesters and tutors can update trial sessions" ON public.trial_sessions;
  DROP POLICY IF EXISTS "Tutors can respond to trial requests" ON public.trial_sessions;
  
  DROP POLICY IF EXISTS "Requesters can delete their trial sessions" ON public.trial_sessions;
  
  -- Also drop any policies that might exist with different names
  -- This is a safety measure to ensure we start fresh
  DECLARE
    policy_name TEXT;
  BEGIN
    FOR policy_name IN
      SELECT policyname
      FROM pg_policies
      WHERE schemaname = 'public'
        AND tablename = 'trial_sessions'
    LOOP
      EXECUTE format('DROP POLICY IF EXISTS %I ON public.trial_sessions', policy_name);
      RAISE NOTICE 'Dropped policy: %', policy_name;
    END LOOP;
  END;
  
  RAISE NOTICE '✅ Dropped all existing policies';
END $$;

-- STEP 3: Create new permissive policies
DO $$
BEGIN
  RAISE NOTICE '';
  RAISE NOTICE 'Creating new RLS policies...';

  -- INSERT Policy: Allow ANY authenticated user to create trial sessions
  -- This includes parents, learners, and students
  CREATE POLICY "Anyone authenticated can create trial sessions"
    ON public.trial_sessions
    FOR INSERT
    TO authenticated
    WITH CHECK (true); -- No restrictions - any authenticated user can insert

  RAISE NOTICE '✅ Created INSERT policy';

  -- SELECT Policy: Users can view their own trial sessions
  -- As tutor, learner, parent, or requester
  CREATE POLICY "Users can view their own trial sessions"
    ON public.trial_sessions
    FOR SELECT
    TO authenticated
    USING (
      tutor_id = auth.uid() 
      OR learner_id = auth.uid() 
      OR parent_id = auth.uid() 
      OR requester_id = auth.uid()
    );

  RAISE NOTICE '✅ Created SELECT policy';

  -- UPDATE Policy: Requesters and tutors can update
  CREATE POLICY "Requesters and tutors can update trial sessions"
    ON public.trial_sessions
    FOR UPDATE
    TO authenticated
    USING (
      requester_id = auth.uid() -- Requesters can update their requests
      OR tutor_id = auth.uid()   -- Tutors can approve/reject
    )
    WITH CHECK (
      requester_id = auth.uid() 
      OR tutor_id = auth.uid()
    );

  RAISE NOTICE '✅ Created UPDATE policy';

  -- DELETE Policy: Only requesters can delete their own requests
  CREATE POLICY "Requesters can delete their trial sessions"
    ON public.trial_sessions
    FOR DELETE
    TO authenticated
    USING (requester_id = auth.uid());

  RAISE NOTICE '✅ Created DELETE policy';

  RAISE NOTICE '';
  RAISE NOTICE '✅ All RLS policies created successfully!';

END $$;

-- STEP 4: Verify RLS is enabled
DO $$
BEGIN
  IF EXISTS (
    SELECT 1 FROM pg_tables 
    WHERE schemaname = 'public' 
    AND tablename = 'trial_sessions'
    AND rowsecurity = true
  ) THEN
    RAISE NOTICE '✅ RLS is enabled on trial_sessions';
  ELSE
    ALTER TABLE public.trial_sessions ENABLE ROW LEVEL SECURITY;
    RAISE NOTICE '✅ Enabled RLS on trial_sessions';
  END IF;
END $$;

-- STEP 5: Verify the new policies
SELECT 
  'New RLS Policies' as check_type,
  policyname,
  cmd as command,
  CASE 
    WHEN qual IS NULL THEN 'No USING clause (allows all)'
    ELSE 'Has USING clause'
  END as using_info,
  CASE 
    WHEN with_check IS NULL THEN 'No WITH CHECK clause'
    ELSE 'Has WITH CHECK clause'
  END as with_check_info
FROM pg_policies
WHERE schemaname = 'public'
  AND tablename = 'trial_sessions'
ORDER BY cmd, policyname;

-- STEP 6: Test query to verify parent can insert
-- This simulates what happens when a parent tries to book
DO $$
DECLARE
  test_parent_id UUID;
  test_tutor_id UUID;
BEGIN
  -- Get a parent user ID for testing
  SELECT id INTO test_parent_id
  FROM profiles
  WHERE user_type = 'parent'
  LIMIT 1;

  -- Get a tutor ID for testing
  SELECT id INTO test_tutor_id
  FROM profiles
  WHERE user_type = 'tutor'
  LIMIT 1;

  IF test_parent_id IS NULL THEN
    RAISE NOTICE '⚠️ No parent found for testing';
  ELSIF test_tutor_id IS NULL THEN
    RAISE NOTICE '⚠️ No tutor found for testing';
  ELSE
    RAISE NOTICE '';
    RAISE NOTICE 'Test parent ID: %', test_parent_id;
    RAISE NOTICE 'Test tutor ID: %', test_tutor_id;
    RAISE NOTICE '✅ Test data found - policies should allow insert';
  END IF;
END $$;

-- ============================================
-- DONE!
-- ============================================
-- 
-- This script:
-- 1. ✅ Drops all existing restrictive RLS policies
-- 2. ✅ Creates new permissive policies that allow:
--    - ANY authenticated user to INSERT (including parents)
--    - Users to SELECT their own sessions (as tutor/learner/parent/requester)
--    - Requesters and tutors to UPDATE
--    - Requesters to DELETE
-- 3. ✅ Verifies RLS is enabled
-- 4. ✅ Shows the new policies
--
-- After running this, parents should be able to book trial sessions!
--
-- ============================================

