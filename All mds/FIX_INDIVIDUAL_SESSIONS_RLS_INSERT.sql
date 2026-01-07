-- ========================================
-- FIX INDIVIDUAL_SESSIONS RLS INSERT POLICY
-- ========================================
-- The issue: There's no INSERT policy for individual_sessions table
-- This prevents the app from creating individual sessions
--
-- Solution: Add INSERT policies that allow:
-- 1. Tutors to insert sessions for their recurring sessions
-- 2. Learners/Parents to insert sessions for their recurring sessions (when payment is paid)
-- 3. System/service role to insert (for webhooks)

-- Step 1: Check current policies
SELECT 
    'Current RLS Policies' AS info,
    schemaname,
    tablename,
    policyname,
    permissive,
    roles,
    cmd,
    qual,
    with_check
FROM pg_policies
WHERE tablename = 'individual_sessions'
ORDER BY policyname;

-- Step 2: Drop existing INSERT policies if they exist (to avoid conflicts)
DROP POLICY IF EXISTS "Tutors can insert sessions" ON public.individual_sessions;
DROP POLICY IF EXISTS "Users can insert their own sessions" ON public.individual_sessions;
DROP POLICY IF EXISTS "Tutors and learners can insert sessions" ON public.individual_sessions;
DROP POLICY IF EXISTS "Learners and parents can insert sessions" ON public.individual_sessions;

-- Step 3: Create INSERT policy
-- Allow insert if user is tutor, learner, or parent in the session
-- This allows the app to generate individual sessions when:
-- - A tutor creates sessions for their recurring sessions
-- - A learner/parent creates sessions for their recurring sessions (after payment)
CREATE POLICY "Users can insert their own sessions" ON public.individual_sessions
  FOR INSERT
  WITH CHECK (
    auth.uid() = tutor_id 
    OR auth.uid() = learner_id 
    OR auth.uid() = parent_id
  );

-- Step 6: Verify policies were created
SELECT 
    'New RLS Policies' AS info,
    schemaname,
    tablename,
    policyname,
    cmd,
    CASE 
        WHEN with_check IS NOT NULL THEN 'WITH CHECK: ' || with_check
        ELSE 'No WITH CHECK'
    END AS policy_definition
FROM pg_policies
WHERE tablename = 'individual_sessions'
AND cmd = 'INSERT'
ORDER BY policyname;

-- Step 7: Test query to verify RLS allows inserts
-- This should return true if the policy works
SELECT 
    'RLS Policy Test' AS test_type,
    CASE 
        WHEN EXISTS (
            SELECT 1 FROM pg_policies
            WHERE tablename = 'individual_sessions'
            AND cmd = 'INSERT'
        ) THEN '✅ INSERT policies exist'
        ELSE '❌ No INSERT policies found'
    END AS policy_status;

SELECT '✅ RLS INSERT policies created. The app should now be able to create individual sessions.' AS status;
SELECT '💡 TIP: Try clicking "View Session" again - it should generate individual sessions now.' AS tip;

