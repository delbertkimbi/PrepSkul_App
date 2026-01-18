-- ========================================
-- ADD SUBJECT COLUMN TO RECURRING_SESSIONS
-- ========================================
-- This migration adds the missing 'subject' column to the recurring_sessions table
-- The column is nullable TEXT to store optional subject/summary (e.g. "Mathematics", "Physics")

-- Check if column exists, and add it if it doesn't
DO $$
BEGIN
    -- Check if the subject column exists
    IF NOT EXISTS (
        SELECT 1 
        FROM information_schema.columns 
        WHERE table_schema = 'public' 
        AND table_name = 'recurring_sessions' 
        AND column_name = 'subject'
    ) THEN
        -- Add the subject column
        ALTER TABLE public.recurring_sessions 
        ADD COLUMN subject TEXT;
        
        -- Add a comment to document the column
        COMMENT ON COLUMN public.recurring_sessions.subject IS 'Optional subject/summary (e.g. "Mathematics", "Physics") for display';
        
        RAISE NOTICE '✅ Added subject column to recurring_sessions table';
    ELSE
        RAISE NOTICE 'ℹ️ Subject column already exists in recurring_sessions table';
    END IF;
END $$;

-- Verify the column was added
SELECT 
    column_name, 
    data_type, 
    is_nullable,
    column_default
FROM information_schema.columns 
WHERE table_schema = 'public' 
AND table_name = 'recurring_sessions' 
AND column_name = 'subject';

-- Success message
SELECT '✅ Migration completed: subject column check/add for recurring_sessions' AS status;

