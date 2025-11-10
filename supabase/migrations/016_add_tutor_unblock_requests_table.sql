-- ======================================================
-- MIGRATION 016: Add Tutor Unblock Requests Table
-- Stores requests from tutors to unblock/unhide their accounts
-- ======================================================

-- Create tutor_unblock_requests table
CREATE TABLE IF NOT EXISTS public.tutor_unblock_requests (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  tutor_id UUID NOT NULL REFERENCES public.tutor_profiles(id) ON DELETE CASCADE,
  tutor_user_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  request_type TEXT NOT NULL CHECK (request_type IN ('unblock', 'unhide')),
  reason TEXT,
  status TEXT NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'approved', 'rejected')),
  admin_response TEXT,
  reviewed_by UUID REFERENCES public.profiles(id),
  reviewed_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Create indexes
CREATE INDEX IF NOT EXISTS idx_tutor_unblock_requests_tutor_id ON public.tutor_unblock_requests(tutor_id);
CREATE INDEX IF NOT EXISTS idx_tutor_unblock_requests_status ON public.tutor_unblock_requests(status);
CREATE INDEX IF NOT EXISTS idx_tutor_unblock_requests_created_at ON public.tutor_unblock_requests(created_at DESC);

-- Enable RLS
ALTER TABLE public.tutor_unblock_requests ENABLE ROW LEVEL SECURITY;

-- RLS Policies
-- Tutors can view their own requests
CREATE POLICY "Tutors can view own unblock requests"
  ON public.tutor_unblock_requests
  FOR SELECT
  USING (tutor_user_id = auth.uid());

-- Admins can view all requests
CREATE POLICY "Admins can view all unblock requests"
  ON public.tutor_unblock_requests
  FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM public.profiles
      WHERE id = auth.uid() AND is_admin = true
    )
  );

-- Tutors can create their own requests
CREATE POLICY "Tutors can create own unblock requests"
  ON public.tutor_unblock_requests
  FOR INSERT
  WITH CHECK (tutor_user_id = auth.uid());

-- Admins can update requests
CREATE POLICY "Admins can update unblock requests"
  ON public.tutor_unblock_requests
  FOR UPDATE
  USING (
    EXISTS (
      SELECT 1 FROM public.profiles
      WHERE id = auth.uid() AND is_admin = true
    )
  );

-- Add comment
COMMENT ON TABLE public.tutor_unblock_requests IS 'Stores requests from tutors to unblock or unhide their accounts';
COMMENT ON COLUMN public.tutor_unblock_requests.request_type IS 'Type of request: unblock or unhide';
COMMENT ON COLUMN public.tutor_unblock_requests.status IS 'Request status: pending, approved, or rejected';






