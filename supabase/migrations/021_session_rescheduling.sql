-- ======================================================
-- MIGRATION 021: Session Rescheduling System
-- Allows tutors and students to request session rescheduling
-- with mutual agreement required
-- ======================================================

-- Session Rescheduling Requests Table
-- Supports both trial_sessions and individual_sessions (normal recurring sessions)
CREATE TABLE IF NOT EXISTS public.session_reschedule_requests (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  session_id UUID NOT NULL, -- References trial_sessions.id or individual_sessions.id
  session_type TEXT NOT NULL CHECK (session_type IN ('trial', 'recurring')),
  recurring_session_id UUID REFERENCES public.recurring_sessions(id) ON DELETE SET NULL,
  
  -- Request Details
  requested_by UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  requested_by_type TEXT NOT NULL CHECK (requested_by_type IN ('tutor', 'student', 'parent')),
  
  -- Original Session Details
  original_date DATE NOT NULL,
  original_time TIME NOT NULL,
  
  -- Proposed New Details
  proposed_date DATE NOT NULL,
  proposed_time TIME NOT NULL,
  proposed_duration_minutes INT,
  proposed_location TEXT CHECK (proposed_location IN ('online', 'onsite', 'hybrid')),
  proposed_address TEXT,
  proposed_location_description TEXT, -- For trial sessions
  
  -- Request Details
  reason TEXT NOT NULL,
  additional_notes TEXT,
  
  -- Status and Agreement
  status TEXT NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'approved', 'rejected', 'cancelled')),
  tutor_approved BOOLEAN DEFAULT FALSE,
  student_approved BOOLEAN DEFAULT FALSE,
  approved_at TIMESTAMPTZ,
  approved_by UUID REFERENCES auth.users(id) ON DELETE SET NULL,
  
  -- Rejection
  rejected_by UUID REFERENCES auth.users(id) ON DELETE SET NULL,
  rejection_reason TEXT,
  rejected_at TIMESTAMPTZ,
  
  -- Timestamps
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW(),
  expires_at TIMESTAMPTZ DEFAULT NOW() + INTERVAL '48 hours' -- Request expires after 48 hours
);

-- Indexes for performance
CREATE INDEX IF NOT EXISTS idx_reschedule_requests_session ON public.session_reschedule_requests(session_id);
CREATE INDEX IF NOT EXISTS idx_reschedule_requests_recurring ON public.session_reschedule_requests(recurring_session_id);
CREATE INDEX IF NOT EXISTS idx_reschedule_requests_requested_by ON public.session_reschedule_requests(requested_by);
CREATE INDEX IF NOT EXISTS idx_reschedule_requests_status ON public.session_reschedule_requests(status);
CREATE INDEX IF NOT EXISTS idx_reschedule_requests_created ON public.session_reschedule_requests(created_at DESC);

-- Add rescheduling columns to individual_sessions if not exists
-- Check if table exists first
DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'individual_sessions' AND table_schema = 'public') THEN
    -- Add columns only if table exists
    ALTER TABLE public.individual_sessions
    ADD COLUMN IF NOT EXISTS reschedule_request_id UUID,
    ADD COLUMN IF NOT EXISTS original_scheduled_date DATE,
    ADD COLUMN IF NOT EXISTS original_scheduled_time TIME;
    
    -- Add foreign key constraint only if it doesn't exist
    IF NOT EXISTS (
      SELECT 1 FROM information_schema.table_constraints 
      WHERE constraint_name = 'individual_sessions_reschedule_request_id_fkey'
      AND table_schema = 'public'
    ) THEN
      ALTER TABLE public.individual_sessions
      ADD CONSTRAINT individual_sessions_reschedule_request_id_fkey
      FOREIGN KEY (reschedule_request_id) REFERENCES public.session_reschedule_requests(id) ON DELETE SET NULL;
    END IF;
  ELSE
    RAISE NOTICE 'individual_sessions table does not exist. Skipping column additions. Please run migration 002 first.';
  END IF;
END $$;

-- Add rescheduling columns to trial_sessions if not exists
ALTER TABLE public.trial_sessions
ADD COLUMN IF NOT EXISTS reschedule_request_id UUID REFERENCES public.session_reschedule_requests(id) ON DELETE SET NULL,
ADD COLUMN IF NOT EXISTS original_scheduled_date DATE,
ADD COLUMN IF NOT EXISTS original_scheduled_time TIME;

-- Function to auto-update updated_at
CREATE OR REPLACE FUNCTION update_reschedule_requests_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Trigger for auto-updating updated_at
DROP TRIGGER IF EXISTS update_reschedule_requests_modtime ON public.session_reschedule_requests;
CREATE TRIGGER update_reschedule_requests_modtime
  BEFORE UPDATE ON public.session_reschedule_requests
  FOR EACH ROW
  EXECUTE FUNCTION update_reschedule_requests_updated_at();

-- RLS Policies
ALTER TABLE public.session_reschedule_requests ENABLE ROW LEVEL SECURITY;

-- Policy: Users can view reschedule requests for their sessions
-- This policy works for both trial sessions and recurring sessions (when individual_sessions exists)
DROP POLICY IF EXISTS "Users can view their reschedule requests" ON public.session_reschedule_requests;
DO $$
BEGIN
  -- Check if individual_sessions table exists
  IF EXISTS (
    SELECT 1 FROM information_schema.tables 
    WHERE table_schema = 'public' AND table_name = 'individual_sessions'
  ) THEN
    -- Create policy with individual_sessions support
    EXECUTE '
    CREATE POLICY "Users can view their reschedule requests" ON public.session_reschedule_requests
      FOR SELECT
      USING (
        -- For recurring sessions (individual_sessions)
        (
          session_type = ''recurring'' AND (
            -- Tutor can see requests for their sessions
            EXISTS (
              SELECT 1 FROM individual_sessions
              WHERE individual_sessions.id = session_reschedule_requests.session_id
              AND individual_sessions.tutor_id = auth.uid()
            )
            OR
            -- Student/parent can see requests for their sessions
            EXISTS (
              SELECT 1 FROM individual_sessions
              WHERE individual_sessions.id = session_reschedule_requests.session_id
              AND (individual_sessions.learner_id = auth.uid() OR individual_sessions.parent_id = auth.uid())
            )
          )
        )
        OR
        -- For trial sessions
        (
          session_type = ''trial'' AND (
            -- Tutor can see requests for their trial sessions
            EXISTS (
              SELECT 1 FROM public.trial_sessions
              WHERE trial_sessions.id = session_reschedule_requests.session_id
              AND trial_sessions.tutor_id = auth.uid()
            )
            OR
            -- Student/parent can see requests for their trial sessions
            EXISTS (
              SELECT 1 FROM public.trial_sessions
              WHERE trial_sessions.id = session_reschedule_requests.session_id
              AND (trial_sessions.learner_id = auth.uid() OR trial_sessions.parent_id = auth.uid())
            )
          )
        )
        OR
        -- User can see requests they created
        requested_by = auth.uid()
      )';
  ELSE
    -- Create policy without individual_sessions (only trial sessions)
    EXECUTE '
    CREATE POLICY "Users can view their reschedule requests" ON public.session_reschedule_requests
      FOR SELECT
      USING (
        -- For trial sessions
        (
          session_type = ''trial'' AND (
            -- Tutor can see requests for their trial sessions
            EXISTS (
              SELECT 1 FROM public.trial_sessions
              WHERE trial_sessions.id = session_reschedule_requests.session_id
              AND trial_sessions.tutor_id = auth.uid()
            )
            OR
            -- Student/parent can see requests for their trial sessions
            EXISTS (
              SELECT 1 FROM public.trial_sessions
              WHERE trial_sessions.id = session_reschedule_requests.session_id
              AND (trial_sessions.learner_id = auth.uid() OR trial_sessions.parent_id = auth.uid())
            )
          )
        )
        OR
        -- User can see requests they created
        requested_by = auth.uid()
      )';
  END IF;
END $$;

-- Policy: Users can create reschedule requests for their sessions
DROP POLICY IF EXISTS "Users can create reschedule requests" ON public.session_reschedule_requests;
DO $$
BEGIN
  -- Check if individual_sessions table exists
  IF EXISTS (
    SELECT 1 FROM information_schema.tables 
    WHERE table_schema = 'public' AND table_name = 'individual_sessions'
  ) THEN
    -- Create policy with individual_sessions support
    EXECUTE '
    CREATE POLICY "Users can create reschedule requests" ON public.session_reschedule_requests
      FOR INSERT
      WITH CHECK (
        -- For recurring sessions (individual_sessions)
        (
          session_type = ''recurring'' AND (
            -- Tutor can create requests for their sessions
            EXISTS (
              SELECT 1 FROM individual_sessions
              WHERE individual_sessions.id = session_reschedule_requests.session_id
              AND individual_sessions.tutor_id = auth.uid()
            )
            OR
            -- Student/parent can create requests for their sessions
            EXISTS (
              SELECT 1 FROM individual_sessions
              WHERE individual_sessions.id = session_reschedule_requests.session_id
              AND (individual_sessions.learner_id = auth.uid() OR individual_sessions.parent_id = auth.uid())
            )
          )
        )
        OR
        -- For trial sessions
        (
          session_type = ''trial'' AND (
            -- Tutor can create requests for their trial sessions
            EXISTS (
              SELECT 1 FROM public.trial_sessions
              WHERE trial_sessions.id = session_reschedule_requests.session_id
              AND trial_sessions.tutor_id = auth.uid()
            )
            OR
            -- Student/parent can create requests for their trial sessions
            EXISTS (
              SELECT 1 FROM public.trial_sessions
              WHERE trial_sessions.id = session_reschedule_requests.session_id
              AND (trial_sessions.learner_id = auth.uid() OR trial_sessions.parent_id = auth.uid())
            )
          )
        )
      )';
  ELSE
    -- Create policy without individual_sessions (only trial sessions)
    EXECUTE '
    CREATE POLICY "Users can create reschedule requests" ON public.session_reschedule_requests
      FOR INSERT
      WITH CHECK (
        -- For trial sessions
        (
          session_type = ''trial'' AND (
            -- Tutor can create requests for their trial sessions
            EXISTS (
              SELECT 1 FROM public.trial_sessions
              WHERE trial_sessions.id = session_reschedule_requests.session_id
              AND trial_sessions.tutor_id = auth.uid()
            )
            OR
            -- Student/parent can create requests for their trial sessions
            EXISTS (
              SELECT 1 FROM public.trial_sessions
              WHERE trial_sessions.id = session_reschedule_requests.session_id
              AND (trial_sessions.learner_id = auth.uid() OR trial_sessions.parent_id = auth.uid())
            )
          )
        )
      )';
  END IF;
END $$;

-- Policy: Users can update reschedule requests (approve/reject)
DROP POLICY IF EXISTS "Users can update reschedule requests" ON public.session_reschedule_requests;
DO $$
BEGIN
  -- Check if individual_sessions table exists
  IF EXISTS (
    SELECT 1 FROM information_schema.tables 
    WHERE table_schema = 'public' AND table_name = 'individual_sessions'
  ) THEN
    -- Create policy with individual_sessions support
    EXECUTE '
    CREATE POLICY "Users can update reschedule requests" ON public.session_reschedule_requests
      FOR UPDATE
      USING (
        -- For recurring sessions (individual_sessions)
        (
          session_type = ''recurring'' AND (
            -- Tutor can approve/reject requests for their sessions
            EXISTS (
              SELECT 1 FROM individual_sessions
              WHERE individual_sessions.id = session_reschedule_requests.session_id
              AND individual_sessions.tutor_id = auth.uid()
            )
            OR
            -- Student/parent can approve/reject requests for their sessions
            EXISTS (
              SELECT 1 FROM individual_sessions
              WHERE individual_sessions.id = session_reschedule_requests.session_id
              AND (individual_sessions.learner_id = auth.uid() OR individual_sessions.parent_id = auth.uid())
            )
          )
        )
        OR
        -- For trial sessions
        (
          session_type = ''trial'' AND (
            -- Tutor can approve/reject requests for their trial sessions
            EXISTS (
              SELECT 1 FROM public.trial_sessions
              WHERE trial_sessions.id = session_reschedule_requests.session_id
              AND trial_sessions.tutor_id = auth.uid()
            )
            OR
            -- Student/parent can approve/reject requests for their trial sessions
            EXISTS (
              SELECT 1 FROM public.trial_sessions
              WHERE trial_sessions.id = session_reschedule_requests.session_id
              AND (trial_sessions.learner_id = auth.uid() OR trial_sessions.parent_id = auth.uid())
            )
          )
        )
        OR
        -- User can cancel their own requests
        (requested_by = auth.uid() AND status = ''pending'')
      )';
  ELSE
    -- Create policy without individual_sessions (only trial sessions)
    EXECUTE '
    CREATE POLICY "Users can update reschedule requests" ON public.session_reschedule_requests
      FOR UPDATE
      USING (
        -- For trial sessions
        (
          session_type = ''trial'' AND (
            -- Tutor can approve/reject requests for their trial sessions
            EXISTS (
              SELECT 1 FROM public.trial_sessions
              WHERE trial_sessions.id = session_reschedule_requests.session_id
              AND trial_sessions.tutor_id = auth.uid()
            )
            OR
            -- Student/parent can approve/reject requests for their trial sessions
            EXISTS (
              SELECT 1 FROM public.trial_sessions
              WHERE trial_sessions.id = session_reschedule_requests.session_id
              AND (trial_sessions.learner_id = auth.uid() OR trial_sessions.parent_id = auth.uid())
            )
          )
        )
        OR
        -- User can cancel their own requests
        (requested_by = auth.uid() AND status = ''pending'')
      )';
  END IF;
END $$;

COMMENT ON TABLE public.session_reschedule_requests IS 'Rescheduling requests for trial and recurring sessions requiring mutual agreement';
COMMENT ON COLUMN public.session_reschedule_requests.session_type IS 'Type of session: trial or recurring (individual_sessions)';
COMMENT ON COLUMN public.session_reschedule_requests.tutor_approved IS 'Whether the tutor has approved the reschedule request';
COMMENT ON COLUMN public.session_reschedule_requests.student_approved IS 'Whether the student/parent has approved the reschedule request';
COMMENT ON COLUMN public.session_reschedule_requests.expires_at IS 'Request expires after 48 hours if not approved by both parties';
COMMENT ON COLUMN public.session_reschedule_requests.proposed_location_description IS 'Location description for trial sessions (online/onsite details)';

