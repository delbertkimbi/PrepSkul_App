-- ======================================================
-- MIGRATION 054: Transportation Cost System
-- Adds transportation cost tracking for onsite sessions
-- Transportation cost: 200-1000 XAF (round trip)
-- Platform fee: 0% on transportation (only on session fee)
-- ======================================================

-- Add transportation cost fields to session_payments
ALTER TABLE public.session_payments
  ADD COLUMN IF NOT EXISTS transportation_cost DECIMAL(10,2) DEFAULT 0,
  ADD COLUMN IF NOT EXISTS transportation_earnings DECIMAL(10,2) DEFAULT 0,
  ADD COLUMN IF NOT EXISTS is_onsite BOOLEAN DEFAULT false;

COMMENT ON COLUMN public.session_payments.transportation_cost IS 'Transportation cost paid by parent (200-1000 XAF, round trip). Only for onsite sessions.';
COMMENT ON COLUMN public.session_payments.transportation_earnings IS 'Transportation earnings for tutor (100% of transportation_cost, no platform fee).';
COMMENT ON COLUMN public.session_payments.is_onsite IS 'Whether this session is onsite (transportation cost applies).';

-- Add transportation earnings to tutor_earnings
ALTER TABLE public.tutor_earnings
  ADD COLUMN IF NOT EXISTS transportation_earnings DECIMAL(10,2) DEFAULT 0,
  ADD COLUMN IF NOT EXISTS earnings_type TEXT DEFAULT 'session' CHECK (earnings_type IN ('session', 'transportation', 'combined'));

COMMENT ON COLUMN public.tutor_earnings.transportation_earnings IS 'Transportation earnings (100% of transportation cost, no platform fee).';
COMMENT ON COLUMN public.tutor_earnings.earnings_type IS 'Type of earnings: session (85% of session fee), transportation (100% of transport cost), or combined (both).';

-- Create table for transportation cost calculations (for tracking and audit)
CREATE TABLE IF NOT EXISTS public.tutor_transportation_calculations (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  session_id UUID REFERENCES public.individual_sessions(id) ON DELETE CASCADE,
  tutor_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
  tutor_home_address TEXT,
  onsite_address TEXT NOT NULL,
  distance_km DECIMAL(10,2),
  duration_minutes INT,
  calculated_cost DECIMAL(10,2) NOT NULL CHECK (calculated_cost >= 200 AND calculated_cost <= 1000),
  osrm_route_data JSONB, -- Store routing details from OSRM API
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_transportation_calc_session ON public.tutor_transportation_calculations(session_id);
CREATE INDEX IF NOT EXISTS idx_transportation_calc_tutor ON public.tutor_transportation_calculations(tutor_id);

COMMENT ON TABLE public.tutor_transportation_calculations IS 'Tracks transportation cost calculations for onsite sessions. Used for audit and recalculation if needed.';
COMMENT ON COLUMN public.tutor_transportation_calculations.calculated_cost IS 'Final transportation cost (200-1000 XAF, round trip).';
COMMENT ON COLUMN public.tutor_transportation_calculations.osrm_route_data IS 'Raw OSRM routing API response (distance, duration, route geometry).';

-- Add transportation cost to booking_requests (for upfront calculation)
ALTER TABLE public.booking_requests
  ADD COLUMN IF NOT EXISTS estimated_transportation_cost DECIMAL(10,2) DEFAULT 0;

COMMENT ON COLUMN public.booking_requests.estimated_transportation_cost IS 'Estimated transportation cost for onsite sessions (calculated at booking time).';

-- Add transportation cost to recurring_sessions (for tracking)
ALTER TABLE public.recurring_sessions
  ADD COLUMN IF NOT EXISTS transportation_cost_per_session DECIMAL(10,2) DEFAULT 0;

COMMENT ON COLUMN public.recurring_sessions.transportation_cost_per_session IS 'Transportation cost per session for onsite/hybrid recurring sessions.';

-- Add transportation cost to individual_sessions (for per-session tracking)
ALTER TABLE public.individual_sessions
  ADD COLUMN IF NOT EXISTS transportation_cost DECIMAL(10,2) DEFAULT 0;

COMMENT ON COLUMN public.individual_sessions.transportation_cost IS 'Transportation cost for this specific session (if onsite).';
