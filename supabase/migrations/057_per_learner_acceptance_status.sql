-- ======================================================
-- MIGRATION 057: Per-Learner Acceptance Status for Multi-Learner Bookings
-- Allows tutors to accept/decline individual learners in group bookings
-- ======================================================

-- Add learner_acceptance_status JSONB column to booking_requests
-- Format: {"learner_name": {"status": "pending|accepted|declined", "reason": "optional reason", "responded_at": "timestamp"}}
ALTER TABLE public.booking_requests
  ADD COLUMN IF NOT EXISTS learner_acceptance_status JSONB;

COMMENT ON COLUMN public.booking_requests.learner_acceptance_status IS 'Per-learner acceptance status for multi-learner bookings. Format: {"Emma": {"status": "accepted", "reason": null, "responded_at": "2025-01-28T10:00:00Z"}, "James": {"status": "declined", "reason": "Not teaching Physics this term", "responded_at": "2025-01-28T10:05:00Z"}}';

-- Create index for efficient queries on multi-learner bookings
CREATE INDEX IF NOT EXISTS idx_booking_requests_learner_labels ON public.booking_requests USING GIN (learner_labels) 
  WHERE learner_labels IS NOT NULL;

-- Create index for learner acceptance status queries
CREATE INDEX IF NOT EXISTS idx_booking_requests_learner_acceptance_status ON public.booking_requests USING GIN (learner_acceptance_status) 
  WHERE learner_acceptance_status IS NOT NULL;

-- Function to check if all learners have been responded to
CREATE OR REPLACE FUNCTION check_all_learners_responded(
  p_request_id UUID
)
RETURNS BOOLEAN AS $$
DECLARE
  v_learner_labels JSONB;
  v_acceptance_status JSONB;
  v_learner_name TEXT;
  v_learner_status JSONB;
BEGIN
  -- Get learner labels and acceptance status
  SELECT learner_labels, learner_acceptance_status
  INTO v_learner_labels, v_acceptance_status
  FROM public.booking_requests
  WHERE id = p_request_id;
  
  -- If no learner labels, return true (not a multi-learner booking)
  IF v_learner_labels IS NULL OR jsonb_array_length(v_learner_labels) = 0 THEN
    RETURN TRUE;
  END IF;
  
  -- If no acceptance status yet, return false
  IF v_acceptance_status IS NULL THEN
    RETURN FALSE;
  END IF;
  
  -- Check each learner has a status
  FOR v_learner_name IN SELECT jsonb_array_elements_text(v_learner_labels)
  LOOP
    v_learner_status := v_acceptance_status->v_learner_name;
    
    -- If learner not in acceptance status or status is pending, return false
    IF v_learner_status IS NULL OR (v_learner_status->>'status') = 'pending' THEN
      RETURN FALSE;
    END IF;
  END LOOP;
  
  RETURN TRUE;
END;
$$ LANGUAGE plpgsql;

COMMENT ON FUNCTION check_all_learners_responded IS 'Checks if all learners in a multi-learner booking have been accepted or declined';

-- Function to get count of accepted learners
CREATE OR REPLACE FUNCTION get_accepted_learners_count(
  p_request_id UUID
)
RETURNS INTEGER AS $$
DECLARE
  v_acceptance_status JSONB;
  v_count INTEGER := 0;
  v_learner_status JSONB;
BEGIN
  -- Get acceptance status
  SELECT learner_acceptance_status
  INTO v_acceptance_status
  FROM public.booking_requests
  WHERE id = p_request_id;
  
  -- If no acceptance status, return 0
  IF v_acceptance_status IS NULL THEN
    RETURN 0;
  END IF;
  
  -- Count accepted learners
  FOR v_learner_status IN SELECT jsonb_object_values(v_acceptance_status)
  LOOP
    IF (v_learner_status->>'status') = 'accepted' THEN
      v_count := v_count + 1;
    END IF;
  END LOOP;
  
  RETURN v_count;
END;
$$ LANGUAGE plpgsql;

COMMENT ON FUNCTION get_accepted_learners_count IS 'Returns the count of accepted learners in a multi-learner booking';
