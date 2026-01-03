-- ============================================
-- FIX session_payments FOREIGN KEY RELATIONSHIP
-- This adds the missing FK constraint from session_payments.session_id to individual_sessions.id
-- ============================================

DO $$
BEGIN
  -- Check if individual_sessions table exists
  IF EXISTS (
    SELECT 1 FROM information_schema.tables 
    WHERE table_schema = 'public' 
    AND table_name = 'individual_sessions'
  ) THEN
    -- Check if session_payments table exists
    IF EXISTS (
      SELECT 1 FROM information_schema.tables 
      WHERE table_schema = 'public' 
      AND table_name = 'session_payments'
    ) THEN
      -- Check if FK constraint already exists
      IF NOT EXISTS (
        SELECT 1 FROM information_schema.table_constraints 
        WHERE constraint_schema = 'public' 
        AND constraint_name = 'session_payments_session_id_fkey'
      ) THEN
        -- Add foreign key constraint
        ALTER TABLE public.session_payments
        ADD CONSTRAINT session_payments_session_id_fkey
        FOREIGN KEY (session_id) 
        REFERENCES public.individual_sessions(id) 
        ON DELETE SET NULL;
        
        RAISE NOTICE '✅ Added foreign key constraint: session_payments.session_id -> individual_sessions.id';
      ELSE
        RAISE NOTICE 'ℹ️ Foreign key constraint already exists';
      END IF;
    ELSE
      RAISE NOTICE '⚠️ session_payments table does not exist. Run CREATE_TUTOR_EARNINGS_TABLE.sql first.';
    END IF;
  ELSE
    RAISE NOTICE '⚠️ individual_sessions table does not exist. Cannot add foreign key.';
  END IF;
END $$;

-- Verify the constraint was added
SELECT 
  tc.constraint_name, 
  tc.table_name, 
  kcu.column_name,
  ccu.table_name AS foreign_table_name,
  ccu.column_name AS foreign_column_name 
FROM information_schema.table_constraints AS tc 
JOIN information_schema.key_column_usage AS kcu
  ON tc.constraint_name = kcu.constraint_name
  AND tc.table_schema = kcu.table_schema
JOIN information_schema.constraint_column_usage AS ccu
  ON ccu.constraint_name = tc.constraint_name
  AND ccu.table_schema = tc.table_schema
WHERE tc.constraint_type = 'FOREIGN KEY' 
  AND tc.table_name = 'session_payments'
  AND kcu.column_name = 'session_id';

