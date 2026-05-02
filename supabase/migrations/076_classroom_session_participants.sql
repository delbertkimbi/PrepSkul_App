-- ======================================================
-- MIGRATION 076: Classroom — multiple users per live session
-- Adds session_participants so tutor + N learners (and optional parent observers)
-- can receive Agora tokens for the same channel. Legacy tutor_id / learner_id /
-- parent_id on individual_sessions / trial_sessions remain the primary row;
-- this table extends access for additional learners linked to the same session.
-- ======================================================

CREATE TABLE IF NOT EXISTS public.session_participants (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  individual_session_id UUID REFERENCES public.individual_sessions (id) ON DELETE CASCADE,
  trial_session_id UUID REFERENCES public.trial_sessions (id) ON DELETE CASCADE,
  user_id UUID NOT NULL REFERENCES public.profiles (id) ON DELETE CASCADE,
  role TEXT NOT NULL CHECK (role IN ('tutor', 'learner', 'parent_observer')),
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  CONSTRAINT session_participants_one_session_fk CHECK (
    (individual_session_id IS NOT NULL)::INT + (trial_session_id IS NOT NULL)::INT = 1
  ),
  CONSTRAINT session_participants_individual_user_unique UNIQUE (individual_session_id, user_id),
  CONSTRAINT session_participants_trial_user_unique UNIQUE (trial_session_id, user_id)
);

CREATE INDEX IF NOT EXISTS idx_session_participants_individual
  ON public.session_participants (individual_session_id)
  WHERE individual_session_id IS NOT NULL;

CREATE INDEX IF NOT EXISTS idx_session_participants_trial
  ON public.session_participants (trial_session_id)
  WHERE trial_session_id IS NOT NULL;

CREATE INDEX IF NOT EXISTS idx_session_participants_user_id ON public.session_participants (user_id);

COMMENT ON TABLE public.session_participants IS 'Enrolled users for a live session beyond single learner_id; enables classroom-style Agora access control.';
COMMENT ON COLUMN public.session_participants.role IS 'tutor | learner | parent_observer — mirrors session role for policy and UI.';

ALTER TABLE public.session_participants ENABLE ROW LEVEL SECURITY;

-- SELECT: anyone who is already a legacy session participant OR listed in session_participants for that session
CREATE POLICY session_participants_select_members
  ON public.session_participants
  FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM public.individual_sessions s
      WHERE s.id = session_participants.individual_session_id
        AND (
          s.tutor_id = auth.uid()
          OR s.learner_id = auth.uid()
          OR s.parent_id = auth.uid()
        )
    )
    OR EXISTS (
      SELECT 1 FROM public.trial_sessions t
      WHERE t.id = session_participants.trial_session_id
        AND (
          t.tutor_id = auth.uid()
          OR t.learner_id = auth.uid()
          OR t.parent_id = auth.uid()
        )
    )
    OR EXISTS (
      SELECT 1 FROM public.session_participants me
      WHERE me.user_id = auth.uid()
        AND (
          (me.individual_session_id IS NOT NULL AND me.individual_session_id = session_participants.individual_session_id)
          OR (me.trial_session_id IS NOT NULL AND me.trial_session_id = session_participants.trial_session_id)
        )
    )
  );

-- INSERT: tutor for that session can add rows (booking/admin flows may use service role instead)
CREATE POLICY session_participants_insert_tutor
  ON public.session_participants
  FOR INSERT
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM public.individual_sessions s
      WHERE s.id = session_participants.individual_session_id
        AND s.tutor_id = auth.uid()
    )
    OR EXISTS (
      SELECT 1 FROM public.trial_sessions t
      WHERE t.id = session_participants.trial_session_id
        AND t.tutor_id = auth.uid()
    )
  );

CREATE POLICY session_participants_delete_tutor
  ON public.session_participants
  FOR DELETE
  USING (
    EXISTS (
      SELECT 1 FROM public.individual_sessions s
      WHERE s.id = session_participants.individual_session_id
        AND s.tutor_id = auth.uid()
    )
    OR EXISTS (
      SELECT 1 FROM public.trial_sessions t
      WHERE t.id = session_participants.trial_session_id
        AND t.tutor_id = auth.uid()
    )
  );
