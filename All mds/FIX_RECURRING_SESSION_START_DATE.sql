-- ========================================
-- FIX RECURRING SESSION START DATE
-- ========================================
-- This script fixes recurring sessions that have start_date in the past
-- which prevents individual session generation

-- Step 1: Find recurring sessions with past start_date and no individual sessions
SELECT 
    'Recurring sessions with past start_date' AS issue_type,
    rs.id AS recurring_session_id,
    rs.start_date,
    rs.days,
    rs.times,
    rs.frequency,
    CURRENT_DATE AS today,
    (rs.start_date::DATE < CURRENT_DATE) AS is_past,
    (SELECT COUNT(*) FROM individual_sessions WHERE recurring_session_id = rs.id) AS individual_sessions_count
FROM recurring_sessions rs
INNER JOIN payment_requests pr ON pr.recurring_session_id = rs.id
WHERE pr.status = 'paid'
AND rs.start_date::DATE < CURRENT_DATE
AND (SELECT COUNT(*) FROM individual_sessions WHERE recurring_session_id = rs.id) = 0
ORDER BY rs.start_date DESC;

-- Step 2: Update start_date to next occurrence of first day
DO $$
DECLARE
    rs_record RECORD;
    new_start_date DATE;
    first_day TEXT;
    days_array TEXT[];
    day_index INTEGER;
    current_dow INTEGER;
    days_until INTEGER;
BEGIN
    FOR rs_record IN 
        SELECT rs.id, rs.start_date, rs.days
        FROM recurring_sessions rs
        INNER JOIN payment_requests pr ON pr.recurring_session_id = rs.id
        WHERE pr.status = 'paid'
        AND rs.start_date::DATE < CURRENT_DATE
        AND (SELECT COUNT(*) FROM individual_sessions WHERE recurring_session_id = rs.id) = 0
    LOOP
        days_array := rs_record.days;
        
        IF array_length(days_array, 1) > 0 THEN
            first_day := days_array[1];
            
            -- Map day name to day of week (Monday = 1, Sunday = 7)
            CASE first_day
                WHEN 'Monday' THEN day_index := 1;
                WHEN 'Tuesday' THEN day_index := 2;
                WHEN 'Wednesday' THEN day_index := 3;
                WHEN 'Thursday' THEN day_index := 4;
                WHEN 'Friday' THEN day_index := 5;
                WHEN 'Saturday' THEN day_index := 6;
                WHEN 'Sunday' THEN day_index := 7;
                ELSE day_index := 1; -- Default to Monday
            END CASE;
            
            -- Get current day of week (PostgreSQL: 0=Sunday, 1=Monday, etc.)
            current_dow := EXTRACT(DOW FROM CURRENT_DATE)::INTEGER;
            -- Convert to Monday=1, Sunday=7 format
            IF current_dow = 0 THEN
                current_dow := 7;
            END IF;
            
            -- Calculate days until next occurrence
            days_until := (day_index - current_dow) % 7;
            IF days_until <= 0 THEN
                days_until := days_until + 7; -- Next week
            END IF;
            
            new_start_date := CURRENT_DATE + (days_until || ' days')::INTERVAL;
            
            -- Update recurring session
            UPDATE recurring_sessions
            SET 
                start_date = new_start_date::TIMESTAMP WITH TIME ZONE,
                updated_at = NOW()
            WHERE id = rs_record.id;
            
            RAISE NOTICE '✅ Updated recurring session %: start_date from % to %', 
                rs_record.id, rs_record.start_date, new_start_date;
        END IF;
    END LOOP;
    
    RAISE NOTICE '✅ Completed updating start dates';
END $$;

-- Step 3: Verify updates
SELECT 
    'Updated recurring sessions' AS status,
    rs.id AS recurring_session_id,
    rs.start_date,
    rs.days,
    (rs.start_date::DATE >= CURRENT_DATE) AS is_future,
    (SELECT COUNT(*) FROM individual_sessions WHERE recurring_session_id = rs.id) AS individual_sessions_count
FROM recurring_sessions rs
INNER JOIN payment_requests pr ON pr.recurring_session_id = rs.id
WHERE pr.status = 'paid'
AND rs.updated_at > NOW() - INTERVAL '5 minutes'
ORDER BY rs.updated_at DESC;

SELECT '✅ Script completed. Try clicking "View Session" again in the app.' AS status;
SELECT '💡 TIP: The app will now automatically generate individual sessions when you click "View Session".' AS tip;

