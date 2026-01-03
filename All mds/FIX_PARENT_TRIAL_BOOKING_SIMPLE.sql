-- ============================================
-- SIMPLE FIX FOR PARENT TRIAL BOOKING
-- This script directly fixes the most common issues preventing parents from booking
-- ============================================

-- STEP 1: Check and fix RLS policies on trial_sessions
-- Parents need to be able to INSERT into trial_sessions

DO $$
BEGIN
  RAISE NOTICE '========================================';
  RAISE NOTICE 'FIXING RLS POLICIES FOR PARENT BOOKING';
  RAISE NOTICE '========================================';

  -- Enable RLS if not already enabled
  ALTER TABLE public.trial_sessions ENABLE ROW LEVEL SECURITY;

  -- Drop existing INSERT policy if it exists (might be too restrictive)
  DROP POLICY IF EXISTS "Users can create trial sessions" ON public.trial_sessions;
  DROP POLICY IF EXISTS "Students can create trial sessions" ON public.trial_sessions;
  DROP POLICY IF EXISTS "Learners can create trial sessions" ON public.trial_sessions;
  DROP POLICY IF EXISTS "Anyone can create trial sessions" ON public.trial_sessions;

  -- Create a new INSERT policy that allows ANY authenticated user (including parents)
  CREATE POLICY "Authenticated users can create trial sessions"
    ON public.trial_sessions
    FOR INSERT
    TO authenticated
    WITH CHECK (true); -- Allow any authenticated user to insert

  RAISE NOTICE '✅ Created INSERT policy allowing all authenticated users';

  -- Ensure SELECT policy allows users to see their own trial sessions
  DROP POLICY IF EXISTS "Users can view their trial sessions" ON public.trial_sessions;
  
  CREATE POLICY "Users can view their trial sessions"
    ON public.trial_sessions
    FOR SELECT
    TO authenticated
    USING (
      tutor_id = auth.uid() 
      OR learner_id = auth.uid() 
      OR parent_id = auth.uid() 
      OR requester_id = auth.uid()
    );

  RAISE NOTICE '✅ Created SELECT policy for trial sessions';

  -- Ensure UPDATE policy allows requesters to update their own requests
  DROP POLICY IF EXISTS "Users can update their trial sessions" ON public.trial_sessions;
  
  CREATE POLICY "Users can update their trial sessions"
    ON public.trial_sessions
    FOR UPDATE
    TO authenticated
    USING (
      requester_id = auth.uid() -- Requesters can update
      OR tutor_id = auth.uid()   -- Tutors can update (approve/reject)
    )
    WITH CHECK (
      requester_id = auth.uid() 
      OR tutor_id = auth.uid()
    );

  RAISE NOTICE '✅ Created UPDATE policy for trial sessions';

END $$;

-- STEP 2: Verify there are no CHECK constraints preventing parent IDs in learner_id
-- The learner_id should be able to reference any user (parent or learner)

DO $$
DECLARE
  check_constraint_name TEXT;
  constraint_def TEXT;
BEGIN
  RAISE NOTICE '';
  RAISE NOTICE '========================================';
  RAISE NOTICE 'CHECKING FOR RESTRICTIVE CONSTRAINTS';
  RAISE NOTICE '========================================';

  -- Find and report any CHECK constraints that might restrict learner_id
  FOR check_constraint_name, constraint_def IN
    SELECT 
      tc.constraint_name,
      pg_get_constraintdef(c.oid) as constraint_definition
    FROM information_schema.table_constraints tc
    JOIN pg_constraint c ON c.conname = tc.constraint_name
    WHERE tc.table_schema = 'public'
      AND tc.table_name = 'trial_sessions'
      AND tc.constraint_type = 'CHECK'
      AND (
        pg_get_constraintdef(c.oid) LIKE '%learner_id%'
        OR pg_get_constraintdef(c.oid) LIKE '%user_type%'
      )
  LOOP
    RAISE NOTICE '⚠️ Found potentially restrictive CHECK constraint: %', check_constraint_name;
    RAISE NOTICE '   Definition: %', constraint_def;
    RAISE NOTICE '   Consider dropping this if it prevents parents from booking';
  END LOOP;

  -- If no restrictive constraints found, that's good
  IF NOT FOUND THEN
    RAISE NOTICE '✅ No restrictive CHECK constraints found on learner_id';
  END IF;

END $$;

-- STEP 3: Verify foreign key constraints allow any user type
-- learner_id should reference auth.users(id) which allows any user type

DO $$
DECLARE
  fk_name TEXT;
  fk_def TEXT;
BEGIN
  RAISE NOTICE '';
  RAISE NOTICE '========================================';
  RAISE NOTICE 'VERIFYING FOREIGN KEY CONSTRAINTS';
  RAISE NOTICE '========================================';

  -- Check learner_id foreign key
  SELECT 
    tc.constraint_name,
    pg_get_constraintdef(c.oid)
  INTO fk_name, fk_def
  FROM information_schema.table_constraints tc
  JOIN pg_constraint c ON c.conname = tc.constraint_name
  JOIN information_schema.key_column_usage kcu 
    ON kcu.constraint_name = tc.constraint_name
  WHERE tc.table_schema = 'public'
    AND tc.table_name = 'trial_sessions'
    AND tc.constraint_type = 'FOREIGN KEY'
    AND kcu.column_name = 'learner_id'
  LIMIT 1;

  IF fk_name IS NOT NULL THEN
    RAISE NOTICE '✅ Foreign key constraint on learner_id: %', fk_name;
    RAISE NOTICE '   Definition: %', fk_def;
    
    -- Check if it references auth.users (good) or profiles (also good)
    IF fk_def LIKE '%auth.users%' OR fk_def LIKE '%profiles%' THEN
      RAISE NOTICE '   ✅ FK references users/profiles table (allows any user type)';
    ELSE
      RAISE NOTICE '   ⚠️ FK might be restrictive - check the referenced table';
    END IF;
  ELSE
    RAISE NOTICE '⚠️ No foreign key constraint found on learner_id';
  END IF;

END $$;

-- STEP 4: Test if a parent can theoretically insert (check user exists)
-- This is just a diagnostic query

SELECT 
  'Parent Accounts Check' as check_type,
  COUNT(*) as parent_count,
  'Parents who can book trial sessions' as description
FROM profiles
WHERE user_type = 'parent';

-- STEP 5: Show sample trial_sessions structure
SELECT 
  'trial_sessions structure' as check_type,
  column_name,
  data_type,
  is_nullable,
  column_default
FROM information_schema.columns
WHERE table_schema = 'public'
  AND table_name = 'trial_sessions'
  AND column_name IN ('learner_id', 'parent_id', 'requester_id', 'tutor_id')
ORDER BY column_name;

-- ============================================
-- SUMMARY
-- ============================================
-- 
-- This script:
-- 1. ✅ Creates RLS policies that allow parents to INSERT trial sessions
-- 2. ✅ Allows parents to SELECT their trial sessions
-- 3. ✅ Allows parents to UPDATE their trial session requests
-- 4. ✅ Checks for restrictive CHECK constraints
-- 5. ✅ Verifies foreign key constraints allow any user type
--
-- After running this script:
-- - Parents should be able to create trial session requests
-- - The learner_id can be the parent's ID (temporary solution)
-- - Future: Add UI for parents to select which child they're booking for
--
-- ============================================

