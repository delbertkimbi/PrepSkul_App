-- ============================================
-- ADD PENDING UPDATE FIELD FOR TUTOR PROFILES
-- Allows approved tutors to remain visible while changes await admin approval
-- ============================================

DO $$
BEGIN
  -- Add has_pending_update column if it doesn't exist
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_schema = 'public' 
    AND table_name = 'tutor_profiles' 
    AND column_name = 'has_pending_update'
  ) THEN
    ALTER TABLE public.tutor_profiles 
    ADD COLUMN has_pending_update BOOLEAN DEFAULT FALSE;
    
    COMMENT ON COLUMN public.tutor_profiles.has_pending_update IS 
      'TRUE when an approved tutor makes profile changes that need admin re-approval. Tutor remains visible with current approved data until admin approves the update.';
    
    RAISE NOTICE '✅ Added has_pending_update column to tutor_profiles';
  ELSE
    RAISE NOTICE 'ℹ️ has_pending_update column already exists';
  END IF;

  -- Add index for faster queries
  CREATE INDEX IF NOT EXISTS idx_tutor_profiles_pending_update 
  ON public.tutor_profiles(has_pending_update) 
  WHERE has_pending_update = TRUE;
  
  RAISE NOTICE '✅ Created index on has_pending_update';

  -- Update existing records: if status is 'pending' but tutor was previously approved,
  -- we can't determine this from current data, so we'll leave it as is
  -- New logic will handle this going forward

END $$;

-- Verification query
SELECT 
  'Verification' as check_type,
  COUNT(*) FILTER (WHERE has_pending_update = TRUE) as tutors_with_pending_updates,
  COUNT(*) FILTER (WHERE status = 'approved' AND has_pending_update = TRUE) as approved_tutors_with_updates,
  COUNT(*) FILTER (WHERE status = 'approved') as total_approved_tutors
FROM public.tutor_profiles;

