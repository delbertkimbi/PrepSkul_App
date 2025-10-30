-- ======================================================
-- FIX: Row-Level Security Policies for parent_profiles
-- Run this in Supabase SQL Editor NOW
-- ======================================================

-- Enable RLS on parent_profiles (if not already enabled)
ALTER TABLE public.parent_profiles ENABLE ROW LEVEL SECURITY;

-- Drop existing policies if they exist (to avoid conflicts)
DROP POLICY IF EXISTS "Users can view own parent profile" ON public.parent_profiles;
DROP POLICY IF EXISTS "Users can insert own parent profile" ON public.parent_profiles;
DROP POLICY IF EXISTS "Users can update own parent profile" ON public.parent_profiles;

-- Allow users to SELECT their own parent profile
CREATE POLICY "Users can view own parent profile"
  ON public.parent_profiles
  FOR SELECT
  USING (auth.uid() = user_id);

-- Allow users to INSERT their own parent profile
CREATE POLICY "Users can insert own parent profile"
  ON public.parent_profiles
  FOR INSERT
  WITH CHECK (auth.uid() = user_id);

-- Allow users to UPDATE their own parent profile
CREATE POLICY "Users can update own parent profile"
  ON public.parent_profiles
  FOR UPDATE
  USING (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);

-- Verify policies were created
SELECT 
  schemaname, 
  tablename, 
  policyname, 
  cmd AS operation,
  qual AS using_expression,
  with_check AS with_check_expression
FROM pg_policies 
WHERE tablename = 'parent_profiles'
ORDER BY policyname;

-- ======================================================
-- DONE! You should see 3 policies listed
-- ======================================================

