-- ============================================
-- FIX PARENT TRIAL BOOKING CONSTRAINTS
-- This script diagnoses and fixes database constraints that prevent parents from booking trial sessions
-- ============================================

DO $$
DECLARE
  constraint_name_val TEXT;
  constraint_def TEXT;
BEGIN
  RAISE NOTICE '========================================';
  RAISE NOTICE 'DIAGNOSING TRIAL_SESSIONS CONSTRAINTS';
  RAISE NOTICE '========================================';

  -- STEP 1: Check all constraints on trial_sessions table
  RAISE NOTICE '';
  RAISE NOTICE 'STEP 1: Checking constraints on trial_sessions table...';
  
  FOR constraint_name_val, constraint_def IN
    SELECT 
      tc.constraint_name,
      pg_get_constraintdef(c.oid) as constraint_definition
    FROM information_schema.table_constraints tc
    JOIN pg_constraint c ON c.conname = tc.constraint_name
    WHERE tc.table_schema = 'public'
      AND tc.table_name = 'trial_sessions'
      AND tc.constraint_type IN ('CHECK', 'FOREIGN KEY', 'UNIQUE', 'PRIMARY KEY')
    ORDER BY tc.constraint_type, tc.constraint_name
  LOOP
    RAISE NOTICE 'Constraint: % - %', constraint_name_val, constraint_def;
  END LOOP;

  -- STEP 2: Check foreign key constraints on learner_id
  RAISE NOTICE '';
  RAISE NOTICE 'STEP 2: Checking foreign key constraints on learner_id...';
  
  FOR constraint_name_val, constraint_def IN
    SELECT 
      tc.constraint_name,
      pg_get_constraintdef(c.oid) as constraint_definition
    FROM information_schema.table_constraints tc
    JOIN pg_constraint c ON c.conname = tc.constraint_name
    JOIN information_schema.key_column_usage kcu 
      ON kcu.constraint_name = tc.constraint_name
    WHERE tc.table_schema = 'public'
      AND tc.table_name = 'trial_sessions'
      AND tc.constraint_type = 'FOREIGN KEY'
      AND kcu.column_name = 'learner_id'
  LOOP
    RAISE NOTICE 'FK Constraint on learner_id: % - %', constraint_name_val, constraint_def;
  END LOOP;

  -- STEP 3: Check CHECK constraints that might restrict learner_id
  RAISE NOTICE '';
  RAISE NOTICE 'STEP 3: Checking CHECK constraints that might restrict learner_id...';
  
  FOR constraint_name_val, constraint_def IN
    SELECT 
      tc.constraint_name,
      pg_get_constraintdef(c.oid) as constraint_definition
    FROM information_schema.table_constraints tc
    JOIN pg_constraint c ON c.conname = tc.constraint_name
    WHERE tc.table_schema = 'public'
      AND tc.table_name = 'trial_sessions'
      AND tc.constraint_type = 'CHECK'
      AND pg_get_constraintdef(c.oid) LIKE '%learner%'
  LOOP
    RAISE NOTICE 'CHECK Constraint: % - %', constraint_name_val, constraint_def;
  END LOOP;

END $$;

-- ============================================
-- STEP 4: FIX CONSTRAINTS
-- ============================================

DO $$
BEGIN
  RAISE NOTICE '';
  RAISE NOTICE '========================================';
  RAISE NOTICE 'FIXING CONSTRAINTS';
  RAISE NOTICE '========================================';

  -- Check if trial_sessions table exists
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.tables 
    WHERE table_schema = 'public' 
    AND table_name = 'trial_sessions'
  ) THEN
    RAISE EXCEPTION 'trial_sessions table does not exist!';
  END IF;

  -- STEP 4.1: Drop any CHECK constraints that restrict learner_id to only 'learner' user_type
  -- These constraints might prevent parents from booking
  DECLARE
    check_constraint_name TEXT;
  BEGIN
    FOR check_constraint_name IN
      SELECT tc.constraint_name
      FROM information_schema.table_constraints tc
      JOIN pg_constraint c ON c.conname = tc.constraint_name
      WHERE tc.table_schema = 'public'
        AND tc.table_name = 'trial_sessions'
        AND tc.constraint_type = 'CHECK'
        AND (
          pg_get_constraintdef(c.oid) LIKE '%learner_id%user_type%'
          OR pg_get_constraintdef(c.oid) LIKE '%user_type%learner%'
          OR pg_get_constraintdef(c.oid) LIKE '%learner_id%IN%'
        )
    LOOP
      EXECUTE format('ALTER TABLE public.trial_sessions DROP CONSTRAINT IF EXISTS %I', check_constraint_name);
      RAISE NOTICE '✅ Dropped restrictive CHECK constraint: %', check_constraint_name;
    END LOOP;
  END;

  -- STEP 4.2: Ensure learner_id foreign key allows any user (not just learners)
  -- Check if there's a foreign key that might be too restrictive
  DECLARE
    fk_constraint_name TEXT;
    fk_table_name TEXT;
  BEGIN
    FOR fk_constraint_name, fk_table_name IN
      SELECT 
        tc.constraint_name,
        ccu.table_name as referenced_table
      FROM information_schema.table_constraints tc
      JOIN pg_constraint c ON c.conname = tc.constraint_name
      JOIN information_schema.key_column_usage kcu 
        ON kcu.constraint_name = tc.constraint_name
      JOIN information_schema.constraint_column_usage ccu
        ON ccu.constraint_name = tc.constraint_name
      WHERE tc.table_schema = 'public'
        AND tc.table_name = 'trial_sessions'
        AND tc.constraint_type = 'FOREIGN KEY'
        AND kcu.column_name = 'learner_id'
        AND ccu.table_name != 'profiles'
        AND ccu.table_name != 'auth.users'
    LOOP
      -- If FK references a table other than profiles/auth.users, it might be restrictive
      RAISE NOTICE '⚠️ Found FK constraint on learner_id referencing %: %', fk_table_name, fk_constraint_name;
      RAISE NOTICE '   Consider dropping this if it prevents parents from booking';
    END LOOP;
  END;

  -- STEP 4.3: Ensure learner_id can reference any user in profiles (not just learners)
  -- Drop and recreate FK if it exists and is too restrictive
  IF EXISTS (
    SELECT 1 FROM information_schema.table_constraints tc
    JOIN pg_constraint c ON c.conname = tc.constraint_name
    JOIN information_schema.key_column_usage kcu 
      ON kcu.constraint_name = tc.constraint_name
    WHERE tc.table_schema = 'public'
      AND tc.table_name = 'trial_sessions'
      AND tc.constraint_type = 'FOREIGN KEY'
      AND kcu.column_name = 'learner_id'
  ) THEN
    -- Get the FK constraint name
    DECLARE
      fk_name TEXT;
    BEGIN
      SELECT tc.constraint_name INTO fk_name
      FROM information_schema.table_constraints tc
      JOIN information_schema.key_column_usage kcu 
        ON kcu.constraint_name = tc.constraint_name
      WHERE tc.table_schema = 'public'
        AND tc.table_name = 'trial_sessions'
        AND tc.constraint_type = 'FOREIGN KEY'
        AND kcu.column_name = 'learner_id'
      LIMIT 1;

      IF fk_name IS NOT NULL THEN
        -- Check if it references profiles.id (good) or something else (might be restrictive)
        DECLARE
          ref_table TEXT;
        BEGIN
          SELECT ccu.table_name INTO ref_table
          FROM information_schema.constraint_column_usage ccu
          WHERE ccu.constraint_name = fk_name
          LIMIT 1;

          IF ref_table = 'profiles' OR ref_table = 'auth.users' THEN
            RAISE NOTICE '✅ FK constraint on learner_id correctly references % (allows any user)', ref_table;
          ELSE
            RAISE NOTICE '⚠️ FK constraint on learner_id references % - this might be restrictive', ref_table;
            RAISE NOTICE '   Consider updating to reference profiles.id instead';
          END IF;
        END;
      END IF;
    END;
  ELSE
    -- No FK constraint exists - add one that allows any user
    RAISE NOTICE 'ℹ️ No FK constraint found on learner_id - this is OK';
  END IF;

  RAISE NOTICE '';
  RAISE NOTICE '✅ Constraint check complete!';
  RAISE NOTICE '';
  RAISE NOTICE 'If parents still cannot book, check:';
  RAISE NOTICE '1. RLS policies on trial_sessions table';
  RAISE NOTICE '2. Any triggers that might validate user_type';
  RAISE NOTICE '3. Application-level validation in the code';

END $$;

-- ============================================
-- STEP 5: CHECK RLS POLICIES
-- ============================================

SELECT 
  'RLS Policies on trial_sessions' as check_type,
  schemaname,
  tablename,
  policyname,
  permissive,
  roles,
  cmd,
  qual,
  with_check
FROM pg_policies
WHERE schemaname = 'public'
  AND tablename = 'trial_sessions'
ORDER BY policyname;

-- ============================================
-- STEP 6: VERIFY TABLE STRUCTURE
-- ============================================

SELECT 
  'trial_sessions columns' as check_type,
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
-- STEP 7: TEST DATA CHECK
-- ============================================

-- Check if there are any existing trial sessions with parent as learner_id
SELECT 
  'Existing parent bookings' as check_type,
  COUNT(*) as count,
  'trial_sessions where learner_id has user_type = parent' as description
FROM trial_sessions ts
JOIN profiles p ON p.id = ts.learner_id
WHERE p.user_type = 'parent';

-- ============================================
-- DONE!
-- ============================================
-- 
-- After running this script:
-- 1. Review the output to see what constraints exist
-- 2. If there are restrictive constraints, they will be identified
-- 3. Check RLS policies to ensure parents can insert
-- 4. If issues persist, check application-level validation
--
-- ============================================

