-- Allow school ID as a KYC document type (student learners).

DO $$
DECLARE
  constraint_name text;
BEGIN
  SELECT c.conname INTO constraint_name
  FROM pg_constraint c
  JOIN pg_class t ON t.oid = c.conrelid
  JOIN pg_namespace n ON n.oid = t.relnamespace
  WHERE n.nspname = 'public'
    AND t.relname = 'identity_verifications'
    AND c.contype = 'c'
    AND pg_get_constraintdef(c.oid) LIKE '%document_type%'
  LIMIT 1;

  IF constraint_name IS NOT NULL THEN
    EXECUTE format(
      'ALTER TABLE public.identity_verifications DROP CONSTRAINT %I',
      constraint_name
    );
  END IF;
END $$;

ALTER TABLE public.identity_verifications
  ADD CONSTRAINT identity_verifications_document_type_check
  CHECK (
    document_type IN (
      'national_id',
      'passport',
      'voter_card',
      'drivers_licence',
      'residence_permit',
      'school_id',
      'other'
    )
  );

COMMENT ON COLUMN public.identity_verifications.document_type IS
  'Type of ID: national_id, passport, voter_card, drivers_licence, residence_permit, school_id, other.';
