-- ======================================================
-- MIGRATION 024: Payment Requests Table
-- Creates payment_requests table for booking payments
-- ======================================================

-- ========================================
-- 1. PAYMENT REQUESTS TABLE
-- ========================================
-- Stores payment requests created when tutors approve bookings
-- Links to booking_requests and recurring_sessions
CREATE TABLE IF NOT EXISTS public.payment_requests (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  
  -- Links
  booking_request_id UUID REFERENCES public.booking_requests(id) ON DELETE CASCADE,
  recurring_session_id UUID REFERENCES public.recurring_sessions(id) ON DELETE SET NULL,
  
  -- Payment Details
  student_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  tutor_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  
  -- Amount Details
  amount DECIMAL(10, 2) NOT NULL CHECK (amount > 0),
  original_amount DECIMAL(10, 2) NOT NULL CHECK (original_amount > 0),
  discount_percent DECIMAL(5, 2) DEFAULT 0 CHECK (discount_percent >= 0 AND discount_percent <= 100),
  discount_amount DECIMAL(10, 2) DEFAULT 0 CHECK (discount_amount >= 0),
  
  -- Payment Plan
  payment_plan TEXT NOT NULL CHECK (payment_plan IN ('monthly', 'biweekly', 'weekly')),
  
  -- Status
  status TEXT NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'paid', 'failed', 'expired', 'cancelled')),
  
  -- Due Date
  due_date TIMESTAMPTZ NOT NULL,
  
  -- Payment Info
  description TEXT,
  metadata JSONB, -- Store additional info (frequency, days, location, etc.)
  
  -- Fapshi Integration
  fapshi_trans_id TEXT,
  payment_id UUID REFERENCES public.payments(id) ON DELETE SET NULL,
  
  -- Timestamps
  paid_at TIMESTAMPTZ,
  failed_at TIMESTAMPTZ,
  expired_at TIMESTAMPTZ,
  cancelled_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Indexes
CREATE INDEX IF NOT EXISTS idx_payment_requests_booking ON public.payment_requests(booking_request_id);
CREATE INDEX IF NOT EXISTS idx_payment_requests_recurring ON public.payment_requests(recurring_session_id);
CREATE INDEX IF NOT EXISTS idx_payment_requests_student ON public.payment_requests(student_id);
CREATE INDEX IF NOT EXISTS idx_payment_requests_tutor ON public.payment_requests(tutor_id);
CREATE INDEX IF NOT EXISTS idx_payment_requests_status ON public.payment_requests(status);
CREATE INDEX IF NOT EXISTS idx_payment_requests_due_date ON public.payment_requests(due_date);
CREATE INDEX IF NOT EXISTS idx_payment_requests_fapshi ON public.payment_requests(fapshi_trans_id);

-- Comments
COMMENT ON TABLE public.payment_requests IS 'Payment requests created when tutors approve bookings';
COMMENT ON COLUMN public.payment_requests.booking_request_id IS 'Original booking request that triggered this payment';
COMMENT ON COLUMN public.payment_requests.recurring_session_id IS 'Recurring session (set after recurring session is created)';
COMMENT ON COLUMN public.payment_requests.amount IS 'Final amount to pay (after discount)';
COMMENT ON COLUMN public.payment_requests.original_amount IS 'Original amount before discount';
COMMENT ON COLUMN public.payment_requests.payment_plan IS 'Payment frequency: monthly, biweekly, or weekly';
COMMENT ON COLUMN public.payment_requests.status IS 'Payment status: pending, paid, failed, expired, cancelled';
COMMENT ON COLUMN public.payment_requests.due_date IS 'When payment is due';
COMMENT ON COLUMN public.payment_requests.metadata IS 'Additional payment info (frequency, days, location, student/tutor names)';





