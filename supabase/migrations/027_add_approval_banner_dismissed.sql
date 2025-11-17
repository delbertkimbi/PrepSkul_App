-- Migration: Add approval_banner_dismissed to tutor_profiles
-- This allows the approval banner dismissal to persist across devices

ALTER TABLE public.tutor_profiles
ADD COLUMN IF NOT EXISTS approval_banner_dismissed BOOLEAN DEFAULT FALSE;

COMMENT ON COLUMN public.tutor_profiles.approval_banner_dismissed IS 'Whether the tutor has dismissed the approval banner. Persists across devices.';

-- Create index for faster queries
CREATE INDEX IF NOT EXISTS idx_tutor_profiles_approval_banner_dismissed 
ON public.tutor_profiles(user_id) 
WHERE approval_banner_dismissed = true;

