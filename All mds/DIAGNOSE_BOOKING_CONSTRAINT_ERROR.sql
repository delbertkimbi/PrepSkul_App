-- Diagnose Booking Constraint Error
-- This script helps identify why booking_requests_student_type_check constraint is failing

-- 1. Check user's current user_type (using the user ID from the error log)
SELECT 
    id,
    email,
    full_name,
    user_type,
    CASE 
        WHEN user_type IN ('learner', 'student') THEN 'learner'
        WHEN user_type = 'parent' THEN 'parent'
        ELSE 'INVALID - needs mapping'
    END AS expected_student_type
FROM public.profiles
WHERE id = '48a62946-b1bc-4fef-a127-fcdd63768a93'; -- User ID from error log

-- 2. Check for existing booking requests with this tutor
SELECT 
    id,
    student_id,
    tutor_id,
    student_type,
    status,
    created_at,
    tutor_name
FROM public.booking_requests
WHERE student_id = '48a62946-b1bc-4fef-a127-fcdd63768a93' -- User ID from error log
ORDER BY created_at DESC;

-- 3. Check for upcoming trial sessions
SELECT 
    id,
    requester_id,
    learner_id,
    parent_id,
    tutor_id,
    status,
    scheduled_date,
    scheduled_time,
    created_at
FROM public.trial_sessions
WHERE (requester_id = '48a62946-b1bc-4fef-a127-fcdd63768a93' 
    OR learner_id = '48a62946-b1bc-4fef-a127-fcdd63768a93' 
    OR parent_id = '48a62946-b1bc-4fef-a127-fcdd63768a93')
  AND tutor_id = '2b2a54da-2f21-4813-aee6-df7e7d043dc4' -- Tutor ID from error log
  AND status IN ('pending', 'approved', 'scheduled')
ORDER BY created_at DESC;

-- 4. Check all user_type values in profiles (to see if there are unexpected values)
SELECT 
    user_type,
    COUNT(*) as count
FROM public.profiles
GROUP BY user_type
ORDER BY count DESC;

-- 5. Check booking_requests table for any invalid student_type values
SELECT 
    id,
    student_id,
    student_type,
    status,
    created_at
FROM public.booking_requests
WHERE student_type NOT IN ('learner', 'parent')
ORDER BY created_at DESC;

