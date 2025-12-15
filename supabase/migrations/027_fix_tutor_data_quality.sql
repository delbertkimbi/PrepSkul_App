-- ======================================================
-- MIGRATION 027: Tutor Data Quality Audit Script
-- Identifies tutors with missing or corrupted data
-- READ-ONLY: This script only reports issues, does not fix them
-- ======================================================

-- Create a temporary table to store audit results
CREATE TEMP TABLE IF NOT EXISTS tutor_data_quality_audit (
  tutor_id UUID,
  tutor_name TEXT,
  user_id UUID,
  status TEXT,
  issue_type TEXT,
  issue_description TEXT,
  current_value TEXT,
  recommended_value TEXT
);

-- Clear any existing audit data
TRUNCATE TABLE tutor_data_quality_audit;

-- 1. Find tutors with missing admin_approved_rating (approved tutors only)
INSERT INTO tutor_data_quality_audit (tutor_id, tutor_name, user_id, status, issue_type, issue_description, current_value, recommended_value)
SELECT 
  tp.id,
  COALESCE(p.full_name, 'Unknown') as tutor_name,
  tp.user_id,
  tp.status,
  'missing_admin_approved_rating' as issue_type,
  'Approved tutor missing admin_approved_rating' as issue_description,
  'NULL' as current_value,
  CASE 
    WHEN tp.initial_rating_suggested IS NOT NULL THEN tp.initial_rating_suggested::TEXT
    ELSE '3.5'
  END as recommended_value
FROM tutor_profiles tp
LEFT JOIN profiles p ON tp.user_id = p.id
WHERE tp.status = 'approved'
  AND tp.admin_approved_rating IS NULL;

-- 2. Find tutors with missing base_session_price (approved tutors only)
INSERT INTO tutor_data_quality_audit (tutor_id, tutor_name, user_id, status, issue_type, issue_description, current_value, recommended_value)
SELECT 
  tp.id,
  COALESCE(p.full_name, 'Unknown') as tutor_name,
  tp.user_id,
  tp.status,
  'missing_base_session_price' as issue_type,
  'Approved tutor missing base_session_price' as issue_description,
  'NULL' as current_value,
  CASE 
    WHEN tp.hourly_rate IS NOT NULL AND tp.hourly_rate BETWEEN 1000 AND 50000 
      THEN tp.hourly_rate::TEXT
    ELSE '3000'
  END as recommended_value
FROM tutor_profiles tp
LEFT JOIN profiles p ON tp.user_id = p.id
WHERE tp.status = 'approved'
  AND tp.base_session_price IS NULL;

-- 3. Find tutors with corrupted hourly_rate (too high: > 50000 or too low: < 1000)
INSERT INTO tutor_data_quality_audit (tutor_id, tutor_name, user_id, status, issue_type, issue_description, current_value, recommended_value)
SELECT 
  tp.id,
  COALESCE(p.full_name, 'Unknown') as tutor_name,
  tp.user_id,
  tp.status,
  'corrupted_hourly_rate' as issue_type,
  'hourly_rate is corrupted (outside valid range 1000-50000)' as issue_description,
  tp.hourly_rate::TEXT as current_value,
  CASE 
    WHEN tp.base_session_price IS NOT NULL AND tp.base_session_price BETWEEN 3000 AND 15000 
      THEN tp.base_session_price::TEXT
    ELSE '3000'
  END as recommended_value
FROM tutor_profiles tp
LEFT JOIN profiles p ON tp.user_id = p.id
WHERE tp.hourly_rate IS NOT NULL
  AND (tp.hourly_rate > 50000 OR tp.hourly_rate < 1000);

-- 4. Find tutors with corrupted hourly_rate (too low: < 1000)
-- (Already covered in query 3, but keeping separate for clarity in reports)

-- 5. Generate summary report
DO $$
DECLARE
  total_issues INTEGER;
  missing_rating_count INTEGER;
  missing_price_count INTEGER;
  corrupted_rate_count INTEGER;
BEGIN
  SELECT COUNT(*) INTO total_issues FROM tutor_data_quality_audit;
  SELECT COUNT(*) INTO missing_rating_count FROM tutor_data_quality_audit WHERE issue_type = 'missing_admin_approved_rating';
  SELECT COUNT(*) INTO missing_price_count FROM tutor_data_quality_audit WHERE issue_type = 'missing_base_session_price';
  SELECT COUNT(*) INTO corrupted_rate_count FROM tutor_data_quality_audit WHERE issue_type LIKE 'corrupted_hourly_rate%';
  
  RAISE NOTICE '========================================';
  RAISE NOTICE 'TUTOR DATA QUALITY AUDIT REPORT';
  RAISE NOTICE '========================================';
  RAISE NOTICE 'Total Issues Found: %', total_issues;
  RAISE NOTICE 'Missing admin_approved_rating: %', missing_rating_count;
  RAISE NOTICE 'Missing base_session_price: %', missing_price_count;
  RAISE NOTICE 'Corrupted hourly_rate: %', corrupted_rate_count;
  RAISE NOTICE '========================================';
END $$;

-- Display detailed results
SELECT 
  tutor_name,
  status,
  issue_type,
  issue_description,
  current_value,
  recommended_value
FROM tutor_data_quality_audit
ORDER BY tutor_name, issue_type;

-- Export results to a view for easy access
CREATE OR REPLACE VIEW tutor_data_quality_report AS
SELECT 
  tutor_id,
  tutor_name,
  user_id,
  status,
  issue_type,
  issue_description,
  current_value,
  recommended_value
FROM tutor_data_quality_audit;

COMMENT ON VIEW tutor_data_quality_report IS 'Current tutor data quality issues - run migration 027 to refresh';








