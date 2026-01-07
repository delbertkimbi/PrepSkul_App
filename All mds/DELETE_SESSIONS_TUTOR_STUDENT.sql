-- ======================================================
-- DELETE APPROVED SESSIONS BETWEEN TUTOR AND STUDENT
-- Tutor: leke brian bechem (bechembrian@gmail.com)
-- Student: brian student (brianleke9@gmail.com)
-- ======================================================

-- STEP 0: DIAGNOSTIC - Check what users exist (run this first to verify emails)
SELECT 
  'Diagnostic: Users with similar emails' as check_type,
  id,
  email,
  full_name,
  user_type,
  created_at
FROM public.profiles
WHERE email ILIKE '%bechem%' 
   OR email ILIKE '%brian%'
   OR full_name ILIKE '%brian%'
   OR full_name ILIKE '%leke%'
ORDER BY email;

-- STEP 1: Find the tutor and student IDs
DO $$
DECLARE
  v_tutor_id UUID;
  v_student_id UUID;
  deleted_individual_sessions INTEGER := 0;
  deleted_recurring_sessions INTEGER := 0;
  updated_booking_requests INTEGER := 0;
BEGIN
  -- Get tutor ID - try exact email first, then partial match
  SELECT id INTO v_tutor_id
  FROM public.profiles
  WHERE email = 'bechembrian@gmail.com'
  LIMIT 1;
  
  -- If not found, try partial email match
  IF v_tutor_id IS NULL THEN
    SELECT id INTO v_tutor_id
    FROM public.profiles
    WHERE email ILIKE '%bechem%'
       OR email ILIKE '%brian%'
       OR (full_name ILIKE '%leke%' AND full_name ILIKE '%brian%' AND full_name ILIKE '%bechem%')
    LIMIT 1;
  END IF;
  
  -- Get student ID - try exact email first, then partial match
  SELECT id INTO v_student_id
  FROM public.profiles
  WHERE email = 'brianleke9@gmail.com'
  LIMIT 1;
  
  -- If not found, try partial email match
  IF v_student_id IS NULL THEN
    SELECT id INTO v_student_id
    FROM public.profiles
    WHERE email ILIKE '%brianleke%'
       OR email ILIKE '%brian%leke%'
       OR (full_name ILIKE '%brian%' AND email ILIKE '%brian%')
    LIMIT 1;
  END IF;
  
  -- Verify we found both - show helpful error if not found
  IF v_tutor_id IS NULL THEN
    RAISE EXCEPTION 'Tutor not found. Please check the diagnostic query above for available users. Looking for email: bechembrian@gmail.com or name containing: leke brian bechem';
  END IF;
  
  IF v_student_id IS NULL THEN
    RAISE EXCEPTION 'Student not found. Please check the diagnostic query above for available users. Looking for email: brianleke9@gmail.com or name containing: brian student';
  END IF;
  
  RAISE NOTICE '========================================';
  RAISE NOTICE 'FOUND TUTOR AND STUDENT';
  RAISE NOTICE '========================================';
  RAISE NOTICE 'Tutor ID: %', v_tutor_id;
  RAISE NOTICE 'Student ID: %', v_student_id;
  RAISE NOTICE '';
  
  -- STEP 2: Delete individual sessions first (due to foreign key constraints)
  -- Note: individual_sessions uses learner_id, not student_id
  RAISE NOTICE 'Deleting individual sessions...';
  WITH deleted AS (
    DELETE FROM public.individual_sessions
    WHERE public.individual_sessions.tutor_id = v_tutor_id
      AND (public.individual_sessions.learner_id = v_student_id 
           OR public.individual_sessions.parent_id = v_student_id)
    RETURNING id
  )
  SELECT COUNT(*) INTO deleted_individual_sessions FROM deleted;
  
  RAISE NOTICE 'Deleted % individual sessions', deleted_individual_sessions;
  
  -- STEP 3: Delete recurring sessions
  -- Note: recurring_sessions uses student_id
  RAISE NOTICE 'Deleting recurring sessions...';
  WITH deleted AS (
    DELETE FROM public.recurring_sessions
    WHERE public.recurring_sessions.tutor_id = v_tutor_id
      AND public.recurring_sessions.student_id = v_student_id
    RETURNING id
  )
  SELECT COUNT(*) INTO deleted_recurring_sessions FROM deleted;
  
  RAISE NOTICE 'Deleted % recurring sessions', deleted_recurring_sessions;
  
  -- STEP 4: Update booking requests to 'cancelled' (safer than deleting)
  -- Or delete them if you prefer - uncomment the DELETE block below
  RAISE NOTICE 'Updating booking requests...';
  
  -- Option A: Update status to cancelled (preserves history)
  WITH updated AS (
    UPDATE public.booking_requests
    SET status = 'cancelled',
        updated_at = NOW()
    WHERE public.booking_requests.tutor_id = v_tutor_id
      AND public.booking_requests.student_id = v_student_id
      AND public.booking_requests.status = 'approved'
    RETURNING id
  )
  SELECT COUNT(*) INTO updated_booking_requests FROM updated;
  
  RAISE NOTICE 'Updated % booking requests to cancelled', updated_booking_requests;
  
  -- Option B: Delete booking requests (uncomment if you want to delete instead of cancel)
  /*
  WITH deleted AS (
    DELETE FROM public.booking_requests
    WHERE tutor_id = tutor_id
      AND student_id = student_id
      AND status = 'approved'
    RETURNING id
  )
  SELECT COUNT(*) INTO updated_booking_requests FROM deleted;
  RAISE NOTICE 'Deleted % booking requests', updated_booking_requests;
  */
  
  -- STEP 5: Summary
  RAISE NOTICE '';
  RAISE NOTICE '========================================';
  RAISE NOTICE 'DELETION SUMMARY';
  RAISE NOTICE '========================================';
  RAISE NOTICE 'Individual sessions deleted: %', deleted_individual_sessions;
  RAISE NOTICE 'Recurring sessions deleted: %', deleted_recurring_sessions;
  RAISE NOTICE 'Booking requests updated: %', updated_booking_requests;
  RAISE NOTICE '========================================';
  
END $$;

-- STEP 6: Verify deletion (optional - run separately to check)
-- Uncomment to verify:
/*
SELECT 
  'Individual Sessions' as table_name,
  COUNT(*) as remaining_count
FROM public.individual_sessions
WHERE tutor_id = (SELECT id FROM public.profiles WHERE email = 'bechembrian@gmail.com' LIMIT 1)
  AND learner_id = (SELECT id FROM public.profiles WHERE email = 'brianleke9@gmail.com' LIMIT 1)

UNION ALL

SELECT 
  'Recurring Sessions' as table_name,
  COUNT(*) as remaining_count
FROM public.recurring_sessions
WHERE tutor_id = (SELECT id FROM public.profiles WHERE email = 'bechembrian@gmail.com' LIMIT 1)
  AND learner_id = (SELECT id FROM public.profiles WHERE email = 'brianleke9@gmail.com' LIMIT 1)

UNION ALL

SELECT 
  'Booking Requests (Approved)' as table_name,
  COUNT(*) as remaining_count
FROM public.booking_requests
WHERE tutor_id = (SELECT id FROM public.profiles WHERE email = 'bechembrian@gmail.com' LIMIT 1)
  AND student_id = (SELECT id FROM public.profiles WHERE email = 'brianleke9@gmail.com' LIMIT 1)
  AND status = 'approved';
*/

