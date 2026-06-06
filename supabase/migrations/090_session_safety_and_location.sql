-- Session safety + live location tracking (onsite tutor safety features)

ALTER TABLE public.profiles
  ADD COLUMN IF NOT EXISTS emergency_contact_name TEXT,
  ADD COLUMN IF NOT EXISTS emergency_contact_phone TEXT;

CREATE TABLE IF NOT EXISTS public.session_location_tracking (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  session_id UUID NOT NULL REFERENCES public.individual_sessions(id) ON DELETE CASCADE,
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  user_type TEXT NOT NULL CHECK (user_type IN ('tutor', 'learner', 'student')),
  latitude DOUBLE PRECISION NOT NULL,
  longitude DOUBLE PRECISION NOT NULL,
  accuracy DOUBLE PRECISION,
  last_updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  UNIQUE (session_id, user_id)
);

CREATE INDEX IF NOT EXISTS idx_session_location_tracking_session
  ON public.session_location_tracking(session_id);

CREATE TABLE IF NOT EXISTS public.session_location_history (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  session_id UUID NOT NULL REFERENCES public.individual_sessions(id) ON DELETE CASCADE,
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  user_type TEXT NOT NULL,
  latitude DOUBLE PRECISION NOT NULL,
  longitude DOUBLE PRECISION NOT NULL,
  accuracy DOUBLE PRECISION,
  recorded_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_session_location_history_session
  ON public.session_location_history(session_id, recorded_at DESC);

CREATE TABLE IF NOT EXISTS public.session_safety_records (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  session_id UUID NOT NULL REFERENCES public.individual_sessions(id) ON DELETE CASCADE,
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  user_type TEXT NOT NULL,
  action TEXT NOT NULL CHECK (action IN ('location_shared', 'panic_button_triggered')),
  reason TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_session_safety_records_session
  ON public.session_safety_records(session_id, created_at DESC);

ALTER TABLE public.session_location_tracking ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.session_location_history ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.session_safety_records ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Session participants manage location tracking" ON public.session_location_tracking;
CREATE POLICY "Session participants manage location tracking"
  ON public.session_location_tracking FOR ALL
  USING (
    auth.uid() = user_id
    OR EXISTS (
      SELECT 1 FROM public.individual_sessions s
      WHERE s.id = session_id
        AND (s.tutor_id = auth.uid() OR s.learner_id = auth.uid() OR s.parent_id = auth.uid())
    )
  )
  WITH CHECK (auth.uid() = user_id);

DROP POLICY IF EXISTS "Session participants read location history" ON public.session_location_history;
CREATE POLICY "Session participants read location history"
  ON public.session_location_history FOR SELECT
  USING (
    auth.uid() = user_id
    OR EXISTS (
      SELECT 1 FROM public.individual_sessions s
      WHERE s.id = session_id
        AND (s.tutor_id = auth.uid() OR s.learner_id = auth.uid() OR s.parent_id = auth.uid())
    )
  );

DROP POLICY IF EXISTS "Users insert own location history" ON public.session_location_history;
CREATE POLICY "Users insert own location history"
  ON public.session_location_history FOR INSERT
  WITH CHECK (auth.uid() = user_id);

DROP POLICY IF EXISTS "Users manage own safety records" ON public.session_safety_records;
CREATE POLICY "Users manage own safety records"
  ON public.session_safety_records FOR ALL
  USING (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);

DROP POLICY IF EXISTS "Admins read safety records" ON public.session_safety_records;
CREATE POLICY "Admins read safety records"
  ON public.session_safety_records FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM public.profiles p
      WHERE p.id = auth.uid() AND p.is_admin = true
    )
  );
