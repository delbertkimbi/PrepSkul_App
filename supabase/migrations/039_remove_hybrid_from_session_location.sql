-- ======================================================
-- MIGRATION 039: Remove 'hybrid' from Session Location
-- Hybrid should only be a teaching mode preference, not a session location type
-- Each session must be either 'online' or 'onsite'
-- ======================================================

-- Update any existing 'hybrid' sessions to 'online' (default)
-- This is safe because hybrid sessions were meant to be flexible anyway
UPDATE public.individual_sessions
SET location = 'online'
WHERE location = 'hybrid';

UPDATE public.recurring_sessions
SET location = 'online'
WHERE location = 'hybrid';

-- Remove 'hybrid' from location constraints
-- Note: location_preference can still be 'hybrid' (it's a preference, not actual location)

-- For recurring_sessions table
ALTER TABLE public.recurring_sessions
DROP CONSTRAINT IF EXISTS recurring_sessions_location_check;

ALTER TABLE public.recurring_sessions
ADD CONSTRAINT recurring_sessions_location_check 
CHECK (location IN ('online', 'onsite'));

-- For session_reschedule_requests table
ALTER TABLE public.session_reschedule_requests
DROP CONSTRAINT IF EXISTS session_reschedule_requests_proposed_location_check;

ALTER TABLE public.session_reschedule_requests
ADD CONSTRAINT session_reschedule_requests_proposed_location_check
CHECK (proposed_location IN ('online', 'onsite'));

-- Add comment explaining the change
COMMENT ON COLUMN public.recurring_sessions.location IS 'Session location: online or onsite. Hybrid is a teaching mode preference only, not a session location.';

