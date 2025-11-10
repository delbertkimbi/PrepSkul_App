-- ======================================================
-- MIGRATION 018: Add ALL missing columns to tutor_profiles
-- This migration adds all columns that are being saved but don't exist in the database
-- ======================================================

-- Add certificates_urls column (if not already added by migration 017)
ALTER TABLE public.tutor_profiles 
ADD COLUMN IF NOT EXISTS certificates_urls JSONB DEFAULT '[]'::jsonb;

-- Add digital readiness columns
ALTER TABLE public.tutor_profiles 
ADD COLUMN IF NOT EXISTS devices TEXT[],
ADD COLUMN IF NOT EXISTS has_internet BOOLEAN,
ADD COLUMN IF NOT EXISTS teaching_tools TEXT[],
ADD COLUMN IF NOT EXISTS has_materials BOOLEAN,
ADD COLUMN IF NOT EXISTS wants_training BOOLEAN;

-- Add other potentially missing columns from onboarding
ALTER TABLE public.tutor_profiles 
ADD COLUMN IF NOT EXISTS tutoring_availability JSONB,
ADD COLUMN IF NOT EXISTS test_session_availability JSONB,
ADD COLUMN IF NOT EXISTS pricing_factors TEXT[],
ADD COLUMN IF NOT EXISTS personal_statement TEXT,
ADD COLUMN IF NOT EXISTS final_agreements JSONB,
ADD COLUMN IF NOT EXISTS preferred_mode TEXT,
ADD COLUMN IF NOT EXISTS teaching_approaches TEXT[],
ADD COLUMN IF NOT EXISTS preferred_session_type TEXT,
ADD COLUMN IF NOT EXISTS handles_multiple_learners BOOLEAN,
ADD COLUMN IF NOT EXISTS hours_per_week INTEGER,
ADD COLUMN IF NOT EXISTS taught_levels TEXT[],
ADD COLUMN IF NOT EXISTS tutoring_areas TEXT[],
ADD COLUMN IF NOT EXISTS learner_levels TEXT[],
ADD COLUMN IF NOT EXISTS specializations TEXT[],
ADD COLUMN IF NOT EXISTS social_media_links JSONB,
ADD COLUMN IF NOT EXISTS payment_details JSONB,
ADD COLUMN IF NOT EXISTS payment_agreement BOOLEAN,
ADD COLUMN IF NOT EXISTS verification_agreement BOOLEAN;

-- Add missing columns that were causing errors
ALTER TABLE public.tutor_profiles 
ADD COLUMN IF NOT EXISTS expected_rate TEXT,
ADD COLUMN IF NOT EXISTS has_experience BOOLEAN,
ADD COLUMN IF NOT EXISTS has_training BOOLEAN,
ADD COLUMN IF NOT EXISTS id_card_url TEXT,
ADD COLUMN IF NOT EXISTS video_intro TEXT,
ADD COLUMN IF NOT EXISTS video_link TEXT,
ADD COLUMN IF NOT EXISTS has_teaching_experience BOOLEAN,
ADD COLUMN IF NOT EXISTS teaching_duration TEXT,
ADD COLUMN IF NOT EXISTS motivation TEXT,
ADD COLUMN IF NOT EXISTS availability JSONB;

-- Add indexes for frequently queried columns
CREATE INDEX IF NOT EXISTS idx_tutor_profiles_certificates_urls 
ON public.tutor_profiles USING gin (certificates_urls);

CREATE INDEX IF NOT EXISTS idx_tutor_profiles_tutoring_availability 
ON public.tutor_profiles USING gin (tutoring_availability);

CREATE INDEX IF NOT EXISTS idx_tutor_profiles_test_session_availability 
ON public.tutor_profiles USING gin (test_session_availability);

-- Add comments for documentation
COMMENT ON COLUMN public.tutor_profiles.certificates_urls IS 'Array of certificate document URLs uploaded by the tutor';
COMMENT ON COLUMN public.tutor_profiles.devices IS 'Array of devices the tutor has available (e.g., ["Laptop", "Smartphone", "Tablet"])';
COMMENT ON COLUMN public.tutor_profiles.has_internet IS 'Whether the tutor has reliable internet connection';
COMMENT ON COLUMN public.tutor_profiles.teaching_tools IS 'Array of teaching tools/apps the tutor uses';
COMMENT ON COLUMN public.tutor_profiles.has_materials IS 'Whether the tutor has teaching materials';
COMMENT ON COLUMN public.tutor_profiles.wants_training IS 'Whether the tutor wants training from PrepSkul';
COMMENT ON COLUMN public.tutor_profiles.tutoring_availability IS 'JSONB object with tutoring session availability schedule';
COMMENT ON COLUMN public.tutor_profiles.test_session_availability IS 'JSONB object with test session availability schedule';
COMMENT ON COLUMN public.tutor_profiles.pricing_factors IS 'Array of factors that influence pricing';
COMMENT ON COLUMN public.tutor_profiles.personal_statement IS 'Tutor''s personal statement/bio';
COMMENT ON COLUMN public.tutor_profiles.final_agreements IS 'JSONB object with final agreements/confirmations';

