-- ======================================================
-- CHECK AND FIX BOOKING_REQUESTS RLS POLICIES
-- Ensures students/parents can view their booking requests
-- ======================================================

-- STEP 1: Check if booking_requests table exists and has RLS enabled
SELECT 
  'Table Check' as check_type,
  tablename,
  rowsecurity as rls_enabled
FROM pg_tables
WHERE schemaname = 'public'
  AND tablename = 'booking_requests';

-- STEP 2: Check current RLS policies on booking_requests
SELECT 
  'Current RLS Policies' as check_type,
  policyname,
  cmd as command,
  qual as using_expression,
  with_check as with_check_expression
FROM pg_policies
WHERE schemaname = 'public'
  AND tablename = 'booking_requests'
ORDER BY policyname;

-- STEP 3: Check table columns to understand structure
SELECT 
  'Table Columns' as check_type,
  column_name,
  data_type,
  is_nullable
FROM information_schema.columns
WHERE table_schema = 'public'
  AND table_name = 'booking_requests'
ORDER BY ordinal_position;

-- STEP 4: Enable RLS if not already enabled
ALTER TABLE public.booking_requests ENABLE ROW LEVEL SECURITY;

-- STEP 5: Drop ALL existing policies on booking_requests (comprehensive cleanup)
-- This ensures we start fresh and avoid conflicts
DO $$
DECLARE
  policy_name TEXT;
BEGIN
  -- Drop all existing policies on booking_requests
  FOR policy_name IN
    SELECT policyname
    FROM pg_policies
    WHERE schemaname = 'public'
      AND tablename = 'booking_requests'
  LOOP
    EXECUTE format('DROP POLICY IF EXISTS %I ON public.booking_requests', policy_name);
    RAISE NOTICE 'Dropped policy: %', policy_name;
  END LOOP;
  
  RAISE NOTICE '✅ All existing policies dropped';
END $$;

-- STEP 6: Create comprehensive RLS policies for booking_requests

-- SELECT Policy: Students/Parents can view their own requests
-- Tutors can view requests sent to them
CREATE POLICY "Users can view their own booking requests"
  ON public.booking_requests
  FOR SELECT
  TO authenticated
  USING (
    -- Students/parents can view their own requests
    student_id = auth.uid()
    OR
    -- Tutors can view requests sent to them
    tutor_id = auth.uid()
  );

-- INSERT Policy: Students/Parents can create their own requests
CREATE POLICY "Students/Parents can create booking requests"
  ON public.booking_requests
  FOR INSERT
  TO authenticated
  WITH CHECK (
    -- Only allow if the authenticated user is the student
    student_id = auth.uid()
  );

-- UPDATE Policy: Students can cancel, tutors can approve/reject
CREATE POLICY "Users can update booking requests"
  ON public.booking_requests
  FOR UPDATE
  TO authenticated
  USING (
    -- Students can update their own pending requests (to cancel)
    (student_id = auth.uid() AND status = 'pending')
    OR
    -- Tutors can update requests sent to them (to approve/reject)
    (tutor_id = auth.uid() AND status = 'pending')
  )
  WITH CHECK (
    -- Students can only set status to 'cancelled'
    (student_id = auth.uid() AND status = 'cancelled')
    OR
    -- Tutors can set status to 'approved' or 'rejected'
    (tutor_id = auth.uid() AND status IN ('approved', 'rejected'))
  );

-- STEP 7: Verify policies were created
SELECT 
  'Verification' as check_type,
  policyname,
  cmd as command
FROM pg_policies
WHERE schemaname = 'public'
  AND tablename = 'booking_requests'
ORDER BY policyname;

-- STEP 8: Test query (replace with actual user ID if needed)
-- This will show if RLS is working correctly
-- SELECT COUNT(*) as total_requests,
--        COUNT(*) FILTER (WHERE student_id = auth.uid()) as my_requests,
--        COUNT(*) FILTER (WHERE tutor_id = auth.uid()) as tutor_requests
-- FROM public.booking_requests;

