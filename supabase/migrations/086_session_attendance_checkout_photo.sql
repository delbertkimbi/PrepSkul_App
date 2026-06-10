-- Checkout selfie for onsite session attendance (mirrors check_in_photo_url)

DO $$
BEGIN
  IF EXISTS (
    SELECT 1 FROM information_schema.tables
    WHERE table_schema = 'public' AND table_name = 'session_attendance'
  ) THEN
    ALTER TABLE public.session_attendance
      ADD COLUMN IF NOT EXISTS check_out_photo_url TEXT;

    COMMENT ON COLUMN public.session_attendance.check_out_photo_url IS
      'Optional selfie at check-out (presence proof when leaving session)';
  END IF;
END $$;
