-- RPC: Get recommended skulMate friends (users who play games, not already friends)
-- Duolingo-style: prioritize users with game activity (user_game_stats)
-- SECURITY DEFINER bypasses RLS on user_game_stats so we can see who plays

CREATE OR REPLACE FUNCTION public.get_recommended_skulmate_friends(
  p_limit INT DEFAULT 20
)
RETURNS TABLE (
  id UUID,
  full_name TEXT,
  email TEXT,
  avatar_url TEXT,
  total_xp BIGINT,
  games_played BIGINT,
  level BIGINT
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_user_id UUID := auth.uid();
BEGIN
  IF v_user_id IS NULL THEN
    RETURN;
  END IF;

  RETURN QUERY
  SELECT
    p.id,
    p.full_name,
    p.email,
    p.avatar_url,
    COALESCE(ugs.total_xp, 0)::BIGINT,
    COALESCE(ugs.games_played, 0)::BIGINT,
    COALESCE(ugs.level, 1)::BIGINT
  FROM profiles p
  INNER JOIN user_game_stats ugs ON ugs.user_id = p.id
  WHERE p.id != v_user_id
    AND (p.user_type IS NULL OR p.user_type NOT IN ('tutor', 'admin'))
    AND ugs.games_played > 0
    AND NOT EXISTS (
      SELECT 1 FROM skulmate_friendships f
      WHERE (f.user_id = v_user_id AND f.friend_id = p.id)
         OR (f.friend_id = v_user_id AND f.user_id = p.id)
    )
  ORDER BY ugs.total_xp DESC NULLS LAST, ugs.games_played DESC NULLS LAST
  LIMIT p_limit;
END;
$$;

COMMENT ON FUNCTION public.get_recommended_skulmate_friends(INT) IS 'Returns skulMate users (with game stats) recommended as friends, excluding current user, tutors/admins, and existing friends. Duolingo-style.';

-- Allow authenticated users to call
GRANT EXECUTE ON FUNCTION public.get_recommended_skulmate_friends(INT) TO authenticated;
