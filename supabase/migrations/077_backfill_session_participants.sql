-- ======================================================
-- MIGRATION 077: Backfill session_participants from legacy session rows
-- Ensures existing individual_sessions and trial_sessions have normalized
-- participant membership rows for tutor/learner/parent roles.
-- ======================================================

-- Backfill from individual_sessions
INSERT INTO public.session_participants (individual_session_id, user_id, role)
SELECT s.id, s.tutor_id, 'tutor'
FROM public.individual_sessions s
WHERE s.tutor_id IS NOT NULL
ON CONFLICT (individual_session_id, user_id) DO UPDATE
SET role = EXCLUDED.role;

INSERT INTO public.session_participants (individual_session_id, user_id, role)
SELECT s.id, s.learner_id, 'learner'
FROM public.individual_sessions s
WHERE s.learner_id IS NOT NULL
ON CONFLICT (individual_session_id, user_id) DO NOTHING;

INSERT INTO public.session_participants (individual_session_id, user_id, role)
SELECT s.id, s.parent_id, 'parent_observer'
FROM public.individual_sessions s
WHERE s.parent_id IS NOT NULL
ON CONFLICT (individual_session_id, user_id) DO NOTHING;

-- Backfill from trial_sessions
INSERT INTO public.session_participants (trial_session_id, user_id, role)
SELECT t.id, t.tutor_id, 'tutor'
FROM public.trial_sessions t
WHERE t.tutor_id IS NOT NULL
ON CONFLICT (trial_session_id, user_id) DO UPDATE
SET role = EXCLUDED.role;

INSERT INTO public.session_participants (trial_session_id, user_id, role)
SELECT t.id, t.learner_id, 'learner'
FROM public.trial_sessions t
WHERE t.learner_id IS NOT NULL
ON CONFLICT (trial_session_id, user_id) DO NOTHING;

INSERT INTO public.session_participants (trial_session_id, user_id, role)
SELECT t.id, t.parent_id, 'parent_observer'
FROM public.trial_sessions t
WHERE t.parent_id IS NOT NULL
ON CONFLICT (trial_session_id, user_id) DO NOTHING;
