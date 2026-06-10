-- Store geocoded coordinates for onsite sessions (accurate map + check-in)

DO $$
BEGIN
  IF EXISTS (
    SELECT 1 FROM information_schema.tables
    WHERE table_schema = 'public' AND table_name = 'individual_sessions'
  ) THEN
    ALTER TABLE public.individual_sessions
      ADD COLUMN IF NOT EXISTS onsite_coordinates TEXT;

    COMMENT ON COLUMN public.individual_sessions.onsite_coordinates IS
      'Verified lat,lng from booking geocode (e.g. 4.0511,9.7679)';
  END IF;

  IF EXISTS (
    SELECT 1 FROM information_schema.tables
    WHERE table_schema = 'public' AND table_name = 'booking_requests'
  ) THEN
    ALTER TABLE public.booking_requests
      ADD COLUMN IF NOT EXISTS address_coordinates TEXT;
  END IF;
END $$;
