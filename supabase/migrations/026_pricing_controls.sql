-- Migration: Pricing Controls for Admin Dashboard
-- Allows admins to set trial session pricing and tutor discounts

-- Table for trial session pricing controls
CREATE TABLE IF NOT EXISTS trial_session_pricing (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  duration_minutes INTEGER NOT NULL UNIQUE CHECK (duration_minutes IN (30, 60)),
  price_xaf INTEGER NOT NULL CHECK (price_xaf > 0),
  is_active BOOLEAN DEFAULT true,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW(),
  updated_by UUID REFERENCES auth.users(id)
);

-- Insert default trial session pricing
INSERT INTO trial_session_pricing (duration_minutes, price_xaf) 
VALUES 
  (30, 2000),
  (60, 3500)
ON CONFLICT (duration_minutes) DO NOTHING;

-- Table for tutor discount rules
CREATE TABLE IF NOT EXISTS tutor_discount_rules (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name TEXT NOT NULL,
  description TEXT,
  discount_percent NUMERIC(5, 2) NOT NULL CHECK (discount_percent >= 0 AND discount_percent <= 100),
  discount_amount_xaf INTEGER CHECK (discount_amount_xaf >= 0),
  -- Rule criteria (JSONB for flexibility)
  criteria JSONB NOT NULL DEFAULT '{}',
  -- Examples:
  -- {"rating_min": 4.5, "rating_max": 5.0} - for rating-based discounts
  -- {"qualification": "PhD"} - for qualification-based
  -- {"subject": "Mathematics"} - for subject-based
  -- {"all": true} - for platform-wide discounts
  is_active BOOLEAN DEFAULT true,
  starts_at TIMESTAMPTZ,
  ends_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW(),
  updated_by UUID REFERENCES auth.users(id)
);

-- Index for active discount rules
CREATE INDEX IF NOT EXISTS idx_tutor_discount_rules_active 
ON tutor_discount_rules(is_active, starts_at, ends_at) 
WHERE is_active = true;

-- Function to get active discount for a tutor
CREATE OR REPLACE FUNCTION get_tutor_discount(
  tutor_rating NUMERIC,
  tutor_qualification TEXT,
  tutor_subjects TEXT[],
  tutor_base_price NUMERIC
) RETURNS TABLE (
  discount_percent NUMERIC,
  discount_amount_xaf INTEGER,
  final_price NUMERIC
) AS $$
BEGIN
  RETURN QUERY
  SELECT 
    dr.discount_percent,
    dr.discount_amount_xaf,
    CASE 
      WHEN dr.discount_percent > 0 THEN 
        tutor_base_price * (1 - dr.discount_percent / 100)
      WHEN dr.discount_amount_xaf > 0 THEN 
        GREATEST(0, tutor_base_price - dr.discount_amount_xaf)
      ELSE 
        tutor_base_price
    END as final_price
  FROM tutor_discount_rules dr
  WHERE dr.is_active = true
    AND (dr.starts_at IS NULL OR dr.starts_at <= NOW())
    AND (dr.ends_at IS NULL OR dr.ends_at >= NOW())
    AND (
      -- Check if rule applies to all tutors
      (dr.criteria->>'all')::boolean = true
      OR
      -- Check rating criteria
      (
        (dr.criteria->>'rating_min')::numeric IS NULL OR tutor_rating >= (dr.criteria->>'rating_min')::numeric
      ) AND (
        (dr.criteria->>'rating_max')::numeric IS NULL OR tutor_rating <= (dr.criteria->>'rating_max')::numeric
      )
      OR
      -- Check qualification criteria
      (
        dr.criteria->>'qualification' IS NOT NULL 
        AND tutor_qualification ILIKE '%' || (dr.criteria->>'qualification') || '%'
      )
      OR
      -- Check subject criteria
      (
        dr.criteria->>'subject' IS NOT NULL 
        AND EXISTS (
          SELECT 1 FROM unnest(tutor_subjects) AS subject 
          WHERE subject ILIKE '%' || (dr.criteria->>'subject') || '%'
        )
      )
    )
  ORDER BY 
    -- Prioritize percentage discounts over fixed amounts
    CASE WHEN dr.discount_percent > 0 THEN 1 ELSE 2 END,
    -- Prioritize higher discounts
    dr.discount_percent DESC NULLS LAST,
    dr.discount_amount_xaf DESC NULLS LAST
  LIMIT 1;
END;
$$ LANGUAGE plpgsql;

-- Add discount columns to tutor_profiles for caching
ALTER TABLE tutor_profiles 
ADD COLUMN IF NOT EXISTS discount_percent NUMERIC(5, 2) DEFAULT 0,
ADD COLUMN IF NOT EXISTS discount_amount_xaf INTEGER DEFAULT 0,
ADD COLUMN IF NOT EXISTS discounted_price NUMERIC(10, 2),
ADD COLUMN IF NOT EXISTS discount_rule_id UUID REFERENCES tutor_discount_rules(id);

-- Create index for discount updates
CREATE INDEX IF NOT EXISTS idx_tutor_profiles_discount 
ON tutor_profiles(discount_rule_id) 
WHERE discount_rule_id IS NOT NULL;

-- Function to update tutor discounts (can be called by admin or scheduled job)
CREATE OR REPLACE FUNCTION update_tutor_discounts() RETURNS void AS $$
DECLARE
  tutor_record RECORD;
  discount_result RECORD;
BEGIN
  FOR tutor_record IN 
    SELECT 
      tp.user_id,
      tp.base_session_price,
      tp.admin_approved_rating,
      tp.tutor_qualification,
      ARRAY(
        SELECT DISTINCT unnest(string_to_array(COALESCE(tp.subjects, ''), ','))
      ) as subjects_array
    FROM tutor_profiles tp
    WHERE tp.status = 'approved'
  LOOP
    -- Get active discount for this tutor
    SELECT * INTO discount_result
    FROM get_tutor_discount(
      tutor_record.admin_approved_rating,
      tutor_record.tutor_qualification,
      tutor_record.subjects_array,
      tutor_record.base_session_price
    )
    LIMIT 1;

    -- Update tutor profile with discount info
    UPDATE tutor_profiles
    SET 
      discount_percent = COALESCE(discount_result.discount_percent, 0),
      discount_amount_xaf = COALESCE(discount_result.discount_amount_xaf, 0),
      discounted_price = COALESCE(discount_result.final_price, tutor_record.base_session_price),
      updated_at = NOW()
    WHERE user_id = tutor_record.user_id
      AND (
        discount_percent IS DISTINCT FROM COALESCE(discount_result.discount_percent, 0)
        OR discount_amount_xaf IS DISTINCT FROM COALESCE(discount_result.discount_amount_xaf, 0)
        OR discounted_price IS DISTINCT FROM COALESCE(discount_result.final_price, tutor_record.base_session_price)
      );
  END LOOP;
END;
$$ LANGUAGE plpgsql;

-- Enable RLS
ALTER TABLE trial_session_pricing ENABLE ROW LEVEL SECURITY;
ALTER TABLE tutor_discount_rules ENABLE ROW LEVEL SECURITY;

-- RLS Policies for trial_session_pricing (read-only for authenticated, admin-only for write)
-- Drop existing policies if they exist (for idempotency)
DROP POLICY IF EXISTS "Anyone can view trial session pricing" ON trial_session_pricing;
DROP POLICY IF EXISTS "Only admins can modify trial session pricing" ON trial_session_pricing;

CREATE POLICY "Anyone can view trial session pricing"
  ON trial_session_pricing FOR SELECT
  USING (true);

CREATE POLICY "Only admins can modify trial session pricing"
  ON trial_session_pricing FOR ALL
  USING (
    EXISTS (
      SELECT 1 FROM profiles 
      WHERE profiles.id = auth.uid() 
      AND profiles.user_type = 'admin'
    )
  );

-- RLS Policies for tutor_discount_rules (read-only for authenticated, admin-only for write)
-- Drop existing policies if they exist (for idempotency)
DROP POLICY IF EXISTS "Anyone can view discount rules" ON tutor_discount_rules;
DROP POLICY IF EXISTS "Only admins can modify discount rules" ON tutor_discount_rules;

CREATE POLICY "Anyone can view discount rules"
  ON tutor_discount_rules FOR SELECT
  USING (true);

CREATE POLICY "Only admins can modify discount rules"
  ON tutor_discount_rules FOR ALL
  USING (
    EXISTS (
      SELECT 1 FROM profiles 
      WHERE profiles.id = auth.uid() 
      AND profiles.user_type = 'admin'
    )
  );

-- Comments
COMMENT ON TABLE trial_session_pricing IS 'Admin-controlled trial session pricing';
COMMENT ON TABLE tutor_discount_rules IS 'Admin-controlled discount rules for tutors';
COMMENT ON FUNCTION get_tutor_discount IS 'Returns active discount for a tutor based on criteria';
COMMENT ON FUNCTION update_tutor_discounts IS 'Updates all tutor profiles with current discount information';

