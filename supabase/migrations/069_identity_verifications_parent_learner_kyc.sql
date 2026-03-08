-- ======================================================
-- MIGRATION 069: Parent/Learner Identity Verifications (KYC) for Onsite
-- ------------------------------------------------------
-- - Adds identity_verifications table to store parent/learner KYC uploads
-- - Adds identity_verified_at column on profiles to mark verified accounts
-- - Reuses private `documents` storage bucket (see 046/061 migrations)
-- - Supports flexible document types and "whose ID" (self / parent / guardian)
-- ======================================================

-- 1. Identity verifications table (per account)
CREATE TABLE IF NOT EXISTS public.identity_verifications (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),

  -- Account being verified (parent/learner account that owns bookings/payments)
  account_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,

  -- Document type (inclusive for Cameroon/Africa)
  -- Values aligned with PLAN_PARENT_LEARNER_KYC_ONSITE.md
  document_type TEXT NOT NULL CHECK (
    document_type IN (
      'national_id',
      'passport',
      'voter_card',
      'drivers_licence',
      'residence_permit',
      'other'
    )
  ),

  -- Whose ID is this? (self vs parent/guardian/other responsible adult)
  whose_id TEXT NOT NULL CHECK (
    whose_id IN (
      'self',            -- The account owner (parent/guardian or adult learner)
      'parent_guardian', -- Parent/guardian of the learner
      'other_adult'      -- Other responsible adult in the household
    )
  ),

  -- Optional free-text relationship label (e.g. "mother", "uncle", "guardian")
  relationship TEXT,

  -- Signed URLs to KYC documents in `documents` bucket
  front_url TEXT NOT NULL,
  back_url  TEXT,

  -- Verification status
  status TEXT NOT NULL DEFAULT 'pending' CHECK (
    status IN ('pending', 'verified', 'rejected')
  ),
  rejection_reason TEXT,

  -- Admin verification metadata
  verified_at TIMESTAMPTZ,
  verified_by UUID REFERENCES public.profiles(id),

  -- Timestamps
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now()
);

-- Helpful indexes
CREATE INDEX IF NOT EXISTS idx_identity_verifications_account_status
  ON public.identity_verifications (account_id, status);

CREATE INDEX IF NOT EXISTS idx_identity_verifications_created_at
  ON public.identity_verifications (created_at DESC);

COMMENT ON TABLE public.identity_verifications IS
  'Parent/learner identity verification records (KYC) for onsite bookings. One or more records per account.';

COMMENT ON COLUMN public.identity_verifications.account_id IS
  'Account (profiles.id) that this verification applies to (booking/paying user).';

COMMENT ON COLUMN public.identity_verifications.document_type IS
  'Type of ID document: national_id, passport, voter_card, drivers_licence, residence_permit, other.';

COMMENT ON COLUMN public.identity_verifications.whose_id IS
  'Whose ID is stored: self (account owner), parent_guardian, or other_adult.';

COMMENT ON COLUMN public.identity_verifications.front_url IS
  'Signed URL to front of ID document in private documents bucket.';

COMMENT ON COLUMN public.identity_verifications.back_url IS
  'Signed URL to back of ID document (if two-sided).';

COMMENT ON COLUMN public.identity_verifications.status IS
  'Verification status: pending (awaiting review), verified, or rejected.';

COMMENT ON COLUMN public.identity_verifications.verified_at IS
  'When an admin (or automated system) marked this verification as verified.';

COMMENT ON COLUMN public.identity_verifications.verified_by IS
  'Admin profile ID that verified this record.';


-- 2. Mark profiles that have passed KYC (one-time per account)
ALTER TABLE public.profiles
  ADD COLUMN IF NOT EXISTS identity_verified_at TIMESTAMPTZ;

COMMENT ON COLUMN public.profiles.identity_verified_at IS
  'When this account was marked Identity Verified for onsite KYC. Used to skip future KYC prompts.';


-- 3. Enable Row Level Security and policies
ALTER TABLE public.identity_verifications ENABLE ROW LEVEL SECURITY;

DO $$
BEGIN
  -- Accounts (and admins) can view identity_verifications
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
        -- Admins can view all
        EXISTS (
          SELECT 1 FROM public.profiles
          WHERE id = auth.uid() AND is_admin = true
        )
        OR
        -- Account owner can view their own KYC records
        account_id = auth.uid()
      );
  END IF;

  -- Accounts can create their own identity_verifications records
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE schemaname = 'public'
      AND tablename = 'identity_verifications'
      AND policyname = 'Accounts can create own identity verifications'
  ) THEN
    CREATE POLICY "Accounts can create own identity verifications"
      ON public.identity_verifications
      FOR INSERT
      WITH CHECK (
        account_id = auth.uid()
      );
  END IF;

  -- Admins can update/verify/reject identity_verifications
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

