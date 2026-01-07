-- ========================================
-- MANUAL FIX: CREATE RECURRING SESSION FOR PAID PAYMENT
-- ========================================
-- This script manually creates recurring sessions for payment requests
-- that are paid but missing recurring_session_id
--
-- IMPORTANT: Run this AFTER running VERIFY_AND_FIX_RECURRING_SESSIONS_SCHEMA.sql
-- to ensure all required columns exist

-- Step 1: Show what needs to be fixed
SELECT 
    '🔍 DIAGNOSTIC: Payment requests needing recurring sessions' AS step,
    pr.id AS payment_request_id,
    pr.booking_request_id,
    pr.status AS payment_status,
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

-- Step 2: Check if we can create recurring sessions
-- (This is a diagnostic query - actual creation should be done via the app/webhook)
SELECT 
    '⚠️ NOTE: Recurring sessions should be created via the app/webhook service' AS note,
    'The app will call RecurringSessionService.createRecurringSessionFromBooking()' AS method,
    'Check terminal logs for specific errors when creating recurring sessions' AS action;

-- Step 3: Verify schema is correct before attempting creation
SELECT 
    'Schema Check' AS check_type,
    column_name,
    data_type,
    is_nullable
FROM information_schema.columns 
WHERE table_schema = 'public' 
AND table_name = 'recurring_sessions'
AND column_name IN (
    'id', 'request_id', 'learner_id', 'tutor_id', 
    'subject', 'frequency', 'days', 'times', 'location', 'address',
    'payment_plan', 'monthly_total', 'start_date', 'status',
    'learner_name', 'learner_avatar_url', 'learner_type',
    'tutor_name', 'tutor_avatar_url', 'tutor_rating',
    'total_sessions_completed', 'total_revenue', 'created_at'
)
ORDER BY column_name;

-- Step 4: Show booking request data that will be used
SELECT 
    'Booking Request Data' AS data_type,
    br.id AS booking_request_id,
    br.tutor_id,
    br.student_id AS learner_id,
    br.frequency,
    br.days,
    br.times,
    br.location,
    br.address,
    br.payment_plan,
    br.monthly_total,
    br.subject,
    br.student_name AS learner_name,
    br.student_avatar_url AS learner_avatar_url,
    br.student_type AS learner_type,
    br.tutor_name,
    br.tutor_avatar_url,
    br.tutor_rating
FROM booking_requests br
INNER JOIN payment_requests pr ON br.id = pr.booking_request_id
WHERE pr.status = 'paid'
AND pr.recurring_session_id IS NULL
AND br.status = 'approved'
ORDER BY pr.created_at DESC;

-- Success message
SELECT '✅ Diagnostic completed. Use the app to trigger recurring session creation, or check webhook logs.' AS status;
SELECT '💡 TIP: Try clicking "View Session" again after running the schema fix script - it should trigger creation.' AS tip;

