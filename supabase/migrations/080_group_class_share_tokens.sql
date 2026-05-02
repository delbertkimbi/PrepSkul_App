-- ======================================================
-- MIGRATION 080: Group class share tokens
-- Adds unique share tokens for deep-link based class join entry.
-- ======================================================

ALTER TABLE public.group_class_listings
  ADD COLUMN IF NOT EXISTS share_token TEXT;

UPDATE public.group_class_listings
SET share_token = REPLACE(gen_random_uuid()::text, '-', '')
WHERE share_token IS NULL OR share_token = '';

ALTER TABLE public.group_class_listings
  ALTER COLUMN share_token SET DEFAULT REPLACE(gen_random_uuid()::text, '-', '');

CREATE UNIQUE INDEX IF NOT EXISTS idx_group_class_listings_share_token
  ON public.group_class_listings (share_token)
  WHERE share_token IS NOT NULL;

COMMENT ON COLUMN public.group_class_listings.share_token IS 'Opaque token used for optional join deep-link flow (/join/class/:token).';

