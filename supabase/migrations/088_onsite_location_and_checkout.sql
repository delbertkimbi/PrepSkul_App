-- Onsite GPS coordinates and checkout selfie (plan 088)

ALTER TABLE public.individual_sessions
  ADD COLUMN IF NOT EXISTS onsite_latitude DOUBLE PRECISION,
  ADD COLUMN IF NOT EXISTS onsite_longitude DOUBLE PRECISION;

COMMENT ON COLUMN public.individual_sessions.onsite_latitude IS 'Geocoded latitude for onsite check-in proximity';
COMMENT ON COLUMN public.individual_sessions.onsite_longitude IS 'Geocoded longitude for onsite check-in proximity';

ALTER TABLE public.recurring_sessions
  ADD COLUMN IF NOT EXISTS onsite_latitude DOUBLE PRECISION,
  ADD COLUMN IF NOT EXISTS onsite_longitude DOUBLE PRECISION;

COMMENT ON COLUMN public.recurring_sessions.onsite_latitude IS 'Geocoded latitude for recurring onsite sessions';
COMMENT ON COLUMN public.recurring_sessions.onsite_longitude IS 'Geocoded longitude for recurring onsite sessions';

DO $$
BEGIN
  IF EXISTS (
    SELECT 1 FROM information_schema.tables
    WHERE table_schema = 'public' AND table_name = 'session_attendance'
  ) THEN
    ALTER TABLE public.session_attendance
      ADD COLUMN IF NOT EXISTS check_out_photo_url TEXT;

    COMMENT ON COLUMN public.session_attendance.check_out_photo_url IS
      'Selfie at checkout (presence proof when leaving onsite session)';
  END IF;
END $$;
