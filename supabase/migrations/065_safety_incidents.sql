-- ======================================================
-- MIGRATION 065: Safety Incidents Table
-- ------------------------------------------------------
-- - Adds safety_incidents table for tutor/parent/learner/admin reports
--   tied to individual_sessions
-- ======================================================

CREATE TABLE IF NOT EXISTS public.safety_incidents (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  session_id UUID NOT NULL REFERENCES public.individual_sessions(id) ON DELETE CASCADE,
  reported_by UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  role TEXT NOT NULL CHECK (role IN ('tutor','parent','learner','admin')),
  severity TEXT NOT NULL CHECK (severity IN ('info','warning','critical')),
  type TEXT NOT NULL, -- e.g. 'tutor_no_show', 'learner_absent', 'felt_unsafe', 'location_issue', 'other'
  message TEXT NOT NULL,
  location TEXT, -- Optional: GPS string or address at time of report
  created_at TIMESTAMPTZ DEFAULT now(),
  resolved BOOLEAN DEFAULT FALSE,
  resolved_by UUID REFERENCES public.profiles(id),
  resolved_at TIMESTAMPTZ,
  resolution_notes TEXT
);

-- Indexes for performance
CREATE INDEX IF NOT EXISTS idx_safety_incidents_session
  ON public.safety_incidents(session_id, created_at DESC);

CREATE INDEX IF NOT EXISTS idx_safety_incidents_severity
  ON public.safety_incidents(severity);

CREATE INDEX IF NOT EXISTS idx_safety_incidents_type
  ON public.safety_incidents(type);

CREATE INDEX IF NOT EXISTS idx_safety_incidents_resolved
  ON public.safety_incidents(resolved);

COMMENT ON TABLE public.safety_incidents IS 'User-reported safety incidents for individual_sessions (onsite and online).';
COMMENT ON COLUMN public.safety_incidents.type IS 'High-level incident type, e.g. tutor_no_show, learner_absent, felt_unsafe, location_issue, other.';
COMMENT ON COLUMN public.safety_incidents.severity IS 'info = low, warning = medium, critical = requires urgent admin attention.';

-- Enable Row Level Security
ALTER TABLE public.safety_incidents ENABLE ROW LEVEL SECURITY;

-- RLS Policies
DO $$
BEGIN
  -- Participants (and admins) can view incidents for their sessions
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE schemaname = 'public'
      AND tablename = 'safety_incidents'
      AND policyname = 'Participants and admins can view safety incidents'
  ) THEN
    CREATE POLICY "Participants and admins can view safety incidents"
      ON public.safety_incidents
      FOR SELECT
      USING (
        -- Admins can view all
        EXISTS (
          SELECT 1 FROM public.profiles
          WHERE id = auth.uid() AND is_admin = true
        )
        OR
        -- Tutors/parents/learners can view incidents for sessions they are part of
        EXISTS (
          SELECT 1
          FROM public.individual_sessions s
          WHERE s.id = safety_incidents.session_id
            AND (
              s.tutor_id = auth.uid()
              OR s.learner_id = auth.uid()
              OR s.parent_id = auth.uid()
            )
        )
      );
  END IF;

  -- Participants (and admins) can create incidents for their sessions
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE schemaname = 'public'
      AND tablename = 'safety_incidents'
      AND policyname = 'Participants can create safety incidents for their sessions'
  ) THEN
    CREATE POLICY "Participants can create safety incidents for their sessions"
      ON public.safety_incidents
      FOR INSERT
      WITH CHECK (
        -- Admins can always insert
        EXISTS (
          SELECT 1 FROM public.profiles
          WHERE id = auth.uid() AND is_admin = true
        )
        OR
        -- Tutors/parents/learners can insert for sessions they are part of
        EXISTS (
          SELECT 1
          FROM public.individual_sessions s
          WHERE s.id = safety_incidents.session_id
            AND (
              s.tutor_id = auth.uid()
              OR s.learner_id = auth.uid()
              OR s.parent_id = auth.uid()
            )
        )
      );
  END IF;

  -- Admins can update/resolve incidents
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE schemaname = 'public'
      AND tablename = 'safety_incidents'
      AND policyname = 'Admins can update and resolve safety incidents'
  ) THEN
    CREATE POLICY "Admins can update and resolve safety incidents"
      ON public.safety_incidents
      FOR UPDATE
      USING (
        EXISTS (
          SELECT 1 FROM public.profiles
          WHERE id = auth.uid() AND is_admin = true
        )
      )
      WITH CHECK (
        EXISTS (
          SELECT 1 FROM public.profiles
          WHERE id = auth.uid() AND is_admin = true
        )
      );
  END IF;
END $$;

