-- ======================================================
-- MIGRATION 015: Add Admin Flags Table
-- Stores flags for irregular behavior detected in sessions
-- ======================================================

CREATE TABLE IF NOT EXISTS public.admin_flags (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  session_id UUID NOT NULL, -- References trial_sessions.id or recurring_sessions.id
  session_type TEXT NOT NULL CHECK (session_type IN ('trial', 'recurring')),
  flag_type TEXT NOT NULL, -- 'inappropriate_language', 'payment_bypass', 'external_contact', 'no_show', 'short_session', 'content_violation'
  severity TEXT NOT NULL CHECK (severity IN ('low', 'medium', 'high', 'critical')),
  description TEXT NOT NULL,
  transcript_excerpt TEXT, -- Relevant excerpt from transcript
  fathom_timestamp TEXT, -- Recording timestamp where flag was detected
  fathom_playback_url TEXT, -- Link to specific moment in recording
  resolved BOOLEAN DEFAULT FALSE,
  resolved_by UUID REFERENCES public.profiles(id),
  resolved_at TIMESTAMPTZ,
  resolution_notes TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Indexes for performance
CREATE INDEX IF NOT EXISTS idx_admin_flags_session ON public.admin_flags(session_id, session_type);
CREATE INDEX IF NOT EXISTS idx_admin_flags_type ON public.admin_flags(flag_type);
CREATE INDEX IF NOT EXISTS idx_admin_flags_severity ON public.admin_flags(severity);
CREATE INDEX IF NOT EXISTS idx_admin_flags_resolved ON public.admin_flags(resolved);
CREATE INDEX IF NOT EXISTS idx_admin_flags_created ON public.admin_flags(created_at DESC);

-- Row Level Security
ALTER TABLE public.admin_flags ENABLE ROW LEVEL SECURITY;

-- RLS Policies

-- Only admins can view flags
CREATE POLICY "Admins can view all flags"
  ON public.admin_flags FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM public.profiles
      WHERE id = auth.uid() AND is_admin = true
    )
  );

-- System can insert flags (from Fathom analysis)
CREATE POLICY "System can insert flags"
  ON public.admin_flags FOR INSERT
  WITH CHECK (true);

-- Admins can update flags (resolve them)
CREATE POLICY "Admins can update flags"
  ON public.admin_flags FOR UPDATE
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

