-- ========================================
-- COMPLETE FIX FOR INDIVIDUAL_SESSIONS RLS
-- ========================================
-- This script ensures INSERT policies exist and work correctly

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

-- Step 3: Create comprehensive INSERT policy
-- This policy allows inserts when:
-- 1. User is the tutor
-- 2. User is the learner
-- 3. User is the parent
-- 4. OR if the recurring_session exists and payment is paid (for system-generated sessions)
CREATE POLICY "Users can insert their own sessions" ON public.individual_sessions
  FOR INSERT
  WITH CHECK (
    -- User is the tutor
    auth.uid() = tutor_id 
    OR 
    -- User is the learner
    auth.uid() = learner_id 
    OR 
    -- User is the parent
    auth.uid() = parent_id
    OR
    -- Allow if recurring_session exists and payment is paid (for automatic generation)
    (
      recurring_session_id IS NOT NULL
      AND EXISTS (
        SELECT 1 FROM payment_requests pr
        INNER JOIN recurring_sessions rs ON pr.recurring_session_id = rs.id
        WHERE rs.id = individual_sessions.recurring_session_id
        AND pr.status = 'paid'
        AND (
          pr.student_id = auth.uid()
          OR rs.learner_id = auth.uid()
          OR rs.tutor_id = auth.uid()
        )
      )
    )
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

-- Step 5: Show current user context (for debugging)
-- Note: This will show NULL if run from SQL editor (no auth context)
-- But it helps verify the policy structure
SELECT 
    'Policy Verification' AS info,
    'Current policies for individual_sessions' AS description,
    COUNT(*) FILTER (WHERE cmd = 'SELECT') AS select_policies,
    COUNT(*) FILTER (WHERE cmd = 'INSERT') AS insert_policies,
    COUNT(*) FILTER (WHERE cmd = 'UPDATE') AS update_policies,
    COUNT(*) FILTER (WHERE cmd = 'DELETE') AS delete_policies
FROM pg_policies
WHERE tablename = 'individual_sessions';

SELECT '✅ RLS INSERT policy created successfully!' AS status;
SELECT '💡 The policy allows inserts when user is tutor, learner, or parent in the session.' AS note;
SELECT '⚠️ If you still get RLS errors, check that auth.uid() matches tutor_id, learner_id, or parent_id in the insert.' AS warning;

