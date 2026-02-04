-- ======================================================
-- MIGRATION 051: Multi-learner discount rules (platform-level, admin-configurable)
-- Used for RECURRING/NORMAL tutor bookings when parent books 2+ children with same tutor
-- NOT for trial sessions - trials have fixed pricing regardless of group
-- Discount: 2nd child X% off, 3rd+ Y% off
-- Charge only for accepted sessions; discount applied by learner ordinal at payment time
-- ======================================================

CREATE TABLE IF NOT EXISTS public.multi_learner_discount_rules (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  learner_ordinal INTEGER NOT NULL UNIQUE CHECK (learner_ordinal >= 2),
  discount_percent NUMERIC(5, 2) NOT NULL CHECK (discount_percent >= 0 AND discount_percent <= 100),
  description TEXT,
  is_active BOOLEAN DEFAULT true,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW(),
  updated_by UUID REFERENCES auth.users(id)
);

CREATE INDEX IF NOT EXISTS idx_multi_learner_discount_rules_active
  ON public.multi_learner_discount_rules(is_active)
  WHERE is_active = true;

COMMENT ON TABLE public.multi_learner_discount_rules IS 'Platform discount by learner ordinal for RECURRING sessions (NOT trials): 2 = 2nd learner, 3 = 3rd and beyond (use highest ordinal <= count)';
COMMENT ON COLUMN public.multi_learner_discount_rules.learner_ordinal IS '2 = 2nd learner, 3 = 3rd (and 4th, 5th... use this rule)';
COMMENT ON COLUMN public.multi_learner_discount_rules.discount_percent IS 'Percent off base recurring session price for this ordinal';

-- Default: 2nd learner 15% off, 3rd+ 20% off
INSERT INTO public.multi_learner_discount_rules (learner_ordinal, discount_percent, description)
VALUES
  (2, 15, '2nd learner'),
  (3, 20, '3rd learner and beyond')
ON CONFLICT (learner_ordinal) DO NOTHING;

ALTER TABLE public.multi_learner_discount_rules ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Anyone can view multi_learner_discount_rules" ON public.multi_learner_discount_rules;
DROP POLICY IF EXISTS "Only admins can modify multi_learner_discount_rules" ON public.multi_learner_discount_rules;

CREATE POLICY "Anyone can view multi_learner_discount_rules"
  ON public.multi_learner_discount_rules FOR SELECT
  TO authenticated
  USING (true);

CREATE POLICY "Only admins can modify multi_learner_discount_rules"
  ON public.multi_learner_discount_rules FOR ALL
  TO authenticated
  USING (
    EXISTS (SELECT 1 FROM public.profiles WHERE id = auth.uid() AND is_admin = true)
  )
  WITH CHECK (
    EXISTS (SELECT 1 FROM public.profiles WHERE id = auth.uid() AND is_admin = true)
  );
