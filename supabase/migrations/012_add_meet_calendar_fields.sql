-- Migration: Add Google Meet and Calendar fields to trial_sessions and recurring_sessions
-- Date: 2025-01-25
-- Purpose: Support Phase 1.2 - Payment gate and Meet link generation

-- Add Meet and Calendar fields to trial_sessions
ALTER TABLE public.trial_sessions
ADD COLUMN IF NOT EXISTS meet_link TEXT,
ADD COLUMN IF NOT EXISTS calendar_event_id TEXT,
ADD COLUMN IF NOT EXISTS fapshi_trans_id TEXT,
ADD COLUMN IF NOT EXISTS payment_initiated_at TIMESTAMP WITH TIME ZONE,
ADD COLUMN IF NOT EXISTS tutor_joined_at TIMESTAMP WITH TIME ZONE,
ADD COLUMN IF NOT EXISTS student_joined_at TIMESTAMP WITH TIME ZONE,
ADD COLUMN IF NOT EXISTS meet_link_generated_at TIMESTAMP WITH TIME ZONE;

-- Add Meet and Calendar fields to recurring_sessions
ALTER TABLE public.recurring_sessions
ADD COLUMN IF NOT EXISTS meet_link TEXT,
ADD COLUMN IF NOT EXISTS calendar_event_id TEXT;

-- Create indexes for faster lookups
CREATE INDEX IF NOT EXISTS idx_trial_sessions_fapshi_trans_id 
  ON public.trial_sessions(fapshi_trans_id);

CREATE INDEX IF NOT EXISTS idx_trial_sessions_calendar_event_id 
  ON public.trial_sessions(calendar_event_id);

CREATE INDEX IF NOT EXISTS idx_recurring_sessions_calendar_event_id 
  ON public.recurring_sessions(calendar_event_id);

-- Add comments
COMMENT ON COLUMN public.trial_sessions.meet_link IS 'Google Meet link for the session (generated after payment)';
COMMENT ON COLUMN public.trial_sessions.calendar_event_id IS 'Google Calendar event ID';
COMMENT ON COLUMN public.trial_sessions.fapshi_trans_id IS 'Fapshi transaction ID for payment tracking';
COMMENT ON COLUMN public.trial_sessions.payment_initiated_at IS 'Timestamp when payment was initiated';
COMMENT ON COLUMN public.trial_sessions.tutor_joined_at IS 'Timestamp when tutor joined the meeting';
COMMENT ON COLUMN public.trial_sessions.student_joined_at IS 'Timestamp when student joined the meeting';
COMMENT ON COLUMN public.trial_sessions.meet_link_generated_at IS 'Timestamp when Meet link was generated';

COMMENT ON COLUMN public.recurring_sessions.meet_link IS 'Permanent Google Meet link for recurring sessions';
COMMENT ON COLUMN public.recurring_sessions.calendar_event_id IS 'Google Calendar event ID for recurring sessions';






