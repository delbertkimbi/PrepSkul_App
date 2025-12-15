-- ======================================================
-- MIGRATION 025: Payout Requests Table
-- Creates payout_requests table for tutor withdrawals
-- ======================================================

-- ========================================
-- 1. PAYOUT REQUESTS TABLE
-- ========================================
-- Stores payout requests from tutors
CREATE TABLE IF NOT EXISTS public.payout_requests (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  tutor_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  
  -- Payout Details
  amount DECIMAL(10, 2) NOT NULL CHECK (amount >= 5000), -- Minimum 5,000 XAF
  phone_number TEXT NOT NULL, -- Phone number for Fapshi disbursement
  
  -- Status
  status TEXT NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'processing', 'completed', 'failed', 'cancelled')),
  
  -- Processing
  processed_by UUID REFERENCES auth.users(id) ON DELETE SET NULL, -- Admin who processed
  processed_at TIMESTAMPTZ,
  fapshi_trans_id TEXT, -- Fapshi disbursement transaction ID
  
  -- Notes
  notes TEXT, -- Optional notes from tutor
  admin_notes TEXT, -- Admin notes (rejection reason, etc.)
  
  -- Timestamps
  requested_at TIMESTAMPTZ DEFAULT NOW(),
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Indexes
CREATE INDEX IF NOT EXISTS idx_payout_requests_tutor ON public.payout_requests(tutor_id);
CREATE INDEX IF NOT EXISTS idx_payout_requests_status ON public.payout_requests(status);
CREATE INDEX IF NOT EXISTS idx_payout_requests_requested ON public.payout_requests(requested_at DESC);

-- RLS Policies
ALTER TABLE public.payout_requests ENABLE ROW LEVEL SECURITY;

-- Tutors can view their own payout requests
CREATE POLICY "Tutors can view own payout requests"
  ON public.payout_requests FOR SELECT
  USING (auth.uid() = tutor_id);

-- Tutors can create their own payout requests
CREATE POLICY "Tutors can create own payout requests"
  ON public.payout_requests FOR INSERT
  WITH CHECK (auth.uid() = tutor_id);

-- Admins can view all payout requests
CREATE POLICY "Admins can view all payout requests"
  ON public.payout_requests FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM public.profiles
      WHERE profiles.id = auth.uid()
      AND profiles.user_type = 'admin'
    )
  );

-- Admins can update payout requests
CREATE POLICY "Admins can update payout requests"
  ON public.payout_requests FOR UPDATE
  USING (
    EXISTS (
      SELECT 1 FROM public.profiles
      WHERE profiles.id = auth.uid()
      AND profiles.user_type = 'admin'
    )
  );

COMMENT ON TABLE public.payout_requests IS 'Tutor payout/withdrawal requests';
COMMENT ON COLUMN public.payout_requests.amount IS 'Minimum payout: 5,000 XAF';
COMMENT ON COLUMN public.payout_requests.status IS 'pending = awaiting admin approval, processing = being processed, completed = paid out, failed = payment failed, cancelled = cancelled by tutor or admin';










