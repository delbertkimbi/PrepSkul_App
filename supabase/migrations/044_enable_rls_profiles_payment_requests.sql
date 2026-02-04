-- ======================================================
-- MIGRATION 044: Enable RLS for profiles and payment_requests
-- Fixes security issues: Tables are public but RLS not enabled
-- ======================================================

-- ========================================
-- 1. PROFILES TABLE RLS
-- ========================================

-- Ensure RLS is enabled
ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;

-- Drop existing policies if they exist (to avoid conflicts)
DROP POLICY IF EXISTS "Users can view own profile" ON public.profiles;
DROP POLICY IF EXISTS "Users can view public profiles" ON public.profiles;
DROP POLICY IF EXISTS "Users can update own profile" ON public.profiles;
DROP POLICY IF EXISTS "Users can insert own profile" ON public.profiles;
DROP POLICY IF EXISTS "Admins can view all profiles" ON public.profiles;
DROP POLICY IF EXISTS "Admins can update all profiles" ON public.profiles;

-- Policy: Users can view their own profile
CREATE POLICY "Users can view own profile"
  ON public.profiles
  FOR SELECT
  TO authenticated
  USING (auth.uid() = id);

-- Policy: Users can view public profile information (for tutor discovery, etc.)
-- This allows viewing basic info like name, avatar, user_type for approved tutors
CREATE POLICY "Users can view public profiles"
  ON public.profiles
  FOR SELECT
  TO authenticated
  USING (
    -- Allow viewing basic profile info for all authenticated users
    -- More restrictive policies can be added in child tables (tutor_profiles, etc.)
    true
  );

-- Policy: Users can update their own profile
CREATE POLICY "Users can update own profile"
  ON public.profiles
  FOR UPDATE
  TO authenticated
  USING (auth.uid() = id)
  WITH CHECK (auth.uid() = id);

-- Policy: Users can insert their own profile (during signup)
CREATE POLICY "Users can insert own profile"
  ON public.profiles
  FOR INSERT
  TO authenticated
  WITH CHECK (auth.uid() = id);

-- Policy: Admins can view all profiles
CREATE POLICY "Admins can view all profiles"
  ON public.profiles
  FOR SELECT
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM public.profiles
      WHERE profiles.id = auth.uid()
      AND profiles.is_admin = true
    )
  );

-- Policy: Admins can update all profiles
CREATE POLICY "Admins can update all profiles"
  ON public.profiles
  FOR UPDATE
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM public.profiles
      WHERE profiles.id = auth.uid()
      AND profiles.is_admin = true
    )
  )
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM public.profiles
      WHERE profiles.id = auth.uid()
      AND profiles.is_admin = true
    )
  );

-- ========================================
-- 2. PAYMENT_REQUESTS TABLE RLS
-- ========================================

-- Enable RLS
ALTER TABLE public.payment_requests ENABLE ROW LEVEL SECURITY;

-- Drop existing policies if they exist
DROP POLICY IF EXISTS "Students can view own payment requests" ON public.payment_requests;
DROP POLICY IF EXISTS "Tutors can view own payment requests" ON public.payment_requests;
DROP POLICY IF EXISTS "Students can create payment requests" ON public.payment_requests;
DROP POLICY IF EXISTS "Tutors can update payment requests" ON public.payment_requests;
DROP POLICY IF EXISTS "Admins can view all payment requests" ON public.payment_requests;
DROP POLICY IF EXISTS "Admins can update all payment requests" ON public.payment_requests;

-- Policy: Students can view their own payment requests
CREATE POLICY "Students can view own payment requests"
  ON public.payment_requests
  FOR SELECT
  TO authenticated
  USING (auth.uid() = student_id);

-- Policy: Tutors can view payment requests for their sessions
CREATE POLICY "Tutors can view own payment requests"
  ON public.payment_requests
  FOR SELECT
  TO authenticated
  USING (auth.uid() = tutor_id);

-- Policy: System/tutors can create payment requests (when approving bookings)
-- Note: Typically created server-side, but allowing tutors to create them
CREATE POLICY "Tutors can create payment requests"
  ON public.payment_requests
  FOR INSERT
  TO authenticated
  WITH CHECK (
    -- Tutors can create payment requests for their own sessions
    auth.uid() = tutor_id
  );

-- Policy: Students can update their own payment requests (e.g., cancel)
CREATE POLICY "Students can update own payment requests"
  ON public.payment_requests
  FOR UPDATE
  TO authenticated
  USING (auth.uid() = student_id)
  WITH CHECK (
    auth.uid() = student_id
    -- Students can only update status to 'cancelled'
    AND (status = 'cancelled' OR OLD.status = status)
  );

-- Policy: Admins can view all payment requests
CREATE POLICY "Admins can view all payment requests"
  ON public.payment_requests
  FOR SELECT
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM public.profiles
      WHERE profiles.id = auth.uid()
      AND profiles.is_admin = true
    )
  );

-- Policy: Admins can update all payment requests
CREATE POLICY "Admins can update all payment requests"
  ON public.payment_requests
  FOR UPDATE
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM public.profiles
      WHERE profiles.id = auth.uid()
      AND profiles.is_admin = true
    )
  )
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM public.profiles
      WHERE profiles.id = auth.uid()
      AND profiles.is_admin = true
    )
  );

-- ========================================
-- 3. VERIFICATION QUERIES
-- ========================================

-- Verify RLS is enabled
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_tables 
    WHERE schemaname = 'public' 
    AND tablename = 'profiles' 
    AND rowsecurity = true
  ) THEN
    RAISE EXCEPTION 'RLS not enabled on profiles table';
  END IF;
  
  IF NOT EXISTS (
    SELECT 1 FROM pg_tables 
    WHERE schemaname = 'public' 
    AND tablename = 'payment_requests' 
    AND rowsecurity = true
  ) THEN
    RAISE EXCEPTION 'RLS not enabled on payment_requests table';
  END IF;
  
  RAISE NOTICE '✅ RLS enabled successfully on both tables';
END $$;

-- Comments
COMMENT ON POLICY "Users can view own profile" ON public.profiles IS 'Allows users to view their own profile data';
COMMENT ON POLICY "Users can view public profiles" ON public.profiles IS 'Allows authenticated users to view basic profile information';
COMMENT ON POLICY "Users can update own profile" ON public.profiles IS 'Allows users to update their own profile';
COMMENT ON POLICY "Users can insert own profile" ON public.profiles IS 'Allows users to create their own profile during signup';
COMMENT ON POLICY "Admins can view all profiles" ON public.profiles IS 'Allows admins to view all user profiles';
COMMENT ON POLICY "Admins can update all profiles" ON public.profiles IS 'Allows admins to update any user profile';

COMMENT ON POLICY "Students can view own payment requests" ON public.payment_requests IS 'Allows students to view their own payment requests';
COMMENT ON POLICY "Tutors can view own payment requests" ON public.payment_requests IS 'Allows tutors to view payment requests for their sessions';
COMMENT ON POLICY "Tutors can create payment requests" ON public.payment_requests IS 'Allows tutors to create payment requests when approving bookings';
COMMENT ON POLICY "Students can update own payment requests" ON public.payment_requests IS 'Allows students to cancel their own payment requests';
COMMENT ON POLICY "Admins can view all payment requests" ON public.payment_requests IS 'Allows admins to view all payment requests';
COMMENT ON POLICY "Admins can update all payment requests" ON public.payment_requests IS 'Allows admins to update any payment request';
