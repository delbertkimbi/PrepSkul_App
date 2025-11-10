-- ======================================================
-- MIGRATION 013: Add Fathom Session Tables
-- Stores transcripts, summaries, and Fathom data
-- ======================================================

-- Session Transcripts Table
-- Stores Fathom-generated transcripts and summaries
CREATE TABLE IF NOT EXISTS public.session_transcripts (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  session_id UUID NOT NULL, -- References trial_sessions.id or recurring_sessions.id
  session_type TEXT NOT NULL CHECK (session_type IN ('trial', 'recurring')),
  recording_id INTEGER, -- Fathom recording ID
  transcript JSONB, -- Full transcript array from Fathom
  summary TEXT, -- Fathom-generated markdown summary
  summary_template TEXT, -- Template name (e.g., 'general')
  fathom_url TEXT, -- Link to Fathom recording page
  fathom_share_url TEXT, -- Shareable link
  duration_minutes INTEGER, -- Actual session duration
  recording_start_time TIMESTAMPTZ,
  recording_end_time TIMESTAMPTZ,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Indexes for performance
CREATE INDEX IF NOT EXISTS idx_session_transcripts_session ON public.session_transcripts(session_id, session_type);
CREATE INDEX IF NOT EXISTS idx_session_transcripts_recording ON public.session_transcripts(recording_id);
CREATE INDEX IF NOT EXISTS idx_session_transcripts_created ON public.session_transcripts(created_at DESC);

-- Session Summaries Table (for detailed summaries with key points)
CREATE TABLE IF NOT EXISTS public.session_summaries (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  transcript_id UUID REFERENCES public.session_transcripts(id) ON DELETE CASCADE,
  session_id UUID NOT NULL,
  session_type TEXT NOT NULL,
  key_points TEXT[], -- Array of key discussion points
  student_progress TEXT, -- Notes on student progress
  tutor_feedback TEXT, -- Tutor performance notes
  action_items_summary TEXT, -- Summary of action items
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Indexes
CREATE INDEX IF NOT EXISTS idx_session_summaries_session ON public.session_summaries(session_id, session_type);
CREATE INDEX IF NOT EXISTS idx_session_summaries_transcript ON public.session_summaries(transcript_id);

-- Row Level Security
ALTER TABLE public.session_transcripts ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.session_summaries ENABLE ROW LEVEL SECURITY;

-- RLS Policies for session_transcripts
-- Tutors can view transcripts for their sessions
CREATE POLICY "Tutors can view own session transcripts"
  ON public.session_transcripts FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM public.trial_sessions ts
      WHERE ts.id = session_transcripts.session_id 
        AND ts.tutor_id = auth.uid()
        AND session_transcripts.session_type = 'trial'
      UNION
      SELECT 1 FROM public.recurring_sessions rs
      WHERE rs.id = session_transcripts.session_id 
        AND rs.tutor_id = auth.uid()
        AND session_transcripts.session_type = 'recurring'
    )
  );

-- Students/Parents can view transcripts for their sessions
-- Note: This policy handles both student_id (migration 003) and learner_id (migration 002)
-- We use a function to safely check which column exists
CREATE OR REPLACE FUNCTION public.check_recurring_session_access(session_id UUID, user_id UUID)
RETURNS BOOLEAN AS $$
BEGIN
  -- Try student_id first (migration 003)
  IF EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_schema = 'public' 
    AND table_name = 'recurring_sessions' 
    AND column_name = 'student_id'
  ) THEN
    RETURN EXISTS (
      SELECT 1 FROM public.recurring_sessions rs
      WHERE rs.id = session_id AND rs.student_id = user_id
    );
  END IF;
  
  -- Fall back to learner_id (migration 002)
  IF EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_schema = 'public' 
    AND table_name = 'recurring_sessions' 
    AND column_name = 'learner_id'
  ) THEN
    RETURN EXISTS (
      SELECT 1 FROM public.recurring_sessions rs
      WHERE rs.id = session_id AND rs.learner_id = user_id
    );
  END IF;
  
  RETURN FALSE;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE POLICY "Students can view own session transcripts"
  ON public.session_transcripts FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM public.trial_sessions ts
      WHERE (ts.learner_id = auth.uid() OR ts.parent_id = auth.uid())
        AND ts.id = session_transcripts.session_id
        AND session_transcripts.session_type = 'trial'
      UNION ALL
      SELECT 1 FROM public.recurring_sessions rs
      WHERE public.check_recurring_session_access(rs.id, auth.uid())
        AND rs.id = session_transcripts.session_id
        AND session_transcripts.session_type = 'recurring'
    )
  );

-- Admins can view all transcripts
CREATE POLICY "Admins can view all transcripts"
  ON public.session_transcripts FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM public.profiles
      WHERE id = auth.uid() AND is_admin = true
    )
  );

-- System can insert transcripts (via webhook)
CREATE POLICY "System can insert transcripts"
  ON public.session_transcripts FOR INSERT
  WITH CHECK (true);

-- Similar policies for session_summaries
CREATE POLICY "Tutors can view own session summaries"
  ON public.session_summaries FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM public.session_transcripts st
      WHERE st.id = session_summaries.transcript_id
        AND (
          EXISTS (
            SELECT 1 FROM public.trial_sessions ts
            WHERE ts.id = st.session_id AND ts.tutor_id = auth.uid()
            AND st.session_type = 'trial'
          )
          OR EXISTS (
            SELECT 1 FROM public.recurring_sessions rs
            WHERE rs.id = st.session_id AND rs.tutor_id = auth.uid()
            AND st.session_type = 'recurring'
          )
        )
    )
  );

CREATE POLICY "Students can view own session summaries"
  ON public.session_summaries FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM public.session_transcripts st
      WHERE st.id = session_summaries.transcript_id
        AND (
          EXISTS (
            SELECT 1 FROM public.trial_sessions ts
            WHERE (ts.learner_id = auth.uid() OR ts.parent_id = auth.uid())
              AND ts.id = st.session_id
              AND st.session_type = 'trial'
          )
          OR EXISTS (
            SELECT 1 FROM public.recurring_sessions rs
            WHERE public.check_recurring_session_access(rs.id, auth.uid())
              AND rs.id = st.session_id
              AND st.session_type = 'recurring'
          )
        )
    )
  );

CREATE POLICY "Admins can view all summaries"
  ON public.session_summaries FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM public.profiles
      WHERE id = auth.uid() AND is_admin = true
    )
  );

CREATE POLICY "System can insert summaries"
  ON public.session_summaries FOR INSERT
  WITH CHECK (true);

