-- Onsite: continuous location monitoring + check-in photo (Uber-style)
-- No popups during session; background-only; 5min interval, 50m deviation threshold.
-- REQUIRES: session_attendance table (from migration 022_normal_sessions_tables.sql)
-- Skips silently if session_attendance does not exist yet.

DO $$
BEGIN
  IF EXISTS (
    SELECT 1 FROM information_schema.tables
    WHERE table_schema = 'public' AND table_name = 'session_attendance'
  ) THEN
    ALTER TABLE public.session_attendance
      ADD COLUMN IF NOT EXISTS location_history JSONB DEFAULT '[]'::jsonb,
      ADD COLUMN IF NOT EXISTS location_deviations JSONB DEFAULT '[]'::jsonb,
      ADD COLUMN IF NOT EXISTS last_location_check TIMESTAMPTZ,
      ADD COLUMN IF NOT EXISTS location_check_count INT DEFAULT 0;

    ALTER TABLE public.session_attendance
      ADD COLUMN IF NOT EXISTS check_in_photo_url TEXT;

    ALTER TABLE public.session_attendance
      ADD COLUMN IF NOT EXISTS check_in_time TIMESTAMPTZ,
      ADD COLUMN IF NOT EXISTS check_out_time TIMESTAMPTZ,
      ADD COLUMN IF NOT EXISTS punctuality_status TEXT,
      ADD COLUMN IF NOT EXISTS arrival_time_minutes INT,
      ADD COLUMN IF NOT EXISTS duration_minutes INT;

    COMMENT ON COLUMN public.session_attendance.location_history IS 'Array of {timestamp, lat, lon, distance_meters} during session (background checks)';
    COMMENT ON COLUMN public.session_attendance.location_deviations IS 'Array of {timestamp, distance_meters, resolved} when tutor moved >50m from venue';
    COMMENT ON COLUMN public.session_attendance.last_location_check IS 'Last time we recorded location for this attendance';
    COMMENT ON COLUMN public.session_attendance.location_check_count IS 'Number of background location checks performed';
    COMMENT ON COLUMN public.session_attendance.check_in_photo_url IS 'Optional selfie/group photo URL at check-in (presence proof)';
  END IF;
END $$;
