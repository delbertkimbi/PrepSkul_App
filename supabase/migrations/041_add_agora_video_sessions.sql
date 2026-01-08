-- Migration: Add Agora RTC video session support
-- This migration adds fields for Agora video sessions and recording management

-- ========================================
-- 1. ADD AGORA FIELDS TO individual_sessions
-- ========================================

ALTER TABLE public.individual_sessions
ADD COLUMN IF NOT EXISTS agora_channel_name TEXT,
ADD COLUMN IF NOT EXISTS agora_token_expires_at TIMESTAMPTZ,
ADD COLUMN IF NOT EXISTS recording_resource_id TEXT,
ADD COLUMN IF NOT EXISTS recording_sid TEXT,
ADD COLUMN IF NOT EXISTS recording_status TEXT DEFAULT 'not_started' CHECK (recording_status IN ('not_started', 'recording', 'stopped', 'uploaded', 'failed')),
ADD COLUMN IF NOT EXISTS recording_file_url TEXT,
ADD COLUMN IF NOT EXISTS transcript_url TEXT,
ADD COLUMN IF NOT EXISTS session_summary TEXT;

-- Add index for recording status queries
CREATE INDEX IF NOT EXISTS idx_individual_sessions_recording_status 
ON public.individual_sessions(recording_status) 
WHERE recording_status IS NOT NULL;

-- Add index for Agora channel name lookups
CREATE INDEX IF NOT EXISTS idx_individual_sessions_agora_channel 
ON public.individual_sessions(agora_channel_name) 
WHERE agora_channel_name IS NOT NULL;

-- ========================================
-- 2. CREATE session_recordings TABLE
-- ========================================

CREATE TABLE IF NOT EXISTS public.session_recordings (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  session_id UUID NOT NULL REFERENCES public.individual_sessions(id) ON DELETE CASCADE,
  
  -- Agora Recording Metadata
  recording_resource_id TEXT NOT NULL,
  recording_sid TEXT NOT NULL,
  recording_status TEXT NOT NULL DEFAULT 'recording' CHECK (recording_status IN ('recording', 'stopped', 'uploaded', 'failed')),
  
  -- File URLs
  audio_file_url TEXT,
  video_file_url TEXT,
  transcript_url TEXT,
  
  -- AI Processing
  summary TEXT,
  
  -- Timestamps
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  
  -- Constraints
  CONSTRAINT session_recordings_session_id_unique UNIQUE (session_id)
);

-- Enable RLS
ALTER TABLE public.session_recordings ENABLE ROW LEVEL SECURITY;

-- Create indexes
CREATE INDEX IF NOT EXISTS idx_session_recordings_session_id 
ON public.session_recordings(session_id);

CREATE INDEX IF NOT EXISTS idx_session_recordings_recording_status 
ON public.session_recordings(recording_status);

CREATE INDEX IF NOT EXISTS idx_session_recordings_recording_resource_id 
ON public.session_recordings(recording_resource_id);

-- ========================================
-- 3. RLS POLICIES FOR session_recordings
-- ========================================

-- Users can view recordings for their own sessions
CREATE POLICY "Users can view their own session recordings"
ON public.session_recordings
FOR SELECT
USING (
  EXISTS (
    SELECT 1 FROM public.individual_sessions
    WHERE individual_sessions.id = session_recordings.session_id
    AND (
      individual_sessions.tutor_id = auth.uid()
      OR individual_sessions.learner_id = auth.uid()
      OR individual_sessions.parent_id = auth.uid()
    )
  )
);

-- System can insert recordings (via service role)
-- Note: This will be handled via service role in Next.js backend
-- For now, we allow inserts if user is part of the session
CREATE POLICY "Users can insert recordings for their sessions"
ON public.session_recordings
FOR INSERT
WITH CHECK (
  EXISTS (
    SELECT 1 FROM public.individual_sessions
    WHERE individual_sessions.id = session_recordings.session_id
    AND (
      individual_sessions.tutor_id = auth.uid()
      OR individual_sessions.learner_id = auth.uid()
      OR individual_sessions.parent_id = auth.uid()
    )
  )
);

-- Users can update recordings for their own sessions
CREATE POLICY "Users can update their own session recordings"
ON public.session_recordings
FOR UPDATE
USING (
  EXISTS (
    SELECT 1 FROM public.individual_sessions
    WHERE individual_sessions.id = session_recordings.session_id
    AND (
      individual_sessions.tutor_id = auth.uid()
      OR individual_sessions.learner_id = auth.uid()
      OR individual_sessions.parent_id = auth.uid()
    )
  )
);

-- ========================================
-- 4. UPDATE TRIGGER FOR updated_at
-- ========================================

CREATE OR REPLACE FUNCTION update_session_recordings_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER update_session_recordings_updated_at
BEFORE UPDATE ON public.session_recordings
FOR EACH ROW
EXECUTE FUNCTION update_session_recordings_updated_at();

-- ========================================
-- 5. COMMENTS
-- ========================================

COMMENT ON TABLE public.session_recordings IS 'Stores Agora Cloud Recording metadata and AI-generated summaries for video sessions';
COMMENT ON COLUMN public.individual_sessions.agora_channel_name IS 'Agora channel name for this session (format: session_{sessionId})';
COMMENT ON COLUMN public.individual_sessions.agora_token_expires_at IS 'Expiration timestamp for the Agora RTC token';
COMMENT ON COLUMN public.individual_sessions.recording_resource_id IS 'Agora Cloud Recording resource ID';
COMMENT ON COLUMN public.individual_sessions.recording_sid IS 'Agora Cloud Recording SID';
COMMENT ON COLUMN public.individual_sessions.recording_status IS 'Current status of the recording (not_started, recording, stopped, uploaded, failed)';
COMMENT ON COLUMN public.individual_sessions.recording_file_url IS 'URL to the recorded audio/video file in Supabase Storage';
COMMENT ON COLUMN public.individual_sessions.transcript_url IS 'URL to the transcript file in Supabase Storage';
COMMENT ON COLUMN public.individual_sessions.session_summary IS 'AI-generated summary of the session';

