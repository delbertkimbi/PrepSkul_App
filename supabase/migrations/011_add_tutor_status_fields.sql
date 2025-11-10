-- ======================================================
-- MIGRATION 011: Add Tutor Status Fields
-- Adds missing status value and improvement_requests field
-- ======================================================

-- 1. Add 'needs_improvement' to status check constraint
-- First, drop the existing constraint if it exists
DO $$ 
BEGIN
  -- Drop old constraint if it exists
  IF EXISTS (
    SELECT 1 FROM pg_constraint 
    WHERE conname = 'tutor_profiles_status_check'
  ) THEN
    ALTER TABLE public.tutor_profiles 
    DROP CONSTRAINT tutor_profiles_status_check;
  END IF;
END $$;

-- Add new constraint with 'needs_improvement' status
ALTER TABLE public.tutor_profiles 
ADD CONSTRAINT tutor_profiles_status_check 
CHECK (status IN ('pending', 'approved', 'rejected', 'needs_improvement', 'suspended'));

-- 2. Add improvement_requests field (stores array of improvement areas)
ALTER TABLE public.tutor_profiles 
ADD COLUMN IF NOT EXISTS improvement_requests TEXT[];

-- 3. Add column comment for documentation
COMMENT ON COLUMN public.tutor_profiles.improvement_requests IS 'Array of improvement areas requested by admin (e.g., ["Certificate quality", "Profile photo", "Bio clarity"])';
COMMENT ON COLUMN public.tutor_profiles.status IS 'Approval status: pending, approved, rejected, needs_improvement, suspended';

-- 4. Create index for faster queries on status
CREATE INDEX IF NOT EXISTS idx_tutor_profiles_status ON public.tutor_profiles(status);

