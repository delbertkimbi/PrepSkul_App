-- ============================================
-- FIX TRIAL_SESSIONS STATUS CONSTRAINT
-- Adds 'in_progress' and 'expired' to allowed status values
-- ============================================
-- 
-- ISSUE: The constraint only allows:
--   'pending', 'approved', 'rejected', 'scheduled', 'completed', 'cancelled', 'no_show'
-- 
-- But the code tries to set status to 'in_progress' when starting a session
-- 
-- SOLUTION: Update constraint to include 'in_progress' and 'expired'
-- ============================================

DO $$
BEGIN
  -- Check if constraint exists
  IF EXISTS (
    SELECT 1 FROM pg_constraint 
    WHERE conname = 'trial_sessions_status_check'
  ) THEN
    -- Drop existing constraint
    ALTER TABLE public.trial_sessions 
    DROP CONSTRAINT trial_sessions_status_check;
    
    RAISE NOTICE '✅ Dropped existing trial_sessions_status_check constraint';
  END IF;

  -- Add new constraint with 'in_progress' and 'expired' included
  ALTER TABLE public.trial_sessions 
  ADD CONSTRAINT trial_sessions_status_check 
  CHECK (status IN (
    'pending', 
    'approved', 
    'rejected', 
    'scheduled', 
    'in_progress',  -- Added for when session is actively happening
    'completed', 
    'cancelled', 
    'no_show',
    'expired'  -- Added for expired trial sessions
  ));

  RAISE NOTICE '✅ Added updated trial_sessions_status_check constraint with ''in_progress'' and ''expired''';

END $$;

-- Verify the constraint (outside DO block so it can return results)
SELECT 
  'VERIFICATION' as check_type,
  conname as constraint_name,
  pg_get_constraintdef(oid) as constraint_definition
FROM pg_constraint
WHERE conname = 'trial_sessions_status_check';

-- ============================================
-- DONE!
-- ============================================
-- The constraint now allows:
--   - 'pending': Initial request state
--   - 'approved': Tutor approved the request
--   - 'rejected': Tutor rejected the request
--   - 'scheduled': Session is scheduled (after payment)
--   - 'in_progress': Session is currently happening (NEW)
--   - 'completed': Session finished successfully
--   - 'cancelled': Session was cancelled
--   - 'no_show': Someone didn't show up
--   - 'expired': Request expired (NEW)
-- ============================================

