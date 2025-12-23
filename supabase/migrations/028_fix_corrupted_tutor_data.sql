-- ======================================================
-- MIGRATION 028: Fix Corrupted Tutor Data
-- Repairs missing admin_approved_rating, base_session_price, and corrupted hourly_rate
-- WARNING: This script modifies data. Review audit results (027) before running.
-- ======================================================

-- Start transaction for safety
BEGIN;

-- Diagnostic: Check what data we're working with
DO $$
DECLARE
  corrupted_count INTEGER;
  missing_rating_count INTEGER;
  missing_price_count INTEGER;
  all_tutors_count INTEGER;
BEGIN
  SELECT COUNT(*) INTO corrupted_count
  FROM tutor_profiles tp
  WHERE tp.hourly_rate IS NOT NULL
    AND (CAST(tp.hourly_rate AS NUMERIC) > 50000 OR CAST(tp.hourly_rate AS NUMERIC) < 1000);
  
  SELECT COUNT(*) INTO missing_rating_count
  FROM tutor_profiles tp
  WHERE tp.status = 'approved' AND tp.admin_approved_rating IS NULL;
  
  SELECT COUNT(*) INTO missing_price_count
  FROM tutor_profiles tp
  WHERE tp.status = 'approved' AND tp.base_session_price IS NULL;
  
  SELECT COUNT(*) INTO all_tutors_count
  FROM tutor_profiles tp;
  
  RAISE NOTICE '========================================';
  RAISE NOTICE 'DIAGNOSTIC: Data before fixes';
  RAISE NOTICE '========================================';
  RAISE NOTICE 'Total tutors: %', all_tutors_count;
  RAISE NOTICE 'Corrupted hourly_rate values: %', corrupted_count;
  RAISE NOTICE 'Missing admin_approved_rating (approved): %', missing_rating_count;
  RAISE NOTICE 'Missing base_session_price (approved): %', missing_price_count;
  RAISE NOTICE '========================================';
END $$;

-- 1. Fix ALL corrupted hourly_rate values (regardless of status)
-- This is the most important fix - catch all corrupted values
UPDATE tutor_profiles tp
SET 
  hourly_rate = CASE 
    -- Priority 1: Use base_session_price if valid
    WHEN tp.base_session_price IS NOT NULL 
         AND CAST(tp.base_session_price AS NUMERIC) >= 3000 
         AND CAST(tp.base_session_price AS NUMERIC) <= 15000 
      THEN CAST(tp.base_session_price AS NUMERIC)
    -- Priority 2: Default to 3000
    ELSE 3000
  END,
  updated_at = NOW()
WHERE tp.hourly_rate IS NOT NULL
  AND (
    -- Catch values outside valid range
    CAST(tp.hourly_rate AS NUMERIC) > 50000 
    OR CAST(tp.hourly_rate AS NUMERIC) < 1000
    -- Catch corrupted patterns (values with multiple zeros like 2000300, 3000400, 30004000)
    OR (CAST(tp.hourly_rate AS NUMERIC) > 10000 AND CAST(tp.hourly_rate AS TEXT) LIKE '%0000%')
  );

-- Log how many were fixed
DO $$
DECLARE
  fixed_count INTEGER;
BEGIN
  GET DIAGNOSTICS fixed_count = ROW_COUNT;
  RAISE NOTICE 'Fixed % corrupted hourly_rate values', fixed_count;
END $$;

-- 2. Set missing admin_approved_rating for approved tutors
UPDATE tutor_profiles tp
SET 
  admin_approved_rating = CASE 
    -- Priority 1: Use initial_rating_suggested if available
    WHEN tp.initial_rating_suggested IS NOT NULL 
         AND CAST(tp.initial_rating_suggested AS NUMERIC) >= 3.0 
         AND CAST(tp.initial_rating_suggested AS NUMERIC) <= 4.5 
      THEN CAST(tp.initial_rating_suggested AS NUMERIC)
    -- Priority 2: Default to 3.5 for approved tutors
    ELSE 3.5
  END,
  updated_at = NOW()
WHERE tp.status = 'approved'
  AND (tp.admin_approved_rating IS NULL OR CAST(tp.admin_approved_rating AS NUMERIC) < 3.0 OR CAST(tp.admin_approved_rating AS NUMERIC) > 4.5);

-- Log how many were fixed
DO $$
DECLARE
  fixed_count INTEGER;
BEGIN
  GET DIAGNOSTICS fixed_count = ROW_COUNT;
  RAISE NOTICE 'Set admin_approved_rating for % approved tutors', fixed_count;
END $$;

-- 3. Set missing base_session_price for approved tutors
-- This runs AFTER step 1 fixes hourly_rate, so hourly_rate should be valid now
UPDATE tutor_profiles tp
SET 
  base_session_price = CASE 
    -- Priority 1: Use hourly_rate if valid (now that we've fixed corrupted ones in step 1)
    WHEN tp.hourly_rate IS NOT NULL 
         AND CAST(tp.hourly_rate AS NUMERIC) >= 3000 
         AND CAST(tp.hourly_rate AS NUMERIC) <= 15000  -- Check it's in valid session price range
      THEN CAST(tp.hourly_rate AS NUMERIC)
    -- Priority 2: Default to 3000
    ELSE 3000
  END,
  updated_at = NOW()
WHERE tp.status = 'approved'
  AND (
    tp.base_session_price IS NULL 
    OR CAST(tp.base_session_price AS NUMERIC) < 3000 
    OR CAST(tp.base_session_price AS NUMERIC) > 15000
  );

-- Log how many were fixed
DO $$
DECLARE
  fixed_count INTEGER;
BEGIN
  GET DIAGNOSTICS fixed_count = ROW_COUNT;
  RAISE NOTICE 'Set base_session_price for % approved tutors', fixed_count;
END $$;

-- 4. Sync hourly_rate with base_session_price for approved tutors
-- (Ensure they stay in sync going forward)
-- This runs AFTER steps 1-3, so both should be valid now
UPDATE tutor_profiles tp
SET 
  hourly_rate = CAST(tp.base_session_price AS NUMERIC),
  updated_at = NOW()
WHERE tp.status = 'approved'
  AND tp.base_session_price IS NOT NULL
  AND CAST(tp.base_session_price AS NUMERIC) BETWEEN 3000 AND 15000
  AND (
    tp.hourly_rate IS NULL 
    OR CAST(tp.hourly_rate AS NUMERIC) != CAST(tp.base_session_price AS NUMERIC)
    OR CAST(tp.hourly_rate AS NUMERIC) < 1000
    OR CAST(tp.hourly_rate AS NUMERIC) > 50000
    OR (CAST(tp.hourly_rate AS NUMERIC) > 10000 AND CAST(tp.hourly_rate AS TEXT) LIKE '%0000%')  -- Also catch corrupted patterns
  );

-- Log how many were synced
DO $$
DECLARE
  synced_count INTEGER;
BEGIN
  GET DIAGNOSTICS synced_count = ROW_COUNT;
  RAISE NOTICE 'Synced hourly_rate with base_session_price for % tutors', synced_count;
END $$;

-- 5. Verify fixes: Check for any remaining issues
DO $$
DECLARE
  remaining_issues INTEGER;
  missing_rating INTEGER;
  missing_price INTEGER;
  corrupted_rate INTEGER;
BEGIN
  -- Count remaining issues
  SELECT COUNT(*) INTO missing_rating
  FROM tutor_profiles tp
  WHERE tp.status = 'approved' AND tp.admin_approved_rating IS NULL;
  
  SELECT COUNT(*) INTO missing_price
  FROM tutor_profiles tp
  WHERE tp.status = 'approved' AND tp.base_session_price IS NULL;
  
  SELECT COUNT(*) INTO corrupted_rate
  FROM tutor_profiles tp
  WHERE tp.hourly_rate IS NOT NULL
    AND (CAST(tp.hourly_rate AS NUMERIC) > 50000 OR CAST(tp.hourly_rate AS NUMERIC) < 1000);
  
  remaining_issues := missing_rating + missing_price + corrupted_rate;
  
  RAISE NOTICE '========================================';
  RAISE NOTICE 'VERIFICATION REPORT';
  RAISE NOTICE '========================================';
  RAISE NOTICE 'Remaining missing admin_approved_rating: %', missing_rating;
  RAISE NOTICE 'Remaining missing base_session_price: %', missing_price;
  RAISE NOTICE 'Remaining corrupted hourly_rate: %', corrupted_rate;
  RAISE NOTICE 'Total remaining issues: %', remaining_issues;
  RAISE NOTICE '========================================';
  
  IF remaining_issues > 0 THEN
    RAISE WARNING 'Some issues remain. Review the data manually.';
  ELSE
    RAISE NOTICE 'All data quality issues have been resolved!';
  END IF;
END $$;

-- Commit transaction
COMMIT;

-- Add comment for documentation
COMMENT ON COLUMN tutor_profiles.hourly_rate IS 'Hourly rate in XAF. Should be between 1000-50000. For approved tutors, should match base_session_price.';
COMMENT ON COLUMN tutor_profiles.base_session_price IS 'Base price per session in XAF. Required for approved tutors. Should be between 3000-15000.';
COMMENT ON COLUMN tutor_profiles.admin_approved_rating IS 'Admin-approved initial rating. Required for approved tutors. Should be between 3.0-4.5.';












