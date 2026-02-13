-- Migration: Add Agora Recording Transcription Pipeline Tables
-- This migration adds tables for storing session participants, transcripts, and cleanup logs

-- ========================================
-- 1. DROP EXISTING TABLES IF THEY EXIST (to avoid conflicts)
-- ========================================

DROP TABLE IF EXISTS public.session_transcripts CASCADE;
DROP TABLE IF EXISTS public.session_participants CASCADE;
DROP TABLE IF EXISTS public.media_cleanup_logs CASCADE;

-- ========================================
-- 2. CREATE session_participants TABLE
-- ========================================

CREATE TABLE public.session_participants (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  session_id UUID NOT NULL REFERENCES public.individual_sessions(id) ON DELETE CASCADE,
  agora_uid TEXT NOT NULL,
  user_id UUID REFERENCES public.profiles(id),
  role TEXT NOT NULL CHECK (role IN ('tutor', 'learner')),
  joined_at TIMESTAMPTZ,
  left_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  CONSTRAINT session_participants_session_uid_unique UNIQUE(session_id, agora_uid)
);

-- Indexes for session_participants
CREATE INDEX idx_session_participants_session_id 
ON public.session_participants(session_id);

CREATE INDEX idx_session_participants_agora_uid 
ON public.session_participants(agora_uid);

CREATE INDEX idx_session_participants_user_id 
ON public.session_participants(user_id) 
WHERE user_id IS NOT NULL;

-- ========================================

-- 3. CREATE session_transcripts TABLE
-- ========================================

CREATE TABLE public.session_transcripts (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  session_id UUID NOT NULL REFERENCES public.individual_sessions(id) ON DELETE CASCADE,
  participant_id UUID NOT NULL REFERENCES public.session_participants(id) ON DELETE CASCADE,
  agora_uid TEXT NOT NULL,
  start_time FLOAT NOT NULL,
  end_time FLOAT NOT NULL,
  text TEXT NOT NULL,
  confidence FLOAT,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Indexes for session_transcripts
CREATE INDEX idx_session_transcripts_session_id 
ON public.session_transcripts(session_id);

CREATE INDEX idx_session_transcripts_participant_id 
ON public.session_transcripts(participant_id);

CREATE INDEX idx_session_transcripts_agora_uid 
ON public.session_transcripts(agora_uid);

CREATE INDEX idx_session_transcripts_start_time 
ON public.session_transcripts(session_id, start_time);

-- ========================================
-- 4. CREATE media_cleanup_logs TABLE
-- ========================================

CREATE TABLE public.media_cleanup_logs (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  session_id UUID NOT NULL REFERENCES public.individual_sessions(id) ON DELETE CASCADE,
  agora_uid TEXT NOT NULL,
  audio_url TEXT NOT NULL,
  deleted_at TIMESTAMPTZ DEFAULT NOW(),
  status TEXT NOT NULL CHECK (status IN ('success', 'failed', 'pending')),
  error_message TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Indexes for media_cleanup_logs
CREATE INDEX idx_media_cleanup_logs_session_id 
ON public.media_cleanup_logs(session_id);

CREATE INDEX idx_media_cleanup_logs_status 
ON public.media_cleanup_logs(status);

CREATE INDEX idx_media_cleanup_logs_agora_uid 
ON public.media_cleanup_logs(agora_uid);

-- ========================================
-- 5. UPDATE session_recordings TABLE
-- ========================================

ALTER TABLE public.session_recordings
ADD COLUMN IF NOT EXISTS transcription_status TEXT DEFAULT 'pending' 
  CHECK (transcription_status IN ('pending', 'processing', 'completed', 'failed')),
ADD COLUMN IF NOT EXISTS transcription_started_at TIMESTAMPTZ,
ADD COLUMN IF NOT EXISTS transcription_completed_at TIMESTAMPTZ;

-- Index for transcription status queries
CREATE INDEX IF NOT EXISTS idx_session_recordings_transcription_status 
ON public.session_recordings(transcription_status) 
WHERE transcription_status IS NOT NULL;

-- ========================================
-- 6. RLS POLICIES
-- ========================================

-- Enable RLS on new tables
ALTER TABLE public.session_participants ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.session_transcripts ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.media_cleanup_logs ENABLE ROW LEVEL SECURITY;

-- Drop existing policies if they exist
DROP POLICY IF EXISTS "Users can view participants for their own sessions" ON public.session_participants;
DROP POLICY IF EXISTS "Users can view transcripts for their own sessions" ON public.session_transcripts;
DROP POLICY IF EXISTS "Users can view cleanup logs for their own sessions" ON public.media_cleanup_logs;

-- session_participants policies
CREATE POLICY "Users can view participants for their own sessions"
ON public.session_participants
FOR SELECT
USING (
  EXISTS (
    SELECT 1 FROM public.individual_sessions
    WHERE individual_sessions.id = session_participants.session_id
    AND (
      individual_sessions.tutor_id = auth.uid()
      OR individual_sessions.learner_id = auth.uid()
      OR individual_sessions.parent_id = auth.uid()
    )
  )
);

-- session_transcripts policies
CREATE POLICY "Users can view transcripts for their own sessions"
ON public.session_transcripts
FOR SELECT
USING (
  EXISTS (
    SELECT 1 FROM public.individual_sessions
    WHERE individual_sessions.id = session_transcripts.session_id
    AND (
      individual_sessions.tutor_id = auth.uid()
      OR individual_sessions.learner_id = auth.uid()
      OR individual_sessions.parent_id = auth.uid()
    )
  )
);

-- media_cleanup_logs policies (read-only for users, writes via service role)
CREATE POLICY "Users can view cleanup logs for their own sessions"
ON public.media_cleanup_logs
FOR SELECT
USING (
  EXISTS (
    SELECT 1 FROM public.individual_sessions
    WHERE individual_sessions.id = media_cleanup_logs.session_id
    AND (
      individual_sessions.tutor_id = auth.uid()
      OR individual_sessions.learner_id = auth.uid()
      OR individual_sessions.parent_id = auth.uid()
    )
  )
);

-- ========================================
-- 7. COMMENTS
-- ========================================

COMMENT ON TABLE public.session_participants IS 'Tracks Agora UIDs and user mappings for each session participant';
COMMENT ON TABLE public.session_transcripts IS 'Stores timestamped transcript segments for each participant';
COMMENT ON TABLE public.media_cleanup_logs IS 'Audit log for audio file deletions after transcription';
COMMENT ON COLUMN public.session_recordings.transcription_status IS 'Status of transcription process: pending, processing, completed, failed';
