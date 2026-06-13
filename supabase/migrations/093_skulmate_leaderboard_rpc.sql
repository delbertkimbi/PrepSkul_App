-- RPC: Leaderboard with profile display fields (bypasses profiles RLS for public-safe fields)

CREATE OR REPLACE FUNCTION public.get_skulmate_leaderboard(
  p_period TEXT,
  p_period_start TIMESTAMPTZ,
  p_limit INT DEFAULT 100
)
RETURNS TABLE (
  id UUID,
  user_id UUID,
  period TEXT,
  period_start TIMESTAMPTZ,
  period_end TIMESTAMPTZ,
  total_xp INT,
  games_played INT,
  perfect_scores INT,
  average_score DOUBLE PRECISION,
  rank INT,
  created_at TIMESTAMPTZ,
  updated_at TIMESTAMPTZ,
  user_name TEXT,
  user_avatar_url TEXT,
  user_character_id TEXT,
  user_level INT
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF auth.uid() IS NULL THEN
    RETURN;
  END IF;

  RETURN QUERY
  SELECT
    l.id,
    l.user_id,
    l.period,
    l.period_start,
    l.period_end,
    l.total_xp,
    l.games_played,
    l.perfect_scores,
    l.average_score,
    l.rank,
    l.created_at,
    l.updated_at,
    COALESCE(
      NULLIF(TRIM(p.full_name), ''),
      NULLIF(SPLIT_PART(COALESCE(p.email, ''), '@', 1), ''),
      'Player'
    ) AS user_name,
    p.avatar_url AS user_avatar_url,
    p.skulmate_character_id AS user_character_id,
    COALESCE(ugs.level, 1)::INT AS user_level
  FROM skulmate_leaderboards l
  INNER JOIN profiles p ON p.id = l.user_id
  LEFT JOIN user_game_stats ugs ON ugs.user_id = l.user_id
  WHERE l.period = p_period
    AND l.period_start = p_period_start
  ORDER BY l.rank ASC NULLS LAST, l.total_xp DESC
  LIMIT p_limit;
END;
$$;

COMMENT ON FUNCTION public.get_skulmate_leaderboard(TEXT, TIMESTAMPTZ, INT) IS
  'Returns SkulMate leaderboard rows with display names and avatars for all players.';

GRANT EXECUTE ON FUNCTION public.get_skulmate_leaderboard(TEXT, TIMESTAMPTZ, INT) TO authenticated;
