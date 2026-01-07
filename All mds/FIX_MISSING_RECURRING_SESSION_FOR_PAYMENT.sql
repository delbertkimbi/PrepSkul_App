-- ========================================
-- FIX MISSING RECURRING SESSION FOR PAID PAYMENT
-- ========================================
-- This script finds payment requests that are paid but missing recurring_session_id
-- and attempts to create the recurring session from the booking request

-- Step 1: Find payment requests that need fixing
SELECT 
    pr.id AS payment_request_id,
    pr.booking_request_id,
    pr.status AS payment_status,
    pr.recurring_session_id,
    br.status AS booking_status,
    br.tutor_id,
    br.student_id,
    br.frequency,
    br.days,
    br.times,
    br.location,
    br.payment_plan,
    br.monthly_total
FROM payment_requests pr
LEFT JOIN booking_requests br ON pr.booking_request_id = br.id
WHERE pr.status = 'paid'
AND pr.recurring_session_id IS NULL
AND br.status = 'approved'
ORDER BY pr.created_at DESC;

-- Step 2: Check if recurring sessions already exist for these booking requests
SELECT 
    rs.id AS recurring_session_id,
    rs.request_id AS booking_request_id,
    rs.status AS recurring_session_status,
    pr.id AS payment_request_id,
    pr.status AS payment_status
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

-- Step 3: Link existing recurring sessions to payment requests (if found)
UPDATE payment_requests pr
SET 
    recurring_session_id = rs.id,
    updated_at = NOW()
FROM recurring_sessions rs
WHERE pr.booking_request_id = rs.request_id
AND pr.status = 'paid'
AND pr.recurring_session_id IS NULL
AND rs.request_id = pr.booking_request_id;

-- Report how many were linked
SELECT 
    'Linked existing recurring sessions to payment requests' AS action,
    COUNT(*) AS count
FROM payment_requests pr
INNER JOIN recurring_sessions rs ON pr.booking_request_id = rs.request_id
WHERE pr.status = 'paid'
AND pr.recurring_session_id = rs.id
AND pr.updated_at > NOW() - INTERVAL '1 minute';

-- Step 4: Show remaining payment requests that still need manual intervention
SELECT 
    '⚠️ Payment requests that still need recurring sessions created' AS status,
    pr.id AS payment_request_id,
    pr.booking_request_id,
    br.tutor_id,
    br.student_id
FROM payment_requests pr
LEFT JOIN booking_requests br ON pr.booking_request_id = br.id
WHERE pr.status = 'paid'
AND pr.recurring_session_id IS NULL
AND br.status = 'approved'
ORDER BY pr.created_at DESC;

-- Success message
SELECT '✅ Fix script completed. Check results above.' AS status;
SELECT 'ℹ️ For payment requests that still need recurring sessions, the webhook or app will create them on next payment confirmation.' AS note;

