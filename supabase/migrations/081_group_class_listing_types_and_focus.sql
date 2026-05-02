-- ======================================================
-- MIGRATION 081: Group listing type + learning focus
-- Adds classification fields for one-time/training/bootcamp/workshop use-cases.
-- ======================================================

ALTER TABLE public.group_class_listings
  ADD COLUMN IF NOT EXISTS class_type TEXT NOT NULL DEFAULT 'one_time'
    CHECK (class_type IN ('one_time', 'training', 'bootcamp', 'workshop')),
  ADD COLUMN IF NOT EXISTS learning_focus TEXT NULL,
  ADD COLUMN IF NOT EXISTS approval_status TEXT NOT NULL DEFAULT 'pending'
    CHECK (approval_status IN ('pending', 'approved', 'rejected', 'changes_requested')),
  ADD COLUMN IF NOT EXISTS approved_by UUID NULL REFERENCES public.profiles(id) ON DELETE SET NULL,
  ADD COLUMN IF NOT EXISTS approved_at TIMESTAMPTZ NULL,
  ADD COLUMN IF NOT EXISTS approval_notes TEXT NULL;

CREATE INDEX IF NOT EXISTS idx_group_class_listings_approval_status
  ON public.group_class_listings (approval_status, starts_at ASC);

COMMENT ON COLUMN public.group_class_listings.class_type IS
  'Session format selected by tutor: one_time | training | bootcamp | workshop';
COMMENT ON COLUMN public.group_class_listings.learning_focus IS
  'What learners should expect to learn in this group session.';
COMMENT ON COLUMN public.group_class_listings.approval_status IS
  'Admin review status for discovery promotion workflow.';

