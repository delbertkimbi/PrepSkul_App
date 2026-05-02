-- ======================================================
-- MIGRATION 079: Group class listings + enrollments
-- Enables tutor-published group classes with paid seat enrollment.
-- ======================================================

CREATE TABLE IF NOT EXISTS public.group_class_listings (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  tutor_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  individual_session_id UUID NULL REFERENCES public.individual_sessions(id) ON DELETE SET NULL,
  title TEXT NOT NULL,
  description TEXT NOT NULL,
  flyer_image_url TEXT NULL,
  subject TEXT NULL,
  starts_at TIMESTAMPTZ NOT NULL,
  duration_minutes INTEGER NOT NULL CHECK (duration_minutes >= 15 AND duration_minutes <= 240),
  capacity INTEGER NOT NULL CHECK (capacity >= 2 AND capacity <= 50),
  price_per_seat NUMERIC(10, 2) NOT NULL CHECK (price_per_seat >= 0),
  currency_code TEXT NOT NULL DEFAULT 'XAF',
  status TEXT NOT NULL DEFAULT 'draft' CHECK (status IN ('draft', 'published', 'full', 'cancelled', 'completed')),
  published_at TIMESTAMPTZ NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_group_class_listings_tutor
  ON public.group_class_listings (tutor_id, starts_at DESC);

CREATE INDEX IF NOT EXISTS idx_group_class_listings_status_starts_at
  ON public.group_class_listings (status, starts_at ASC);

CREATE INDEX IF NOT EXISTS idx_group_class_listings_session
  ON public.group_class_listings (individual_session_id)
  WHERE individual_session_id IS NOT NULL;

CREATE TABLE IF NOT EXISTS public.group_class_enrollments (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  listing_id UUID NOT NULL REFERENCES public.group_class_listings(id) ON DELETE CASCADE,
  user_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  status TEXT NOT NULL DEFAULT 'reserved' CHECK (status IN ('reserved', 'paid', 'cancelled', 'refunded', 'expired')),
  payment_request_id UUID NULL REFERENCES public.payment_requests(id) ON DELETE SET NULL,
  amount_paid NUMERIC(10, 2) NULL CHECK (amount_paid >= 0),
  paid_at TIMESTAMPTZ NULL,
  cancelled_at TIMESTAMPTZ NULL,
  metadata JSONB NOT NULL DEFAULT '{}'::jsonb,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  CONSTRAINT group_class_enrollments_unique_listing_user UNIQUE (listing_id, user_id)
);

CREATE INDEX IF NOT EXISTS idx_group_class_enrollments_listing_status
  ON public.group_class_enrollments (listing_id, status);

CREATE INDEX IF NOT EXISTS idx_group_class_enrollments_user_status
  ON public.group_class_enrollments (user_id, status);

CREATE INDEX IF NOT EXISTS idx_group_class_enrollments_payment_request
  ON public.group_class_enrollments (payment_request_id)
  WHERE payment_request_id IS NOT NULL;

COMMENT ON TABLE public.group_class_listings IS 'Tutor-published group classes available for paid seat enrollment.';
COMMENT ON TABLE public.group_class_enrollments IS 'Per-user enrollment and payment state for group class listings.';
COMMENT ON COLUMN public.group_class_enrollments.status IS 'reserved | paid | cancelled | refunded | expired';

ALTER TABLE public.group_class_listings ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.group_class_enrollments ENABLE ROW LEVEL SECURITY;

-- Listings are discoverable once published.
CREATE POLICY group_class_listings_read_published
  ON public.group_class_listings
  FOR SELECT
  USING (status = 'published');

-- Tutors manage their own listings.
CREATE POLICY group_class_listings_insert_own
  ON public.group_class_listings
  FOR INSERT
  WITH CHECK (tutor_id = auth.uid());

CREATE POLICY group_class_listings_update_own
  ON public.group_class_listings
  FOR UPDATE
  USING (tutor_id = auth.uid())
  WITH CHECK (tutor_id = auth.uid());

CREATE POLICY group_class_listings_delete_own
  ON public.group_class_listings
  FOR DELETE
  USING (tutor_id = auth.uid());

-- Learners can read their own enrollments.
CREATE POLICY group_class_enrollments_select_own
  ON public.group_class_enrollments
  FOR SELECT
  USING (user_id = auth.uid());

-- Tutors can read enrollments for their listings.
CREATE POLICY group_class_enrollments_select_listing_tutor
  ON public.group_class_enrollments
  FOR SELECT
  USING (
    EXISTS (
      SELECT 1
      FROM public.group_class_listings gcl
      WHERE gcl.id = group_class_enrollments.listing_id
        AND gcl.tutor_id = auth.uid()
    )
  );

-- Learners can create/update/cancel their own enrollments.
CREATE POLICY group_class_enrollments_insert_own
  ON public.group_class_enrollments
  FOR INSERT
  WITH CHECK (user_id = auth.uid());

CREATE POLICY group_class_enrollments_update_own
  ON public.group_class_enrollments
  FOR UPDATE
  USING (user_id = auth.uid())
  WITH CHECK (user_id = auth.uid());

