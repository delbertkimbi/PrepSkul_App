-- ========================================
-- COMPREHENSIVE DIAGNOSTIC FOR RECURRING SESSIONS ISSUE
-- ========================================
-- This script provides a complete diagnostic view of the problem

-- ========================================
-- PART 1: SCHEMA VERIFICATION
-- ========================================
SELECT '=== PART 1: SCHEMA VERIFICATION ===' AS section;

-- Show all columns in recurring_sessions table
SELECT 
    'Current recurring_sessions columns' AS info,
    column_name, 
    data_type, 
    is_nullable,
    column_default
FROM information_schema.columns 
WHERE table_schema = 'public' 
AND table_name = 'recurring_sessions'
ORDER BY ordinal_position;

-- Check for critical missing columns
SELECT 
    'Missing columns check' AS check_type,
    CASE 
        WHEN EXISTS (
            SELECT 1 FROM information_schema.columns 
            WHERE table_schema = 'public' 
            AND table_name = 'recurring_sessions' 
            AND column_name = 'subject'
        ) THEN '✅ subject exists'
        ELSE '❌ subject MISSING'
    END AS subject_status,
    CASE 
        WHEN EXISTS (
            SELECT 1 FROM information_schema.columns 
            WHERE table_schema = 'public' 
            AND table_name = 'recurring_sessions' 
            AND column_name = 'learner_id'
        ) THEN '✅ learner_id exists'
        WHEN EXISTS (
            SELECT 1 FROM information_schema.columns 
            WHERE table_schema = 'public' 
            AND table_name = 'recurring_sessions' 
            AND column_name = 'student_id'
        ) THEN '⚠️ student_id exists (needs rename to learner_id)'
        ELSE '❌ learner_id/student_id MISSING'
    END AS learner_id_status,
    CASE 
        WHEN EXISTS (
            SELECT 1 FROM information_schema.columns 
            WHERE table_schema = 'public' 
            AND table_name = 'recurring_sessions' 
            AND column_name = 'learner_name'
        ) THEN '✅ learner_name exists'
        WHEN EXISTS (
            SELECT 1 FROM information_schema.columns 
            WHERE table_schema = 'public' 
            AND table_name = 'recurring_sessions' 
            AND column_name = 'student_name'
        ) THEN '⚠️ student_name exists (needs rename to learner_name)'
        ELSE '❌ learner_name/student_name MISSING'
    END AS learner_name_status;

-- ========================================
-- PART 2: PAYMENT REQUESTS ANALYSIS
-- ========================================
SELECT '=== PART 2: PAYMENT REQUESTS ANALYSIS ===' AS section;

-- Find all paid payment requests missing recurring_session_id
SELECT 
    'Paid payments missing recurring sessions' AS issue_type,
    pr.id AS payment_request_id,
    pr.booking_request_id,
    pr.status AS payment_status,
    pr.recurring_session_id,
    pr.created_at AS payment_created_at,
    br.status AS booking_status,
    br.tutor_id,
    br.student_id AS learner_id,
    br.frequency,
    br.days,
    br.location,
    br.payment_plan,
    br.monthly_total
FROM payment_requests pr
INNER JOIN booking_requests br ON pr.booking_request_id = br.id
WHERE pr.status = 'paid'
AND pr.recurring_session_id IS NULL
AND br.status = 'approved'
ORDER BY pr.created_at DESC;

-- Count how many need fixing
SELECT 
    'Count of payments needing recurring sessions' AS metric,
    COUNT(*) AS count
FROM payment_requests pr
INNER JOIN booking_requests br ON pr.booking_request_id = br.id
WHERE pr.status = 'paid'
AND pr.recurring_session_id IS NULL
AND br.status = 'approved';

-- ========================================
-- PART 3: EXISTING RECURRING SESSIONS
-- ========================================
SELECT '=== PART 3: EXISTING RECURRING SESSIONS ===' AS section;

-- Check if recurring sessions exist for these booking requests (but not linked)
SELECT 
    'Unlinked recurring sessions' AS issue_type,
    rs.id AS recurring_session_id,
    rs.request_id AS booking_request_id,
    rs.status AS recurring_session_status,
    rs.learner_id,
    rs.tutor_id,
    rs.subject,
    rs.frequency,
    rs.days,
    pr.id AS payment_request_id,
    pr.status AS payment_status,
    pr.recurring_session_id AS payment_recurring_session_id
FROM recurring_sessions rs
INNER JOIN payment_requests pr ON rs.request_id = pr.booking_request_id
WHERE pr.status = 'paid'
AND pr.recurring_session_id IS NULL
AND rs.request_id IN (
    SELECT booking_request_id 
    FROM payment_requests 
    WHERE status = 'paid' 
    AND recurring_session_id IS NULL
);

-- Count unlinked recurring sessions
SELECT 
    'Count of unlinked recurring sessions' AS metric,
    COUNT(*) AS count
FROM recurring_sessions rs
INNER JOIN payment_requests pr ON rs.request_id = pr.booking_request_id
WHERE pr.status = 'paid'
AND pr.recurring_session_id IS NULL;

-- ========================================
-- PART 4: BOOKING REQUEST DATA VALIDITY
-- ========================================
SELECT '=== PART 4: BOOKING REQUEST DATA VALIDITY ===' AS section;

-- Check if booking requests have all required data
SELECT 
    'Booking request data check' AS check_type,
    br.id AS booking_request_id,
    br.status,
    br.tutor_id,
    br.student_id AS learner_id,
    br.frequency,
    br.days IS NOT NULL AS has_days,
    br.times IS NOT NULL AS has_times,
    br.location,
    br.payment_plan,
    br.monthly_total,
    br.student_name AS learner_name,
    br.student_avatar_url AS learner_avatar_url,
    br.student_type AS learner_type,
    br.tutor_name,
    br.tutor_avatar_url,
    br.tutor_rating,
    CASE 
        WHEN br.tutor_id IS NULL THEN '❌ Missing tutor_id'
        WHEN br.student_id IS NULL THEN '❌ Missing student_id'
        WHEN br.frequency IS NULL THEN '❌ Missing frequency'
        WHEN br.days IS NULL THEN '❌ Missing days'
        WHEN br.times IS NULL THEN '❌ Missing times'
        WHEN br.location IS NULL THEN '❌ Missing location'
        WHEN br.payment_plan IS NULL THEN '❌ Missing payment_plan'
        WHEN br.monthly_total IS NULL THEN '❌ Missing monthly_total'
        ELSE '✅ All required fields present'
    END AS data_completeness
FROM booking_requests br
INNER JOIN payment_requests pr ON br.id = pr.booking_request_id
WHERE pr.status = 'paid'
AND pr.recurring_session_id IS NULL
AND br.status = 'approved'
ORDER BY pr.created_at DESC;

-- ========================================
-- PART 5: SUMMARY AND RECOMMENDATIONS
-- ========================================
SELECT '=== PART 5: SUMMARY ===' AS section;

-- Overall summary
SELECT 
    'Summary' AS section,
    (SELECT COUNT(*) FROM payment_requests WHERE status = 'paid' AND recurring_session_id IS NULL) AS paid_payments_missing_sessions,
    (SELECT COUNT(*) FROM recurring_sessions rs 
     INNER JOIN payment_requests pr ON rs.request_id = pr.booking_request_id 
     WHERE pr.status = 'paid' AND pr.recurring_session_id IS NULL) AS unlinked_recurring_sessions,
    CASE 
        WHEN EXISTS (
            SELECT 1 FROM information_schema.columns 
            WHERE table_schema = 'public' 
            AND table_name = 'recurring_sessions' 
            AND column_name = 'subject'
        ) THEN '✅ Schema OK'
        ELSE '❌ Schema needs fixing'
    END AS schema_status;

-- Recommendations
SELECT 
    'Recommendations' AS section,
    CASE 
        WHEN NOT EXISTS (
            SELECT 1 FROM information_schema.columns 
            WHERE table_schema = 'public' 
            AND table_name = 'recurring_sessions' 
            AND column_name = 'subject'
        ) THEN '1. Run VERIFY_AND_FIX_RECURRING_SESSIONS_SCHEMA.sql to fix schema'
        ELSE '1. Schema appears correct'
    END AS step_1,
    CASE 
        WHEN EXISTS (
            SELECT 1 FROM recurring_sessions rs 
            INNER JOIN payment_requests pr ON rs.request_id = pr.booking_request_id 
            WHERE pr.status = 'paid' AND pr.recurring_session_id IS NULL
        ) THEN '2. Run FIX_MISSING_RECURRING_SESSION_FOR_PAYMENT.sql to link existing sessions'
        ELSE '2. No unlinked sessions found'
    END AS step_2,
    CASE 
        WHEN EXISTS (
            SELECT 1 FROM payment_requests pr
            INNER JOIN booking_requests br ON pr.booking_request_id = br.id
            WHERE pr.status = 'paid'
            AND pr.recurring_session_id IS NULL
            AND br.status = 'approved'
        ) THEN '3. Recurring sessions need to be created via app/webhook for remaining payments'
        ELSE '3. All payments have recurring sessions'
    END AS step_3;

SELECT '✅ Diagnostic completed. Review all sections above.' AS status;

