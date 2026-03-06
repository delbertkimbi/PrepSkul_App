-- ======================================================
-- MIGRATION 062: Allow users to delete friendship records
-- Used for: declining incoming friend requests, cancelling sent requests
-- ======================================================

DROP POLICY IF EXISTS "Users can delete own friendships" ON public.skulmate_friendships;
CREATE POLICY "Users can delete own friendships"
  ON public.skulmate_friendships FOR DELETE
  USING (auth.uid() = user_id OR auth.uid() = friend_id);
