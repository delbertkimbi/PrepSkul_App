-- ======================================================
-- MIGRATION 082: Group class schedule range + meeting days
-- Supports recurring trainings, bootcamps, and workshops.
-- ======================================================

ALTER TABLE public.group_class_listings
  ADD COLUMN IF NOT EXISTS schedule_end_at TIMESTAMPTZ NULL,
  ADD COLUMN IF NOT EXISTS meeting_days TEXT[] NOT NULL DEFAULT ARRAY[]::TEXT[];

COMMENT ON COLUMN public.group_class_listings.schedule_end_at IS
  'Optional end date for recurring group classes.';
COMMENT ON COLUMN public.group_class_listings.meeting_days IS
  'Days of the week the recurring class meets, e.g. Mon/Tue/Fri.';

