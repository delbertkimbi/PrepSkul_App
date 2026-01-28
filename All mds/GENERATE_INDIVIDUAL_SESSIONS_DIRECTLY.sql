-- ========================================
-- GENERATE INDIVIDUAL SESSIONS DIRECTLY
-- ========================================
-- This script directly generates individual sessions for recurring sessions
-- that don't have any individual sessions yet
--
-- This bypasses the app logic and creates sessions directly in the database

-- Step 1: Find recurring sessions that need individual sessions
SELECT 
    'Recurring sessions needing individual sessions' AS info,
    rs.id AS recurring_session_id,
    rs.start_date,
    rs.days,
    rs.times,
    rs.frequency,
    rs.location,
    rs.address,
    rs.learner_id,
    rs.tutor_id,
    rs.learner_type,
    rs.subject,
    (SELECT COUNT(*) FROM individual_sessions WHERE recurring_session_id = rs.id) AS existing_sessions_count
FROM recurring_sessions rs
INNER JOIN payment_requests pr ON pr.recurring_session_id = rs.id
WHERE pr.status = 'paid'
AND (SELECT COUNT(*) FROM individual_sessions WHERE recurring_session_id = rs.id) = 0
ORDER BY rs.created_at DESC;

-- Step 2: Generate individual sessions
DO $$
DECLARE
    rs_record RECORD;
    session_date DATE;
    session_time TEXT;
    time_str TEXT;
    days_array TEXT[];
    times_json JSONB;
    first_day TEXT;
    day_index INTEGER;
    current_dow INTEGER;
    days_offset INTEGER;
    week_start DATE;
    session_date_calc DATE;
    hour INTEGER;
    minute INTEGER;
    minute_str TEXT;
    is_pm BOOLEAN;
    hour24 INTEGER;
    time_formatted TEXT;
    date_formatted TEXT;
    weeks_ahead INTEGER := 8;
    week INTEGER;
    day TEXT;
    sessions_created INTEGER := 0;
    learner_id_val UUID;
    parent_id_val UUID;
BEGIN
    FOR rs_record IN 
        SELECT 
            rs.id,
            rs.start_date,
            rs.days,
            rs.times,
            rs.frequency,
            rs.location,
            rs.address,
            rs.learner_id,
            rs.tutor_id,
            rs.learner_type,
            rs.subject
        FROM recurring_sessions rs
        INNER JOIN payment_requests pr ON pr.recurring_session_id = rs.id
        WHERE pr.status = 'paid'
        AND (SELECT COUNT(*) FROM individual_sessions WHERE recurring_session_id = rs.id) = 0
    LOOP
        RAISE NOTICE 'Processing recurring session: %', rs_record.id;
        
        days_array := rs_record.days;
        times_json := rs_record.times;
        
        -- Set learner_id and parent_id based on learner_type
        IF rs_record.learner_type = 'learner' THEN
            learner_id_val := rs_record.learner_id;
            parent_id_val := NULL;
        ELSE
            learner_id_val := NULL;
            parent_id_val := rs_record.learner_id;
        END IF;
        
        -- Calculate start date (use recurring session start_date or today, whichever is later)
        session_date := GREATEST(rs_record.start_date::DATE, CURRENT_DATE);
        
        -- Generate sessions for each week
        FOR week IN 0..(weeks_ahead - 1) LOOP
            week_start := session_date + (week * 7 || ' days')::INTERVAL;
            
            -- For each day in the schedule
            FOREACH day IN ARRAY days_array LOOP
                -- Get time for this day
                time_str := times_json->>day;
                
                IF time_str IS NULL OR time_str = '' THEN
                    CONTINUE;
                END IF;
                
                -- Map day name to day of week (Monday = 1, Sunday = 7)
                CASE day
                    WHEN 'Monday' THEN day_index := 1;
                    WHEN 'Tuesday' THEN day_index := 2;
                    WHEN 'Wednesday' THEN day_index := 3;
                    WHEN 'Thursday' THEN day_index := 4;
                    WHEN 'Friday' THEN day_index := 5;
                    WHEN 'Saturday' THEN day_index := 6;
                    WHEN 'Sunday' THEN day_index := 7;
                    ELSE day_index := 1;
                END CASE;
                
                -- Calculate date for this day in this week
                current_dow := EXTRACT(DOW FROM week_start)::INTEGER;
                IF current_dow = 0 THEN
                    current_dow := 7; -- Convert Sunday from 0 to 7
                END IF;
                
                days_offset := (day_index - current_dow) % 7;
                IF days_offset < 0 THEN
                    days_offset := days_offset + 7;
                END IF;
                
                session_date_calc := week_start + (days_offset || ' days')::INTERVAL;
                
                -- Skip if before today
                IF session_date_calc < CURRENT_DATE THEN
                    CONTINUE;
                END IF;
                
                -- Parse time (e.g., "9:00 AM" or "2:30 PM")
                time_str := REPLACE(time_str, ' ', '');
                hour := (regexp_match(time_str, '^(\d+)'))[1]::INTEGER;
                minute_str := COALESCE((regexp_match(time_str, ':(\d+)'))[1], '0');
                minute := minute_str::INTEGER;
                is_pm := UPPER(time_str) LIKE '%PM%';
                
                -- Convert to 24-hour format
                IF is_pm AND hour != 12 THEN
                    hour24 := hour + 12;
                ELSIF NOT is_pm AND hour = 12 THEN
                    hour24 := 0;
                ELSE
                    hour24 := hour;
                END IF;
                
                time_formatted := LPAD(hour24::TEXT, 2, '0') || ':' || LPAD(minute::TEXT, 2, '0') || ':00';
                date_formatted := session_date_calc::TEXT;
                
                -- Check if session already exists
                IF EXISTS (
                    SELECT 1 FROM individual_sessions 
                    WHERE recurring_session_id = rs_record.id
                    AND scheduled_date = date_formatted::DATE
                    AND scheduled_time = time_formatted
                ) THEN
                    CONTINUE;
                END IF;
                
                -- Insert individual session
                INSERT INTO individual_sessions (
                    recurring_session_id,
                    tutor_id,
                    learner_id,
                    parent_id,
                    subject,
                    scheduled_date,
                    scheduled_time,
                    duration_minutes,
                    location,
                    address,
                    status,
                    created_at
                ) VALUES (
                    rs_record.id,
                    rs_record.tutor_id,
                    learner_id_val,
                    parent_id_val,
                    COALESCE(rs_record.subject, 'Tutoring Session'),
                    date_formatted::DATE,
                    time_formatted,
                    60, -- Default duration
                    rs_record.location,
                    CASE WHEN rs_record.location = 'onsite' THEN rs_record.address ELSE NULL END,
                    'scheduled',
                    NOW()
                );
                
                sessions_created := sessions_created + 1;
            END LOOP;
        END LOOP;
        
        RAISE NOTICE '✅ Created % individual sessions for recurring session %', sessions_created, rs_record.id;
    END LOOP;
    
    RAISE NOTICE '✅ Completed generating individual sessions';
END $$;

-- Step 3: Verify what was created
SELECT 
    'Generated individual sessions' AS status,
    rs.id AS recurring_session_id,
    COUNT(is_sessions.id) AS individual_sessions_count,
    MIN(is_sessions.scheduled_date) AS first_session_date,
    MAX(is_sessions.scheduled_date) AS last_session_date
FROM recurring_sessions rs
INNER JOIN payment_requests pr ON pr.recurring_session_id = rs.id
LEFT JOIN individual_sessions is_sessions ON is_sessions.recurring_session_id = rs.id
WHERE pr.status = 'paid'
AND is_sessions.created_at > NOW() - INTERVAL '5 minutes'
GROUP BY rs.id
ORDER BY rs.created_at DESC;

-- Step 4: Show sample sessions
SELECT 
    'Sample individual sessions' AS info,
    is_sessions.id,
    is_sessions.recurring_session_id,
    is_sessions.scheduled_date,
    is_sessions.scheduled_time,
    is_sessions.status,
    is_sessions.location
FROM individual_sessions is_sessions
INNER JOIN recurring_sessions rs ON rs.id = is_sessions.recurring_session_id
INNER JOIN payment_requests pr ON pr.recurring_session_id = rs.id
WHERE pr.status = 'paid'
AND is_sessions.created_at > NOW() - INTERVAL '5 minutes'
ORDER BY is_sessions.scheduled_date, is_sessions.scheduled_time
LIMIT 10;

SELECT '✅ Script completed. Individual sessions have been generated!' AS status;
SELECT '💡 TIP: Try clicking "View Session" in the app now - it should work!' AS tip;

