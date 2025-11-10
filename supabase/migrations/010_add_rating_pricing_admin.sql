-- ======================================================
-- MIGRATION 010: Add Admin Rating & Pricing Columns
-- Adds admin controls for initial ratings and pricing
-- Non-breaking: All columns are nullable
-- ======================================================

-- Add rating-related columns
ALTER TABLE public.tutor_profiles 
ADD COLUMN IF NOT EXISTS initial_rating_suggested DECIMAL(3,2) CHECK (initial_rating_suggested >= 3.0 AND initial_rating_suggested <= 4.5),
ADD COLUMN IF NOT EXISTS admin_approved_rating DECIMAL(3,2) CHECK (admin_approved_rating >= 3.0 AND admin_approved_rating <= 4.5),
ADD COLUMN IF NOT EXISTS rating_justification TEXT,
ADD COLUMN IF NOT EXISTS credential_score INTEGER;

-- Add pricing-related columns
ALTER TABLE public.tutor_profiles 
ADD COLUMN IF NOT EXISTS base_session_price DECIMAL(10,2) CHECK (base_session_price >= 3000 AND base_session_price <= 15000),
ADD COLUMN IF NOT EXISTS price_3_sessions_weekly DECIMAL(10,2),
ADD COLUMN IF NOT EXISTS price_4_sessions_weekly DECIMAL(10,2),
ADD COLUMN IF NOT EXISTS pricing_tier TEXT CHECK (pricing_tier IN ('entry', 'standard', 'premium', 'expert')),
ADD COLUMN IF NOT EXISTS price_change_requests JSONB DEFAULT '[]'::jsonb;

-- Add comments for documentation
COMMENT ON COLUMN public.tutor_profiles.initial_rating_suggested IS 'Algorithm-calculated initial rating (3.0-4.5) based on credentials';
COMMENT ON COLUMN public.tutor_profiles.admin_approved_rating IS 'Admin-set/approved initial rating (3.0-4.5)';
COMMENT ON COLUMN public.tutor_profiles.rating_justification IS 'Explanation of why this rating was suggested/approved';
COMMENT ON COLUMN public.tutor_profiles.credential_score IS 'Calculated score used by rating algorithm (0-100)';
COMMENT ON COLUMN public.tutor_profiles.base_session_price IS 'Admin-approved price per session in XAF (3000-15000)';
COMMENT ON COLUMN public.tutor_profiles.price_3_sessions_weekly IS 'Auto-calculated monthly price for 3 sessions/week (base × 12)';
COMMENT ON COLUMN public.tutor_profiles.price_4_sessions_weekly IS 'Auto-calculated monthly price for 4 sessions/week (base × 16)';
COMMENT ON COLUMN public.tutor_profiles.pricing_tier IS 'Pricing tier: entry, standard, premium, expert';
COMMENT ON COLUMN public.tutor_profiles.price_change_requests IS 'JSONB array tracking tutor price change requests';

-- Create function to auto-calculate monthly prices when base_session_price changes
CREATE OR REPLACE FUNCTION calculate_monthly_prices()
RETURNS TRIGGER AS $$
BEGIN
  IF NEW.base_session_price IS NOT NULL THEN
    NEW.price_3_sessions_weekly := NEW.base_session_price * 12; -- 3 sessions/week × 4 weeks
    NEW.price_4_sessions_weekly := NEW.base_session_price * 16; -- 4 sessions/week × 4 weeks
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Create trigger to auto-calculate monthly prices
DROP TRIGGER IF EXISTS trigger_calculate_monthly_prices ON public.tutor_profiles;
CREATE TRIGGER trigger_calculate_monthly_prices
  BEFORE INSERT OR UPDATE OF base_session_price ON public.tutor_profiles
  FOR EACH ROW
  EXECUTE FUNCTION calculate_monthly_prices();

-- Create index for faster queries on pricing tier
CREATE INDEX IF NOT EXISTS idx_tutor_profiles_pricing_tier ON public.tutor_profiles(pricing_tier);

-- Create index for faster queries on ratings
CREATE INDEX IF NOT EXISTS idx_tutor_profiles_admin_approved_rating ON public.tutor_profiles(admin_approved_rating);
