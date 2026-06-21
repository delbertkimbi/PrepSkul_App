-- ======================================================
-- MIGRATION 097: Supabase Security Advisor critical fixes
-- - Enable RLS on payment_requests + tutor_transportation_calculations
-- - Convert public views to security_invoker (respect caller RLS)
-- ======================================================

-- ---------- 1. payment_requests RLS ----------
ALTER TABLE public.payment_requests ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Students can view own payment requests" ON public.payment_requests;
DROP POLICY IF EXISTS "Tutors can view own payment requests" ON public.payment_requests;
DROP POLICY IF EXISTS "Students can create payment requests" ON public.payment_requests;
DROP POLICY IF EXISTS "Tutors can create payment requests" ON public.payment_requests;
DROP POLICY IF EXISTS "Students can update own payment requests" ON public.payment_requests;
DROP POLICY IF EXISTS "Admins can view all payment requests" ON public.payment_requests;
DROP POLICY IF EXISTS "Admins can update all payment requests" ON public.payment_requests;

CREATE POLICY "Students can view own payment requests"
  ON public.payment_requests
  FOR SELECT
  TO authenticated
  USING (auth.uid() = student_id);

CREATE POLICY "Tutors can view own payment requests"
  ON public.payment_requests
  FOR SELECT
  TO authenticated
  USING (auth.uid() = tutor_id);

CREATE POLICY "Students can create own payment requests"
  ON public.payment_requests
  FOR INSERT
  TO authenticated
  WITH CHECK (auth.uid() = student_id);

CREATE POLICY "Tutors can create payment requests"
  ON public.payment_requests
  FOR INSERT
  TO authenticated
  WITH CHECK (auth.uid() = tutor_id);

CREATE POLICY "Students can update own payment requests"
  ON public.payment_requests
  FOR UPDATE
  TO authenticated
  USING (auth.uid() = student_id)
  WITH CHECK (auth.uid() = student_id);

CREATE POLICY "Tutors can update own payment requests"
  ON public.payment_requests
  FOR UPDATE
  TO authenticated
  USING (auth.uid() = tutor_id)
  WITH CHECK (auth.uid() = tutor_id);

CREATE POLICY "Admins can view all payment requests"
  ON public.payment_requests
  FOR SELECT
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM public.profiles
      WHERE profiles.id = auth.uid()
        AND profiles.is_admin = true
    )
  );

CREATE POLICY "Admins can update all payment requests"
  ON public.payment_requests
  FOR UPDATE
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM public.profiles
      WHERE profiles.id = auth.uid()
        AND profiles.is_admin = true
    )
  )
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM public.profiles
      WHERE profiles.id = auth.uid()
        AND profiles.is_admin = true
    )
  );

REVOKE ALL ON public.payment_requests FROM anon;
GRANT SELECT, INSERT, UPDATE ON public.payment_requests TO authenticated;
GRANT ALL ON public.payment_requests TO service_role;

-- ---------- 2. tutor_transportation_calculations RLS ----------
ALTER TABLE public.tutor_transportation_calculations ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Tutors can view own transportation calculations" ON public.tutor_transportation_calculations;
DROP POLICY IF EXISTS "Session participants can view transportation calculations" ON public.tutor_transportation_calculations;
DROP POLICY IF EXISTS "Tutors can manage own transportation calculations" ON public.tutor_transportation_calculations;
DROP POLICY IF EXISTS "Admins can manage transportation calculations" ON public.tutor_transportation_calculations;
DROP POLICY IF EXISTS "Service role can manage transportation calculations" ON public.tutor_transportation_calculations;

CREATE POLICY "Tutors can view own transportation calculations"
  ON public.tutor_transportation_calculations
  FOR SELECT
  TO authenticated
  USING (auth.uid() = tutor_id);

CREATE POLICY "Session participants can view transportation calculations"
  ON public.tutor_transportation_calculations
  FOR SELECT
  TO authenticated
  USING (
    EXISTS (
      SELECT 1
      FROM public.individual_sessions s
      WHERE s.id = tutor_transportation_calculations.session_id
        AND (
          auth.uid() = s.parent_id
          OR auth.uid() = s.learner_id
        )
    )
  );

CREATE POLICY "Tutors can manage own transportation calculations"
  ON public.tutor_transportation_calculations
  FOR ALL
  TO authenticated
  USING (auth.uid() = tutor_id)
  WITH CHECK (auth.uid() = tutor_id);

CREATE POLICY "Admins can manage transportation calculations"
  ON public.tutor_transportation_calculations
  FOR ALL
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM public.profiles
      WHERE profiles.id = auth.uid()
        AND profiles.is_admin = true
    )
  )
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM public.profiles
      WHERE profiles.id = auth.uid()
        AND profiles.is_admin = true
    )
  );

CREATE POLICY "Service role can manage transportation calculations"
  ON public.tutor_transportation_calculations
  FOR ALL
  TO service_role
  USING (true)
  WITH CHECK (true);

REVOKE ALL ON public.tutor_transportation_calculations FROM anon;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.tutor_transportation_calculations TO authenticated;
GRANT ALL ON public.tutor_transportation_calculations TO service_role;

-- ---------- 3. Views: security_invoker (respect caller RLS) ----------
ALTER VIEW public.session_timeline_view SET (security_invoker = true);
ALTER VIEW public.session_risk_view SET (security_invoker = true);
ALTER VIEW public.session_eligible_for_payment SET (security_invoker = true);
ALTER VIEW public.skulmate_usage_monthly SET (security_invoker = true);

REVOKE ALL ON public.session_timeline_view FROM anon;
REVOKE ALL ON public.session_risk_view FROM anon;
REVOKE ALL ON public.session_eligible_for_payment FROM anon;
REVOKE ALL ON public.skulmate_usage_monthly FROM anon;

GRANT SELECT ON public.session_timeline_view TO authenticated, service_role;
GRANT SELECT ON public.session_risk_view TO authenticated, service_role;
GRANT SELECT ON public.session_eligible_for_payment TO authenticated, service_role;
GRANT SELECT ON public.skulmate_usage_monthly TO authenticated, service_role;
