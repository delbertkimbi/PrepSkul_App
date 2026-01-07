-- ======================================================
-- GENERATE MISSING INDIVIDUAL SESSIONS
-- This script helps identify recurring sessions that don't have
-- individual sessions generated, and provides a way to manually
-- trigger generation if needed.
-- ======================================================

-- STEP 0: Check what columns exist in recurring_sessions table
SELECT 
    column_name, 
    data_type
FROM 
    information_schema.columns
WHERE 
    table_schema = 'public' 
    AND table_name = 'recurring_sessions'
    AND column_name IN ('student_id', 'learner_id', 'parent_id')
ORDER BY 
    column_name;

-- STEP 1: Find recurring sessions without individual sessions
-- This query shows recurring sessions that should have individual sessions
-- but don't have any (or have very few)
SELECT 
    rs.id AS recurring_session_id,
    rs.tutor_id,
    rs.start_date,
    rs.status AS recurring_status,
    rs.days,
    rs.times,
    rs.frequency,
    COUNT(is_sessions.id) AS individual_sessions_count,
    CASE 
        WHEN COUNT(is_sessions.id) = 0 THEN 'NO SESSIONS - NEEDS GENERATION'
        WHEN COUNT(is_sessions.id) < (rs.frequency * 2) THEN 'FEW SESSIONS - MAY NEED MORE'
        ELSE 'OK'
    END AS status_check
FROM 
    public.recurring_sessions rs
LEFT JOIN 
    public.individual_sessions is_sessions 
    ON rs.id = is_sessions.recurring_session_id
WHERE 
    rs.status = 'active'
    AND rs.start_date::date <= (CURRENT_DATE + INTERVAL '8 weeks')::date
GROUP BY 
    rs.id, rs.tutor_id, rs.start_date, rs.status, rs.days, rs.times, rs.frequency
HAVING 
    COUNT(is_sessions.id) < (rs.frequency * 4) -- Less than 4 weeks worth of sessions
ORDER BY 
    individual_sessions_count ASC, rs.start_date ASC;

-- STEP 2: Check specific recurring session by ID
-- Replace 'YOUR_RECURRING_SESSION_ID' with the actual ID from step 1
/*
SELECT 
    rs.id AS recurring_session_id,
    rs.tutor_id,
    rs.start_date,
    rs.days,
    rs.times,
    rs.frequency,
    rs.status,
    COUNT(is_sessions.id) AS individual_sessions_count,
    MIN(is_sessions.scheduled_date) AS first_session_date,
    MAX(is_sessions.scheduled_date) AS last_session_date
FROM 
    public.recurring_sessions rs
LEFT JOIN 
    public.individual_sessions is_sessions 
    ON rs.id = is_sessions.recurring_session_id
WHERE 
    rs.id = 'YOUR_RECURRING_SESSION_ID'
GROUP BY 
    rs.id, rs.tutor_id, rs.start_date, rs.days, rs.times, rs.frequency, rs.status;
*/

-- STEP 3: View individual sessions for a specific recurring session
-- Replace 'YOUR_RECURRING_SESSION_ID' with the actual ID
/*
SELECT 
    id,
    scheduled_date,
    scheduled_time,
    status,
    tutor_id,
    learner_id,
    parent_id,
    location,
    created_at
FROM 
    public.individual_sessions
WHERE 
    recurring_session_id = 'YOUR_RECURRING_SESSION_ID'
ORDER BY 
    scheduled_date ASC, scheduled_time ASC;
*/

-- NOTE: If individual sessions are missing, you'll need to:
-- 1. Use the Flutter app to manually trigger generation, OR
-- 2. Contact support to regenerate sessions for the recurring session
-- The generation logic is in: lib/features/booking/services/recurring_session_service.dart
-- Method: generateIndividualSessions()

