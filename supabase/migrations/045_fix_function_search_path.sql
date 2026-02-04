-- ======================================================
-- MIGRATION 045: Fix Function Search Path Security Issues
-- Fixes mutable search_path issues in database functions
-- ======================================================

-- ========================================
-- 1. FIX update_tutor_request_updated_at
-- ========================================

CREATE OR REPLACE FUNCTION update_tutor_request_updated_at()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$;

-- ========================================
-- 2. FIX update_user_game_stats_updated_at
-- ========================================

CREATE OR REPLACE FUNCTION update_user_game_stats_updated_at()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$;

-- ========================================
-- 3. FIX calculate_monthly_prices
-- ========================================

CREATE OR REPLACE FUNCTION calculate_monthly_prices()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF NEW.base_session_price IS NOT NULL THEN
    NEW.price_3_sessions_weekly := NEW.base_session_price * 12; -- 3 sessions/week × 4 weeks
    NEW.price_4_sessions_weekly := NEW.base_session_price * 16; -- 4 sessions/week × 4 weeks
  END IF;
  RETURN NEW;
END;
$$;

-- ========================================
-- 4. VERIFY FUNCTIONS
-- ========================================

-- Verify functions have correct search_path
DO $$
DECLARE
  func_record RECORD;
  has_search_path BOOLEAN;
BEGIN
  FOR func_record IN
    SELECT proname, prosrc
    FROM pg_proc
    WHERE proname IN (
      'update_tutor_request_updated_at',
      'update_user_game_stats_updated_at',
      'calculate_monthly_prices'
    )
    AND pronamespace = (SELECT oid FROM pg_namespace WHERE nspname = 'public')
  LOOP
    -- Check if function has SET search_path in its definition
    SELECT EXISTS (
      SELECT 1
      FROM pg_proc p
      JOIN pg_namespace n ON p.pronamespace = n.oid
      WHERE n.nspname = 'public'
      AND p.proname = func_record.proname
      AND p.proconfig IS NOT NULL
      AND array_to_string(p.proconfig, ',') LIKE '%search_path%'
    ) INTO has_search_path;
    
    IF NOT has_search_path THEN
      RAISE WARNING 'Function % may not have search_path set correctly', func_record.proname;
    ELSE
      RAISE NOTICE '✅ Function % has search_path configured', func_record.proname;
    END IF;
  END LOOP;
END $$;

-- Comments
COMMENT ON FUNCTION update_tutor_request_updated_at() IS 'Updates updated_at timestamp for tutor_requests table. Fixed with explicit search_path for security.';
COMMENT ON FUNCTION update_user_game_stats_updated_at() IS 'Updates updated_at timestamp for user_game_stats table. Fixed with explicit search_path for security.';
COMMENT ON FUNCTION calculate_monthly_prices() IS 'Auto-calculates monthly prices when base_session_price changes. Fixed with explicit search_path for security.';
