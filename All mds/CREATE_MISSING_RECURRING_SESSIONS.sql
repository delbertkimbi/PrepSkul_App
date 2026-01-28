-- ========================================
-- CREATE MISSING RECURRING SESSIONS FOR PAID PAYMENTS
-- ========================================
-- This script creates recurring sessions for payment requests that are paid
-- but missing recurring_session_id
--
-- IMPORTANT: Run VERIFY_AND_FIX_RECURRING_SESSIONS_SCHEMA.sql first!

-- Step 1: Show what will be created
SELECT 
    'Will create recurring sessions for these payments' AS info,
    pr.id AS payment_request_id,
    pr.booking_request_id,
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

-- Step 2: Create recurring sessions
-- Note: This uses a simplified approach. For production, the app's 
-- RecurringSessionService.createRecurringSessionFromBooking should be used
-- But this SQL will work as a one-time fix

DO $$
DECLARE
    payment_record RECORD;
    booking_record RECORD;
    new_recurring_session_id UUID;
    start_date DATE;
    first_day TEXT;
    days_array TEXT[];
    times_json JSONB;
BEGIN
    -- Loop through all paid payments missing recurring sessions
    FOR payment_record IN 
        SELECT pr.id AS payment_id, pr.booking_request_id, pr.created_at
        FROM payment_requests pr
        INNER JOIN booking_requests br ON pr.booking_request_id = br.id
        WHERE pr.status = 'paid'
        AND pr.recurring_session_id IS NULL
        AND br.status = 'approved'
        ORDER BY pr.created_at DESC
    LOOP
        -- Get booking request data
        SELECT * INTO booking_record
        FROM booking_requests
        WHERE id = payment_record.booking_request_id;
        
        -- Skip if booking request not found
        IF booking_record IS NULL THEN
            RAISE NOTICE '⚠️ Booking request not found: %', payment_record.booking_request_id;
            CONTINUE;
        END IF;
        
        -- Calculate start date (next Monday or next occurrence of first day)
        days_array := booking_record.days;
        times_json := booking_record.times;
        
        IF array_length(days_array, 1) > 0 THEN
            first_day := days_array[1];
            -- Simple calculation: start from today or next week
            start_date := CURRENT_DATE;
            -- If today is past the first day of the week, start next week
            IF EXTRACT(DOW FROM start_date) > 1 THEN -- 1 = Monday
                start_date := start_date + (8 - EXTRACT(DOW FROM start_date))::INTEGER;
            END IF;
        ELSE
            start_date := CURRENT_DATE;
        END IF;
        
        -- Create recurring session
        -- Note: request_id is set to NULL because the foreign key references session_requests,
        -- but we're using booking_requests. The constraint allows NULL (ON DELETE SET NULL).
        INSERT INTO recurring_sessions (
            request_id, -- Set to NULL due to FK constraint mismatch (references session_requests, not booking_requests)
            learner_id,
            tutor_id,
            frequency,
            days,
            times,
            location,
            address,
            payment_plan,
            monthly_total,
            start_date,
            end_date,
            status,
            total_sessions_completed,
            total_revenue,
            learner_name,
            learner_avatar_url,
            learner_type,
            tutor_name,
            tutor_avatar_url,
            tutor_rating,
            subject,
            created_at,
            updated_at
        ) VALUES (
            NULL, -- Cannot use booking_record.id due to FK constraint to session_requests
            booking_record.student_id,
            booking_record.tutor_id,
            booking_record.frequency,
            booking_record.days,
            booking_record.times,
            booking_record.location,
            booking_record.address,
            booking_record.payment_plan,
            booking_record.monthly_total,
            start_date::TIMESTAMP WITH TIME ZONE,
            NULL, -- Ongoing
            'active',
            0,
            0.0,
            booking_record.student_name,
            booking_record.student_avatar_url,
            booking_record.student_type,
            booking_record.tutor_name,
            booking_record.tutor_avatar_url,
            booking_record.tutor_rating,
            'Tutoring Session', -- Default subject (booking_requests may not have subject column)
            NOW(),
            NOW()
        )
        RETURNING id INTO new_recurring_session_id;
        
        -- Link payment request to recurring session
        UPDATE payment_requests
        SET 
            recurring_session_id = new_recurring_session_id,
            updated_at = NOW()
        WHERE id = payment_record.payment_id;
        
        RAISE NOTICE '✅ Created recurring session % for payment %', new_recurring_session_id, payment_record.payment_id;
    END LOOP;
    
    RAISE NOTICE '✅ Completed creating recurring sessions';
END $$;

-- Step 3: Verify what was created
SELECT 
    'Created recurring sessions' AS status,
    rs.id AS recurring_session_id,
    rs.request_id AS request_id,
    pr.booking_request_id AS booking_request_id,
    rs.status AS recurring_session_status,
    pr.id AS payment_request_id,
    pr.status AS payment_status,
    pr.recurring_session_id AS payment_recurring_session_id
FROM recurring_sessions rs
INNER JOIN payment_requests pr ON pr.recurring_session_id = rs.id
WHERE pr.status = 'paid'
AND pr.recurring_session_id = rs.id
AND rs.created_at > NOW() - INTERVAL '5 minutes'
ORDER BY rs.created_at DESC;

-- Step 4: Count remaining issues
SELECT 
    'Remaining payments missing recurring sessions' AS status,
    COUNT(*) AS count
FROM payment_requests pr
INNER JOIN booking_requests br ON pr.booking_request_id = br.id
WHERE pr.status = 'paid'
AND pr.recurring_session_id IS NULL
AND br.status = 'approved';

-- Step 5: Generate individual sessions for newly created recurring sessions
-- Note: This should ideally be done via the app's RecurringSessionService.generateIndividualSessions
-- But we can at least verify they need to be generated
SELECT 
    'Recurring sessions that need individual sessions generated' AS status,
    rs.id AS recurring_session_id,
    pr.booking_request_id AS booking_request_id,
    (SELECT COUNT(*) FROM individual_sessions WHERE recurring_session_id = rs.id) AS existing_individual_sessions_count
FROM recurring_sessions rs
INNER JOIN payment_requests pr ON pr.recurring_session_id = rs.id
WHERE pr.status = 'paid'
AND pr.recurring_session_id = rs.id
AND rs.created_at > NOW() - INTERVAL '5 minutes'
ORDER BY rs.created_at DESC;

SELECT '✅ Script completed. Check results above.' AS status;
SELECT '⚠️ IMPORTANT: After running this script, individual sessions need to be generated via the app or webhook.' AS note;
SELECT '💡 TIP: Try clicking "View Session" in the app - it should now work and trigger individual session generation.' AS tip;

