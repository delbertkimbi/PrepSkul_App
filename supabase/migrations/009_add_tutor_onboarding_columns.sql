-- ======================================================
-- MIGRATION 009: Add All Tutor Onboarding Columns
-- Adds all missing columns needed for tutor onboarding form submission
-- ======================================================

-- Personal Info
ALTER TABLE public.tutor_profiles 
ADD COLUMN IF NOT EXISTS profile_photo_url TEXT,
ADD COLUMN IF NOT EXISTS city TEXT,
ADD COLUMN IF NOT EXISTS quarter TEXT;

-- Academic Background
ALTER TABLE public.tutor_profiles 
ADD COLUMN IF NOT EXISTS highest_education TEXT,
ADD COLUMN IF NOT EXISTS institution TEXT,
ADD COLUMN IF NOT EXISTS field_of_study TEXT;
-- Note: certifications already exists as JSONB, but we're sending array
-- We'll keep both - JSONB for structured data, or add TEXT[] if needed
ALTER TABLE public.tutor_profiles 
ADD COLUMN IF NOT EXISTS certifications_array TEXT[];

-- Experience
ALTER TABLE public.tutor_profiles 
ADD COLUMN IF NOT EXISTS has_teaching_experience BOOLEAN,
ADD COLUMN IF NOT EXISTS teaching_duration TEXT,
ADD COLUMN IF NOT EXISTS previous_roles TEXT[],
ADD COLUMN IF NOT EXISTS motivation TEXT;

-- Tutoring Details
ALTER TABLE public.tutor_profiles 
ADD COLUMN IF NOT EXISTS tutoring_areas TEXT[],
ADD COLUMN IF NOT EXISTS learner_levels TEXT[],
ADD COLUMN IF NOT EXISTS specializations TEXT[],
ADD COLUMN IF NOT EXISTS personal_statement TEXT;

-- Availability
ALTER TABLE public.tutor_profiles 
ADD COLUMN IF NOT EXISTS hours_per_week TEXT;

-- Payment
ALTER TABLE public.tutor_profiles 
ADD COLUMN IF NOT EXISTS payment_method TEXT,
ADD COLUMN IF NOT EXISTS payment_details JSONB,
ADD COLUMN IF NOT EXISTS payment_agreement BOOLEAN;
-- Note: pricing_details already exists, but we're using payment_details
-- We'll add payment_details as a separate column

-- Verification
ALTER TABLE public.tutor_profiles 
ADD COLUMN IF NOT EXISTS id_card_front_url TEXT,
ADD COLUMN IF NOT EXISTS id_card_back_url TEXT,
ADD COLUMN IF NOT EXISTS video_link TEXT,
-- Note: video_url already exists, we'll add video_link as well for compatibility
ADD COLUMN IF NOT EXISTS social_links JSONB,
ADD COLUMN IF NOT EXISTS verification_agreement BOOLEAN;

-- Add comments for documentation
COMMENT ON COLUMN public.tutor_profiles.profile_photo_url IS 'Profile photo URL from storage';
COMMENT ON COLUMN public.tutor_profiles.city IS 'City where tutor is located';
COMMENT ON COLUMN public.tutor_profiles.quarter IS 'Quarter/neighborhood where tutor is located';
COMMENT ON COLUMN public.tutor_profiles.highest_education IS 'Highest education level (e.g., Bachelors, Masters)';
COMMENT ON COLUMN public.tutor_profiles.institution IS 'Institution name where tutor studied';
COMMENT ON COLUMN public.tutor_profiles.field_of_study IS 'Field of study/major';
COMMENT ON COLUMN public.tutor_profiles.certifications_array IS 'Array of certification URLs';
COMMENT ON COLUMN public.tutor_profiles.has_teaching_experience IS 'Whether tutor has previous teaching experience';
COMMENT ON COLUMN public.tutor_profiles.teaching_duration IS 'Duration of teaching experience';
COMMENT ON COLUMN public.tutor_profiles.previous_roles IS 'Array of previous teaching roles/organizations';
COMMENT ON COLUMN public.tutor_profiles.motivation IS 'Motivation to teach';
COMMENT ON COLUMN public.tutor_profiles.tutoring_areas IS 'Areas tutor can teach';
COMMENT ON COLUMN public.tutor_profiles.learner_levels IS 'Learner levels tutor can teach';
COMMENT ON COLUMN public.tutor_profiles.specializations IS 'Subject specializations';
COMMENT ON COLUMN public.tutor_profiles.personal_statement IS 'Personal statement/description';
COMMENT ON COLUMN public.tutor_profiles.hours_per_week IS 'Hours per week available';
COMMENT ON COLUMN public.tutor_profiles.payment_method IS 'Payment method (MTN Mobile Money, Orange Money, Bank Transfer)';
COMMENT ON COLUMN public.tutor_profiles.payment_details IS 'Payment details (phone, name, bank details)';
COMMENT ON COLUMN public.tutor_profiles.payment_agreement IS 'Whether tutor agreed to payment policy';
COMMENT ON COLUMN public.tutor_profiles.id_card_front_url IS 'ID card front image URL';
COMMENT ON COLUMN public.tutor_profiles.id_card_back_url IS 'ID card back image URL';
COMMENT ON COLUMN public.tutor_profiles.video_link IS 'Introduction video URL';
COMMENT ON COLUMN public.tutor_profiles.social_links IS 'Social media links (JSONB)';
COMMENT ON COLUMN public.tutor_profiles.verification_agreement IS 'Whether tutor agreed to verification process';

