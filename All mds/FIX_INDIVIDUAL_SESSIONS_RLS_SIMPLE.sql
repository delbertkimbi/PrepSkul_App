-- ========================================
-- SIMPLIFIED FIX FOR INDIVIDUAL_SESSIONS RLS
-- ========================================
-- This script creates a simple, permissive INSERT policy
-- that allows users to insert sessions when they are the tutor, learner, or parent

-- Step 1: Verify RLS is enabled
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_tables
        WHERE schemaname = 'public'
        AND tablename = 'individual_sessions'
        AND rowsecurity = true
    ) THEN
        ALTER TABLE public.individual_sessions ENABLE ROW LEVEL SECURITY;
        RAISE NOTICE 'Enabled RLS on individual_sessions';
    ELSE
        RAISE NOTICE 'RLS already enabled on individual_sessions';
    END IF;
END $$;

-- Step 2: Drop ALL existing INSERT policies to avoid conflicts
DO $$
DECLARE
    policy_record RECORD;
BEGIN
    FOR policy_record IN 
        SELECT policyname 
        FROM pg_policies
        WHERE tablename = 'individual_sessions'
        AND cmd = 'INSERT'
    LOOP
        EXECUTE format('DROP POLICY IF EXISTS %I ON public.individual_sessions', policy_record.policyname);
        RAISE NOTICE 'Dropped policy: %', policy_record.policyname;
    END LOOP;
END $$;

-- Step 3: Create simple INSERT policy
-- This policy allows inserts when user is tutor, learner, or parent
-- No complex subqueries - just direct ID matching
CREATE POLICY "Users can insert their own sessions" ON public.individual_sessions
  FOR INSERT
  WITH CHECK (
    auth.uid() = tutor_id 
    OR auth.uid() = learner_id 
    OR auth.uid() = parent_id
  );

-- Step 4: Verify the policy was created
SELECT 
    'INSERT Policy Created' AS status,
    policyname,
    cmd,
    with_check
FROM pg_policies
WHERE tablename = 'individual_sessions'
AND cmd = 'INSERT';

SELECT 'RLS INSERT policy created successfully' AS status;
SELECT 'The policy allows inserts when user is tutor, learner, or parent in the session' AS note;

