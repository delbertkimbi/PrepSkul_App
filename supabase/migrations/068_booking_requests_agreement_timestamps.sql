-- ======================================================
-- MIGRATION 068: Agreement timestamps on booking_requests
-- ------------------------------------------------------
-- Store when parent/learner agreed to Terms and Safeguarding at booking.
-- ======================================================

ALTER TABLE public.booking_requests
  ADD COLUMN IF NOT EXISTS agreed_to_terms_at TIMESTAMPTZ,
  ADD COLUMN IF NOT EXISTS agreed_to_safeguarding_at TIMESTAMPTZ;

COMMENT ON COLUMN public.booking_requests.agreed_to_terms_at IS 'When the user accepted Terms of Service at time of booking request';
COMMENT ON COLUMN public.booking_requests.agreed_to_safeguarding_at IS 'When the user accepted Safeguarding Policy at time of booking request';
