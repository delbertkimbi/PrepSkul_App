-- ========================================
-- DIAGNOSE RLS INSERT FAILURE
-- ========================================
-- This script helps diagnose why RLS INSERT policies might be failing

-- Step 1: Check current RLS policies
SELECT 
    'Current RLS Policies' AS info,
    policyname,
    cmd,
    CASE 
        WHEN with_check IS NOT NULL THEN with_check
        ELSE 'No WITH CHECK clause'
    END AS with_check_clause
FROM pg_policies
WHERE tablename = 'individual_sessions'
AND cmd = 'INSERT'
ORDER BY policyname;

-- Step 2: Check RLS status
SELECT 
    'RLS Status' AS check_type,
    tablename,
    rowsecurity AS rls_enabled
FROM pg_tables
WHERE schemaname = 'public'
AND tablename = 'individual_sessions';

-- Step 3: Find recent recurring sessions with paid payments but no individual sessions
SELECT 
    'Recurring Sessions Needing Individual Sessions' AS info,
    rs.id AS recurring_session_id,
    rs.learner_id,
    rs.tutor_id,
    rs.learner_type,
    pr.id AS payment_request_id,
    pr.status AS payment_status,
    pr.student_id AS payment_student_id,
    (SELECT COUNT(*) FROM individual_sessions WHERE recurring_session_id = rs.id) AS existing_session_count
FROM recurring_sessions rs
INNER JOIN payment_requests pr ON pr.recurring_session_id = rs.id
WHERE pr.status = 'paid'
AND (SELECT COUNT(*) FROM individual_sessions WHERE recurring_session_id = rs.id) = 0
ORDER BY rs.created_at DESC
LIMIT 5;

-- Step 4: Show what the app would try to insert
-- This shows the exact data that would be inserted and whether RLS would allow it
SELECT 
    'What App Would Insert' AS info,
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
    pr.student_id AS payment_student_id,
    CASE 
        WHEN rs.learner_type = 'learner' AND rs.learner_id = pr.student_id THEN 'MATCH - learner_id matches payment student_id'
        WHEN rs.learner_type = 'parent' AND rs.learner_id = pr.student_id THEN 'MATCH - parent_id matches payment student_id'
        WHEN rs.tutor_id = pr.student_id THEN 'MATCH - tutor_id matches payment student_id'
        ELSE 'MISMATCH - IDs do not align'
    END AS id_match_status
FROM recurring_sessions rs
INNER JOIN payment_requests pr ON pr.recurring_session_id = rs.id
WHERE pr.status = 'paid'
AND (SELECT COUNT(*) FROM individual_sessions WHERE recurring_session_id = rs.id) = 0
ORDER BY rs.created_at DESC
LIMIT 3;

-- Step 5: Test policy conditions manually
-- This simulates what the RLS policy would check
SELECT 
    'RLS Policy Test Simulation' AS info,
    rs.id AS recurring_session_id,
    rs.tutor_id,
    CASE WHEN rs.learner_type = 'learner' THEN rs.learner_id ELSE NULL END AS learner_id,
    CASE WHEN rs.learner_type = 'parent' THEN rs.learner_id ELSE NULL END AS parent_id,
    pr.student_id AS auth_uid_simulation,
    CASE 
        WHEN pr.student_id = rs.tutor_id THEN 'PASS - auth.uid() = tutor_id'
        WHEN pr.student_id = CASE WHEN rs.learner_type = 'learner' THEN rs.learner_id ELSE NULL END THEN 'PASS - auth.uid() = learner_id'
        WHEN pr.student_id = CASE WHEN rs.learner_type = 'parent' THEN rs.learner_id ELSE NULL END THEN 'PASS - auth.uid() = parent_id'
        ELSE 'FAIL - auth.uid() does not match any ID'
    END AS rls_check_result
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
        ) THEN 'No INSERT policy found - Run FIX_INDIVIDUAL_SESSIONS_RLS_SIMPLE.sql'
        ELSE 'INSERT policy exists'
    END AS policy_status,
    CASE 
        WHEN EXISTS (
            SELECT 1 FROM pg_tables
            WHERE schemaname = 'public'
            AND tablename = 'individual_sessions'
            AND rowsecurity = false
        ) THEN 'RLS is disabled - Enable it'
        ELSE 'RLS is enabled'
    END AS rls_status;

SELECT 'Diagnostic completed. Review results above to identify the issue.' AS status;

