-- Allow learners and parents to read trial sessions they are linked to,
-- not only the original requester (needed for parent/child bookings).

DROP POLICY IF EXISTS "Users can view their own trial sessions" ON public.trial_sessions;

CREATE POLICY "Users can view their own trial sessions"
  ON public.trial_sessions FOR SELECT
  USING (
    auth.uid() = requester_id
    OR auth.uid() = tutor_id
    OR auth.uid() = learner_id
    OR auth.uid() = parent_id
  );
