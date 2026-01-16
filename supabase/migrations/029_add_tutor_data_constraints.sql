-- ======================================================
-- MIGRATION 029: Add Tutor Data Quality Constraints
-- Prevents invalid data from being inserted/updated
-- ======================================================

-- 1. First, fix any remaining corrupted hourly_rate values before adding constraint
-- This ensures the constraint won't fail on existing bad data
UPDATE tutor_profiles tp
SET 
  hourly_rate = CASE 
    -- Use base_session_price if valid
    WHEN tp.base_session_price IS NOT NULL 
         AND tp.base_session_price BETWEEN 3000 AND 15000 
      THEN tp.base_session_price
    -- Default to 3000 for any invalid values
    ELSE 3000
  END,
  updated_at = NOW()
WHERE tp.hourly_rate IS NOT NULL
  AND (tp.hourly_rate > 50000 OR tp.hourly_rate < 1000);

-- 2. Add CHECK constraint for hourly_rate (must be between 1000 and 50000)
DO $$
BEGIN
  -- Drop existing constraint if it exists
  IF EXISTS (
    SELECT 1 FROM pg_constraint 
    WHERE conname = 'tutor_profiles_hourly_rate_check'
  ) THEN
    ALTER TABLE tutor_profiles DROP CONSTRAINT tutor_profiles_hourly_rate_check;
  END IF;
  
  -- Add new constraint
  ALTER TABLE tutor_profiles
  ADD CONSTRAINT tutor_profiles_hourly_rate_check
  CHECK (hourly_rate IS NULL OR (hourly_rate >= 1000 AND hourly_rate <= 50000));
  
  RAISE NOTICE 'Added hourly_rate constraint (1000-50000)';
END $$;

-- 2. Fix any remaining invalid base_session_price values before adding constraint
UPDATE tutor_profiles tp
SET 
  base_session_price = CASE 
    -- Use hourly_rate if valid
    WHEN tp.hourly_rate IS NOT NULL 
         AND tp.hourly_rate BETWEEN 3000 AND 15000 
      THEN tp.hourly_rate
    -- Default to 3000 for any invalid values
    ELSE 3000
  END,
  updated_at = NOW()
WHERE tp.base_session_price IS NOT NULL
  AND (tp.base_session_price < 3000 OR tp.base_session_price > 15000);

-- 3. Add CHECK constraint for base_session_price (must be between 3000 and 15000 if not NULL)
DO $$
BEGIN
  -- Drop existing constraint if it exists
  IF EXISTS (
    SELECT 1 FROM pg_constraint 
    WHERE conname = 'tutor_profiles_base_session_price_check'
  ) THEN
    ALTER TABLE tutor_profiles DROP CONSTRAINT tutor_profiles_base_session_price_check;
  END IF;
  
  -- Add new constraint (note: existing constraint from 010 might conflict, so we drop it first)
  ALTER TABLE tutor_profiles
  ADD CONSTRAINT tutor_profiles_base_session_price_check
  CHECK (base_session_price IS NULL OR (base_session_price >= 3000 AND base_session_price <= 15000));
  
  RAISE NOTICE 'Added base_session_price constraint (3000-15000)';
END $$;

-- 4. Create function to validate approved tutor data
CREATE OR REPLACE FUNCTION validate_approved_tutor_data()
RETURNS TRIGGER AS $$
BEGIN
  -- If tutor is being approved, ensure required fields are set
  IF NEW.status = 'approved' AND (OLD.status IS NULL OR OLD.status != 'approved') THEN
    -- Check admin_approved_rating
    IF NEW.admin_approved_rating IS NULL THEN
      RAISE EXCEPTION 'Cannot approve tutor without admin_approved_rating. Please set rating before approval.';
    END IF;
    
    IF NEW.admin_approved_rating < 3.0 OR NEW.admin_approved_rating > 4.5 THEN
      RAISE EXCEPTION 'admin_approved_rating must be between 3.0 and 4.5. Current value: %', NEW.admin_approved_rating;
    END IF;
    
    -- Check base_session_price
    IF NEW.base_session_price IS NULL THEN
      RAISE EXCEPTION 'Cannot approve tutor without base_session_price. Please set pricing before approval.';
    END IF;
    
    IF NEW.base_session_price < 3000 OR NEW.base_session_price > 15000 THEN
      RAISE EXCEPTION 'base_session_price must be between 3000 and 15000. Current value: %', NEW.base_session_price;
    END IF;
  END IF;
  
  -- If hourly_rate is set, validate it
  IF NEW.hourly_rate IS NOT NULL THEN
    IF NEW.hourly_rate < 1000 OR NEW.hourly_rate > 50000 THEN
      RAISE EXCEPTION 'hourly_rate must be between 1000 and 50000. Current value: %', NEW.hourly_rate;
    END IF;
  END IF;
  
  -- If base_session_price is set, validate it
  IF NEW.base_session_price IS NOT NULL THEN
    IF NEW.base_session_price < 3000 OR NEW.base_session_price > 15000 THEN
      RAISE EXCEPTION 'base_session_price must be between 3000 and 15000. Current value: %', NEW.base_session_price;
    END IF;
  END IF;
  
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- 5. Create trigger to validate data before insert/update
DROP TRIGGER IF EXISTS trigger_validate_approved_tutor_data ON tutor_profiles;
CREATE TRIGGER trigger_validate_approved_tutor_data
  BEFORE INSERT OR UPDATE ON tutor_profiles
  FOR EACH ROW
  EXECUTE FUNCTION validate_approved_tutor_data();

DO $$
BEGIN
  RAISE NOTICE 'Created validation trigger for tutor data';
END $$;

-- 6. Create function to auto-sync hourly_rate with base_session_price
CREATE OR REPLACE FUNCTION sync_hourly_rate_with_base_price()
RETURNS TRIGGER AS $$
BEGIN
  -- If base_session_price is updated and tutor is approved, sync hourly_rate
  IF NEW.status = 'approved' 
     AND NEW.base_session_price IS NOT NULL 
     AND NEW.base_session_price BETWEEN 3000 AND 15000 THEN
    -- Only update if hourly_rate is NULL, corrupted, or different
    IF NEW.hourly_rate IS NULL 
       OR NEW.hourly_rate NOT BETWEEN 1000 AND 50000 
       OR NEW.hourly_rate != NEW.base_session_price THEN
      NEW.hourly_rate := NEW.base_session_price;
    END IF;
  END IF;
  
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- 7. Create trigger to auto-sync hourly_rate
DROP TRIGGER IF EXISTS trigger_sync_hourly_rate ON tutor_profiles;
CREATE TRIGGER trigger_sync_hourly_rate
  BEFORE INSERT OR UPDATE OF base_session_price, status ON tutor_profiles
  FOR EACH ROW
  EXECUTE FUNCTION sync_hourly_rate_with_base_price();

DO $$
BEGIN
  RAISE NOTICE 'Created auto-sync trigger for hourly_rate';
END $$;

-- 7. Add helpful comments
COMMENT ON CONSTRAINT tutor_profiles_hourly_rate_check ON tutor_profiles IS 
  'Ensures hourly_rate is between 1000-50000 XAF if set. Prevents corrupted values.';

COMMENT ON CONSTRAINT tutor_profiles_base_session_price_check ON tutor_profiles IS 
  'Ensures base_session_price is between 3000-15000 XAF if set. Required for approved tutors.';

COMMENT ON FUNCTION validate_approved_tutor_data() IS 
  'Validates that approved tutors have required admin_approved_rating and base_session_price set.';

COMMENT ON FUNCTION sync_hourly_rate_with_base_price() IS 
  'Automatically syncs hourly_rate with base_session_price for approved tutors to keep data consistent.';























