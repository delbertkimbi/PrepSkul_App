-- ========================================
-- VERIFY RLS POLICIES AND TEST INSERT
-- ========================================
-- This script verifies that INSERT policies exist and tests if they work

-- Step 1: Check all RLS policies for individual_sessions
SELECT 
    'All RLS Policies for individual_sessions' AS info,
    policyname,
    cmd,
    permissive,
    roles,
    CASE 
        WHEN qual IS NOT NULL THEN 'USING: ' || qual
        ELSE 'No USING clause'
    END AS using_clause,
    CASE 
        WHEN with_check IS NOT NULL THEN 'WITH CHECK: ' || with_check
        ELSE 'No WITH CHECK clause'
    END AS with_check_clause
FROM pg_policies
WHERE tablename = 'individual_sessions'
ORDER BY cmd, policyname;

-- Step 2: Specifically check for INSERT policies
SELECT 
    'INSERT Policies Check' AS check_type,
    COUNT(*) AS insert_policy_count,
    STRING_AGG(policyname, ', ') AS policy_names
FROM pg_policies
WHERE tablename = 'individual_sessions'
AND cmd = 'INSERT';

-- Step 3: Check if RLS is enabled
SELECT 
    'RLS Status' AS check_type,
    tablename,
    rowsecurity AS rls_enabled
FROM pg_tables
WHERE schemaname = 'public'
AND tablename = 'individual_sessions';

-- Step 4: Show sample recurring session data to understand what should be inserted
SELECT 
    'Sample Recurring Session Data' AS info,
    rs.id AS recurring_session_id,
    rs.learner_id,
    rs.tutor_id,
    rs.learner_type,
    rs.student_type, -- Check if this column still exists
    pr.id AS payment_request_id,
    pr.status AS payment_status,
    pr.recurring_session_id AS payment_recurring_session_id
FROM recurring_sessions rs
INNER JOIN payment_requests pr ON pr.recurring_session_id = rs.id
WHERE pr.status = 'paid'
AND (SELECT COUNT(*) FROM individual_sessions WHERE recurring_session_id = rs.id) = 0
ORDER BY rs.created_at DESC
LIMIT 5;

-- Step 5: Show what the app would try to insert (based on recurring session)
SELECT 
    'What app would insert' AS info,
    rs.id AS recurring_session_id,
    rs.tutor_id,
    CASE 
        WHEN rs.learner_type = 'learner' THEN rs.learner_id
        ELSE NULL
    END AS would_set_learner_id,
    CASE 
        WHEN rs.learner_type = 'parent' THEN rs.learner_id
        ELSE NULL
    END AS would_set_parent_id,
    rs.learner_type,
    'The app inserts with: tutor_id=' || rs.tutor_id || 
    ', learner_id=' || COALESCE(
        CASE WHEN rs.learner_type = 'learner' THEN rs.learner_id::TEXT ELSE NULL END, 
        'NULL'
    ) ||
    ', parent_id=' || COALESCE(
        CASE WHEN rs.learner_type = 'parent' THEN rs.learner_id::TEXT ELSE NULL END,
        'NULL'
    ) AS insert_values
FROM recurring_sessions rs
INNER JOIN payment_requests pr ON pr.recurring_session_id = rs.id
WHERE pr.status = 'paid'
AND (SELECT COUNT(*) FROM individual_sessions WHERE recurring_session_id = rs.id) = 0
ORDER BY rs.created_at DESC
LIMIT 3;

-- Step 6: Recommendations
SELECT 
    'Recommendations' AS section,
    CASE 
        WHEN NOT EXISTS (
            SELECT 1 FROM pg_policies
            WHERE tablename = 'individual_sessions'
            AND cmd = 'INSERT'
        ) THEN '❌ No INSERT policy found - Run FIX_INDIVIDUAL_SESSIONS_RLS_INSERT.sql'
        ELSE '✅ INSERT policy exists'
    END AS policy_status,
    CASE 
        WHEN EXISTS (
            SELECT 1 FROM pg_tables
            WHERE schemaname = 'public'
            AND tablename = 'individual_sessions'
            AND rowsecurity = false
        ) THEN '⚠️ RLS is disabled - Enable it with: ALTER TABLE individual_sessions ENABLE ROW LEVEL SECURITY;'
        ELSE '✅ RLS is enabled'
    END AS rls_status;

SELECT '✅ Diagnostic completed. Review results above.' AS status;

