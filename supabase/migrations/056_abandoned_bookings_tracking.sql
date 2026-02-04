-- ======================================================
-- MIGRATION 056: Abandoned Bookings Tracking System
-- Tracks when users reach the review screen but don't complete bookings
-- Enables reminder notifications to complete bookings
-- ======================================================

-- Create abandoned_bookings table
CREATE TABLE IF NOT EXISTS public.abandoned_bookings (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  tutor_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  booking_type TEXT NOT NULL CHECK (booking_type IN ('trial', 'normal')),
  
  -- Booking details (stored as JSONB for flexibility)
  booking_data JSONB NOT NULL,
  
  -- Tracking metadata
  reached_review_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  reminder_sent_at TIMESTAMPTZ,
  reminder_count INTEGER NOT NULL DEFAULT 0,
  completed_at TIMESTAMPTZ, -- Set when booking is completed
  
  -- Status
  status TEXT NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'reminded', 'completed', 'expired')),
  
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Add comments
COMMENT ON TABLE public.abandoned_bookings IS 'Tracks bookings that users started but did not complete. Used for reminder notifications.';
COMMENT ON COLUMN public.abandoned_bookings.booking_type IS 'Type of booking: trial or normal';
COMMENT ON COLUMN public.abandoned_bookings.booking_data IS 'JSONB containing booking details (tutor info, subject, schedule, etc.)';
COMMENT ON COLUMN public.abandoned_bookings.reached_review_at IS 'When user reached the review/confirmation screen';
COMMENT ON COLUMN public.abandoned_bookings.reminder_sent_at IS 'When reminder notification was last sent';
COMMENT ON COLUMN public.abandoned_bookings.reminder_count IS 'Number of reminders sent (max 2)';
COMMENT ON COLUMN public.abandoned_bookings.completed_at IS 'When booking was completed (if user returns and completes)';
COMMENT ON COLUMN public.abandoned_bookings.status IS 'Status: pending (no reminder yet), reminded (reminder sent), completed (user completed), expired (too old)';

-- Create indexes for efficient queries
CREATE INDEX IF NOT EXISTS idx_abandoned_bookings_user_id ON public.abandoned_bookings(user_id);
CREATE INDEX IF NOT EXISTS idx_abandoned_bookings_tutor_id ON public.abandoned_bookings(tutor_id);
CREATE INDEX IF NOT EXISTS idx_abandoned_bookings_status ON public.abandoned_bookings(status);
CREATE INDEX IF NOT EXISTS idx_abandoned_bookings_reached_review_at ON public.abandoned_bookings(reached_review_at);
CREATE INDEX IF NOT EXISTS idx_abandoned_bookings_pending_reminders ON public.abandoned_bookings(status, reached_review_at) 
  WHERE status = 'pending' AND reminder_sent_at IS NULL;

-- Create function to update updated_at timestamp
CREATE OR REPLACE FUNCTION update_abandoned_bookings_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Create trigger for updated_at (drop if exists first)
DROP TRIGGER IF EXISTS abandoned_bookings_updated_at ON public.abandoned_bookings;
CREATE TRIGGER abandoned_bookings_updated_at
  BEFORE UPDATE ON public.abandoned_bookings
  FOR EACH ROW
  EXECUTE FUNCTION update_abandoned_bookings_updated_at();

-- Enable RLS
ALTER TABLE public.abandoned_bookings ENABLE ROW LEVEL SECURITY;

-- Drop existing policies if they exist (for idempotency)
DROP POLICY IF EXISTS "Users can view their own abandoned bookings" ON public.abandoned_bookings;
DROP POLICY IF EXISTS "Users can insert their own abandoned bookings" ON public.abandoned_bookings;
DROP POLICY IF EXISTS "Users can update their own abandoned bookings" ON public.abandoned_bookings;

-- RLS Policy: Users can only see their own abandoned bookings
CREATE POLICY "Users can view their own abandoned bookings"
  ON public.abandoned_bookings
  FOR SELECT
  USING (auth.uid() = user_id);

-- RLS Policy: Users can insert their own abandoned bookings
CREATE POLICY "Users can insert their own abandoned bookings"
  ON public.abandoned_bookings
  FOR INSERT
  WITH CHECK (auth.uid() = user_id);

-- RLS Policy: Users can update their own abandoned bookings
CREATE POLICY "Users can update their own abandoned bookings"
  ON public.abandoned_bookings
  FOR UPDATE
  USING (auth.uid() = user_id);

-- Function to mark abandoned booking as completed
CREATE OR REPLACE FUNCTION mark_abandoned_booking_completed(
  p_user_id UUID,
  p_tutor_id UUID,
  p_booking_type TEXT
)
RETURNS void AS $$
BEGIN
  UPDATE public.abandoned_bookings
  SET 
    status = 'completed',
    completed_at = NOW(),
    updated_at = NOW()
  WHERE 
    user_id = p_user_id
    AND tutor_id = p_tutor_id
    AND booking_type = p_booking_type
    AND status IN ('pending', 'reminded');
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

COMMENT ON FUNCTION mark_abandoned_booking_completed IS 'Marks an abandoned booking as completed when user returns and completes the booking';

-- Function to get abandoned bookings ready for reminder (2-4 hours after reaching review screen)
CREATE OR REPLACE FUNCTION get_abandoned_bookings_for_reminder()
RETURNS TABLE (
  id UUID,
  user_id UUID,
  tutor_id UUID,
  booking_type TEXT,
  booking_data JSONB,
  reached_review_at TIMESTAMPTZ
) AS $$
BEGIN
  RETURN QUERY
  SELECT 
    ab.id,
    ab.user_id,
    ab.tutor_id,
    ab.booking_type,
    ab.booking_data,
    ab.reached_review_at
  FROM public.abandoned_bookings ab
  WHERE 
    ab.status = 'pending'
    AND ab.reminder_sent_at IS NULL
    AND ab.reached_review_at <= NOW() - INTERVAL '2 hours'
    AND ab.reached_review_at >= NOW() - INTERVAL '24 hours' -- Don't send reminders for very old bookings
  ORDER BY ab.reached_review_at ASC
  LIMIT 100; -- Process in batches
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

COMMENT ON FUNCTION get_abandoned_bookings_for_reminder IS 'Returns abandoned bookings that are ready for reminder (2+ hours old, not yet reminded)';
