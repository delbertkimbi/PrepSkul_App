-- ========================================
-- VERIFY AND FIX RECURRING_SESSIONS SCHEMA
-- ========================================
-- This script verifies all required columns exist in recurring_sessions table
-- and adds any missing columns based on the application code requirements

-- First, let's see what columns currently exist
SELECT 
    column_name, 
    data_type, 
    is_nullable,
    column_default
FROM information_schema.columns 
WHERE table_schema = 'public' 
AND table_name = 'recurring_sessions'
ORDER BY ordinal_position;

-- Now add any missing columns
DO $$
BEGIN
    -- Add subject column if missing
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_schema = 'public' 
        AND table_name = 'recurring_sessions' 
        AND column_name = 'subject'
    ) THEN
        ALTER TABLE public.recurring_sessions ADD COLUMN subject TEXT;
        RAISE NOTICE '✅ Added subject column';
    END IF;

    -- Add location_description column if missing (used in code)
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_schema = 'public' 
        AND table_name = 'recurring_sessions' 
        AND column_name = 'location_description'
    ) THEN
        ALTER TABLE public.recurring_sessions ADD COLUMN location_description TEXT;
        RAISE NOTICE '✅ Added location_description column';
    END IF;

    -- Verify learner_id exists (should be renamed from student_id)
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_schema = 'public' 
        AND table_name = 'recurring_sessions' 
        AND column_name = 'learner_id'
    ) THEN
        -- Check if student_id exists and rename it
        IF EXISTS (
            SELECT 1 FROM information_schema.columns 
            WHERE table_schema = 'public' 
            AND table_name = 'recurring_sessions' 
            AND column_name = 'student_id'
        ) THEN
            ALTER TABLE public.recurring_sessions RENAME COLUMN student_id TO learner_id;
            RAISE NOTICE '✅ Renamed student_id to learner_id';
        ELSE
            RAISE NOTICE '⚠️ Neither learner_id nor student_id found - this is a problem!';
        END IF;
    END IF;

    -- Verify learner_name exists (should be renamed from student_name)
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_schema = 'public' 
        AND table_name = 'recurring_sessions' 
        AND column_name = 'learner_name'
    ) THEN
        IF EXISTS (
            SELECT 1 FROM information_schema.columns 
            WHERE table_schema = 'public' 
            AND table_name = 'recurring_sessions' 
            AND column_name = 'student_name'
        ) THEN
            ALTER TABLE public.recurring_sessions RENAME COLUMN student_name TO learner_name;
            RAISE NOTICE '✅ Renamed student_name to learner_name';
        END IF;
    END IF;

    -- Verify learner_avatar_url exists
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_schema = 'public' 
        AND table_name = 'recurring_sessions' 
        AND column_name = 'learner_avatar_url'
    ) THEN
        IF EXISTS (
            SELECT 1 FROM information_schema.columns 
            WHERE table_schema = 'public' 
            AND table_name = 'recurring_sessions' 
            AND column_name = 'student_avatar_url'
        ) THEN
            ALTER TABLE public.recurring_sessions RENAME COLUMN student_avatar_url TO learner_avatar_url;
            RAISE NOTICE '✅ Renamed student_avatar_url to learner_avatar_url';
        END IF;
    END IF;

    -- Verify learner_type exists
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_schema = 'public' 
        AND table_name = 'recurring_sessions' 
        AND column_name = 'learner_type'
    ) THEN
        IF EXISTS (
            SELECT 1 FROM information_schema.columns 
            WHERE table_schema = 'public' 
            AND table_name = 'recurring_sessions' 
            AND column_name = 'student_type'
        ) THEN
            ALTER TABLE public.recurring_sessions RENAME COLUMN student_type TO learner_type;
            RAISE NOTICE '✅ Renamed student_type to learner_type';
        END IF;
    END IF;

    RAISE NOTICE '✅ Schema verification and fixes completed';
END $$;

-- Show final column list
SELECT 
    'Final Schema' AS status,
    column_name, 
    data_type, 
    is_nullable
FROM information_schema.columns 
WHERE table_schema = 'public' 
AND table_name = 'recurring_sessions'
ORDER BY ordinal_position;

-- Success message
SELECT '✅ Schema verification completed' AS status;

