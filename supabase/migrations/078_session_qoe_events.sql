-- ======================================================
-- MIGRATION 078: Session QoE telemetry events
-- Stores operational QoE signals for classroom reliability analysis.
-- ======================================================

CREATE TABLE IF NOT EXISTS public.session_qoe_events (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  individual_session_id UUID NULL REFERENCES public.individual_sessions(id) ON DELETE CASCADE,
  trial_session_id UUID NULL REFERENCES public.trial_sessions(id) ON DELETE CASCADE,
  correlation_id TEXT NOT NULL,
  event_name TEXT NOT NULL,
  event_source TEXT NOT NULL DEFAULT 'agora_service',
  user_id UUID NULL REFERENCES public.profiles(id) ON DELETE SET NULL,
  event_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  payload JSONB NOT NULL DEFAULT '{}'::jsonb,
  CONSTRAINT session_qoe_events_one_session_fk CHECK (
    (individual_session_id IS NOT NULL)::INT + (trial_session_id IS NOT NULL)::INT = 1
  )
);

CREATE INDEX IF NOT EXISTS idx_session_qoe_events_session_time
  ON public.session_qoe_events (individual_session_id, trial_session_id, event_at DESC);

CREATE INDEX IF NOT EXISTS idx_session_qoe_events_correlation
  ON public.session_qoe_events (correlation_id, event_at DESC);

CREATE INDEX IF NOT EXISTS idx_session_qoe_events_event_name
  ON public.session_qoe_events (event_name, event_at DESC);

CREATE INDEX IF NOT EXISTS idx_session_qoe_events_payload_gin
  ON public.session_qoe_events USING GIN (payload);

COMMENT ON TABLE public.session_qoe_events IS 'Session-level QoE telemetry for reconnects, quality tier changes, stream switching, and freeze signals.';
COMMENT ON COLUMN public.session_qoe_events.correlation_id IS 'Correlation ID shared across events emitted during a live session instance.';

ALTER TABLE public.session_qoe_events ENABLE ROW LEVEL SECURITY;

CREATE POLICY session_qoe_events_select_participants
  ON public.session_qoe_events
  FOR SELECT
  USING (
    EXISTS (
      SELECT 1
      FROM public.individual_sessions s
      WHERE s.id = session_qoe_events.individual_session_id
        AND (
          s.tutor_id = auth.uid()
          OR s.learner_id = auth.uid()
          OR s.parent_id = auth.uid()
        )
    )
    OR EXISTS (
      SELECT 1
      FROM public.trial_sessions t
      WHERE t.id = session_qoe_events.trial_session_id
        AND (
          t.tutor_id = auth.uid()
          OR t.learner_id = auth.uid()
          OR t.parent_id = auth.uid()
        )
    )
    OR EXISTS (
      SELECT 1
      FROM public.session_participants sp
      WHERE (
          COALESCE(
            NULLIF(to_jsonb(sp)->>'individual_session_id', '')::UUID,
            NULLIF(to_jsonb(sp)->>'session_id', '')::UUID
          ) = session_qoe_events.individual_session_id
          OR NULLIF(to_jsonb(sp)->>'trial_session_id', '')::UUID = session_qoe_events.trial_session_id
        )
        AND sp.user_id = auth.uid()
    )
  );

CREATE POLICY session_qoe_events_insert_participants
  ON public.session_qoe_events
  FOR INSERT
  WITH CHECK (
    EXISTS (
      SELECT 1
      FROM public.individual_sessions s
      WHERE s.id = session_qoe_events.individual_session_id
        AND (
          s.tutor_id = auth.uid()
          OR s.learner_id = auth.uid()
          OR s.parent_id = auth.uid()
        )
    )
    OR EXISTS (
      SELECT 1
      FROM public.trial_sessions t
      WHERE t.id = session_qoe_events.trial_session_id
        AND (
          t.tutor_id = auth.uid()
          OR t.learner_id = auth.uid()
          OR t.parent_id = auth.uid()
        )
    )
    OR EXISTS (
      SELECT 1
      FROM public.session_participants sp
      WHERE (
          COALESCE(
            NULLIF(to_jsonb(sp)->>'individual_session_id', '')::UUID,
            NULLIF(to_jsonb(sp)->>'session_id', '')::UUID
          ) = session_qoe_events.individual_session_id
          OR NULLIF(to_jsonb(sp)->>'trial_session_id', '')::UUID = session_qoe_events.trial_session_id
        )
        AND sp.user_id = auth.uid()
    )
  );
