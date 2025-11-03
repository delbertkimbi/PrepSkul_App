-- ======================================================
-- CLEAR ALL TEST REQUESTS
-- Run this in Supabase SQL Editor to start fresh
-- ======================================================

-- Delete all trial sessions
DELETE FROM public.trial_sessions;

-- Delete all booking requests
DELETE FROM public.session_requests;

-- Delete all custom tutor requests
DELETE FROM public.tutor_requests;

-- Delete all recurring sessions (if any)
DELETE FROM public.recurring_sessions WHERE true;

-- Verify everything is cleared
SELECT 
  'trial_sessions' as table_name, 
  COUNT(*) as remaining_rows 
FROM public.trial_sessions
UNION ALL
SELECT 
  'session_requests' as table_name, 
  COUNT(*) as remaining_rows 
FROM public.session_requests
UNION ALL
SELECT 
  'tutor_requests' as table_name, 
  COUNT(*) as remaining_rows 
FROM public.tutor_requests;

-- ======================================================
-- DONE! All test requests cleared. 
-- Now you'll see the clean empty states.
-- ======================================================

