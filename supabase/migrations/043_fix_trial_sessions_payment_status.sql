-- ======================================================
-- MIGRATION 043: Fix Trial Sessions Payment Status Constraint
-- Updates payment_status constraint to allow 'pending' status
-- ======================================================

-- Drop the old constraint
ALTER TABLE public.trial_sessions 
DROP CONSTRAINT IF EXISTS trial_sessions_payment_status_check;

-- Add new constraint that includes 'pending' status
ALTER TABLE public.trial_sessions 
ADD CONSTRAINT trial_sessions_payment_status_check 
CHECK (payment_status IN ('unpaid', 'pending', 'paid', 'failed', 'refunded'));

-- Update comment to reflect allowed values
COMMENT ON COLUMN public.trial_sessions.payment_status IS 
'Payment status: unpaid (default), pending (payment initiated), paid (confirmed), failed (payment failed), refunded (refunded)';
