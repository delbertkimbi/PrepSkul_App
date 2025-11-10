-- ======================================================
-- MIGRATION 017: Add certificates_urls column to tutor_profiles
-- ======================================================

-- Add certificates_urls column to store certificate URLs as JSONB array
ALTER TABLE public.tutor_profiles 
ADD COLUMN IF NOT EXISTS certificates_urls JSONB DEFAULT '[]'::jsonb;

-- Add index for faster queries
CREATE INDEX IF NOT EXISTS idx_tutor_profiles_certificates_urls 
ON public.tutor_profiles USING gin (certificates_urls);

COMMENT ON COLUMN public.tutor_profiles.certificates_urls IS 'Array of certificate document URLs uploaded by the tutor';






