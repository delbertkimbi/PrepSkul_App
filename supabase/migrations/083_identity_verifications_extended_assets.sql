-- Extended KYC assets for onsite/hybrid verification wizard.
-- Adds holding-ID selfie and tutoring location photo.
--
-- If you see "relation identity_verifications does not exist", this file
-- bootstraps the base table from migration 069 first (idempotent).

-- ---------------------------------------------------------------------------
-- Bootstrap from 069 (safe if 069 was already applied via supabase db push)
-- ---------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS public.identity_verifications (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  account_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  document_type TEXT NOT NULL CHECK (
    document_type IN (
      'national_id',
      'passport',
      'voter_card',
      'drivers_licence',
      'residence_permit',
      'school_id',
      'other'
    )
  ),
  whose_id TEXT NOT NULL CHECK (
    whose_id IN ('self', 'parent_guardian', 'other_adult')
  ),
  relationship TEXT,
  front_url TEXT NOT NULL,
  back_url TEXT,
  status TEXT NOT NULL DEFAULT 'pending' CHECK (
    status IN ('pending', 'verified', 'rejected')
  ),
  rejection_reason TEXT,
  verified_at TIMESTAMPTZ,
  verified_by UUID REFERENCES public.profiles(id),
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_identity_verifications_account_status
  ON public.identity_verifications (account_id, status);

CREATE INDEX IF NOT EXISTS idx_identity_verifications_created_at
  ON public.identity_verifications (created_at DESC);

ALTER TABLE public.profiles
  ADD COLUMN IF NOT EXISTS identity_verified_at TIMESTAMPTZ;

ALTER TABLE public.identity_verifications ENABLE ROW LEVEL SECURITY;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE schemaname = 'public'
      AND tablename = 'identity_verifications'
      AND policyname = 'Accounts and admins can view identity verifications'
  ) THEN
    CREATE POLICY "Accounts and admins can view identity verifications"
      ON public.identity_verifications
      FOR SELECT
      USING (
        EXISTS (
          SELECT 1 FROM public.profiles
          WHERE id = auth.uid() AND is_admin = true
        )
        OR account_id = auth.uid()
      );
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE schemaname = 'public'
      AND tablename = 'identity_verifications'
      AND policyname = 'Accounts can create own identity verifications'
  ) THEN
    CREATE POLICY "Accounts can create own identity verifications"
      ON public.identity_verifications
      FOR INSERT
      WITH CHECK (account_id = auth.uid());
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE schemaname = 'public'
      AND tablename = 'identity_verifications'
      AND policyname = 'Admins can update identity verifications'
  ) THEN
    CREATE POLICY "Admins can update identity verifications"
      ON public.identity_verifications
      FOR UPDATE
      USING (
        EXISTS (
          SELECT 1 FROM public.profiles
          WHERE id = auth.uid() AND is_admin = true
        )
      )
      WITH CHECK (
        EXISTS (
          SELECT 1 FROM public.profiles
          WHERE id = auth.uid() AND is_admin = true
        )
      );
  END IF;
END $$;

-- ---------------------------------------------------------------------------
-- 083 extensions
-- ---------------------------------------------------------------------------

ALTER TABLE public.identity_verifications
  ADD COLUMN IF NOT EXISTS holding_id_url TEXT,
  ADD COLUMN IF NOT EXISTS location_photo_url TEXT,
  ADD COLUMN IF NOT EXISTS booking_request_id UUID REFERENCES public.booking_requests(id) ON DELETE SET NULL;

COMMENT ON COLUMN public.identity_verifications.holding_id_url IS
  'Photo of account holder holding their ID next to face';

COMMENT ON COLUMN public.identity_verifications.location_photo_url IS
  'Photo of tutoring location (required for onsite/hybrid)';

COMMENT ON COLUMN public.identity_verifications.booking_request_id IS
  'Optional link to the booking that triggered this verification submission';

CREATE INDEX IF NOT EXISTS idx_identity_verifications_booking_request_id
  ON public.identity_verifications (booking_request_id)
  WHERE booking_request_id IS NOT NULL;
