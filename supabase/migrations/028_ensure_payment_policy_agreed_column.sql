-- Migration: Ensure payment_policy_agreed column exists in parent_profiles
-- This fixes the error: "Could not find the 'payment_policy_agreed' column of 'parent_profiles'"
-- Migration 025 should have added this, but this ensures it exists

-- Add payment_policy_agreed column to parent_profiles if it doesn't exist
ALTER TABLE public.parent_profiles 
ADD COLUMN IF NOT EXISTS payment_policy_agreed BOOLEAN DEFAULT FALSE;

-- Add comment for documentation
COMMENT ON COLUMN public.parent_profiles.payment_policy_agreed IS 'Whether parent agreed to payment policy during survey';

-- Verify the column exists (this will fail if there's a real issue)
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 
    FROM information_schema.columns 
    WHERE table_schema = 'public' 
      AND table_name = 'parent_profiles' 
      AND column_name = 'payment_policy_agreed'
  ) THEN
    RAISE EXCEPTION 'Column payment_policy_agreed was not created in parent_profiles';
  END IF;
END $$;

