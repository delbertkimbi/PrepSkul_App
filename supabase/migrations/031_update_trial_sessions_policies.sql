-- 031_update_trial_sessions_policies.sql
-- Allow learners/parents/requesters to update their trial sessions (for payments, calendar links, etc.)

-- Policy: Requesters/participants can update their own trial sessions
CREATE POLICY "Requesters can update their trial sessions"
  ON public.trial_sessions
  FOR UPDATE
  USING (
    auth.uid() = requester_id OR
    auth.uid() = learner_id OR
    auth.uid() = parent_id
  )
  WITH CHECK (
    auth.uid() = requester_id OR
    auth.uid() = learner_id OR
    auth.uid() = parent_id
  );
