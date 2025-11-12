-- ======================================================
-- MIGRATION 022: Normal Recurring Sessions Tables
-- Creates tables for payments, feedback, attendance, and earnings
-- ======================================================

-- ========================================
-- 1. SESSION PAYMENTS TABLE
-- ========================================
-- Links payments to individual sessions
-- Note: individual_sessions table should exist from migration 002
CREATE TABLE IF NOT EXISTS public.session_payments (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  session_id UUID NOT NULL, -- References individual_sessions(id) - will add FK after table exists
  recurring_session_id UUID REFERENCES public.recurring_sessions(id) ON DELETE SET NULL,
  
  -- Payment Details
  session_fee DECIMAL(10, 2) NOT NULL CHECK (session_fee >= 0),
  platform_fee DECIMAL(10, 2) NOT NULL CHECK (platform_fee >= 0), -- 15% of session_fee
  tutor_earnings DECIMAL(10, 2) NOT NULL CHECK (tutor_earnings >= 0), -- 85% of session_fee
  
  -- Payment Status
  payment_status TEXT NOT NULL DEFAULT 'unpaid' CHECK (payment_status IN ('unpaid', 'pending', 'paid', 'failed', 'refunded')),
  payment_id UUID REFERENCES public.payments(id) ON DELETE SET NULL,
  fapshi_trans_id TEXT, -- Fapshi transaction ID
  
  -- Payment Timestamps
  payment_initiated_at TIMESTAMPTZ,
  payment_confirmed_at TIMESTAMPTZ,
  payment_failed_at TIMESTAMPTZ,
  refunded_at TIMESTAMPTZ,
  refund_reason TEXT,
  
  -- Wallet Status
  earnings_added_to_wallet BOOLEAN DEFAULT FALSE,
  wallet_updated_at TIMESTAMPTZ,
  
  -- Timestamps
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_session_payments_session ON public.session_payments(session_id);
CREATE INDEX IF NOT EXISTS idx_session_payments_recurring ON public.session_payments(recurring_session_id);
CREATE INDEX IF NOT EXISTS idx_session_payments_status ON public.session_payments(payment_status);
CREATE INDEX IF NOT EXISTS idx_session_payments_fapshi ON public.session_payments(fapshi_trans_id);

COMMENT ON TABLE public.session_payments IS 'Payment tracking for individual recurring sessions';
COMMENT ON COLUMN public.session_payments.platform_fee IS '15% platform fee (automatically calculated)';
COMMENT ON COLUMN public.session_payments.tutor_earnings IS '85% of session fee (automatically calculated)';

-- ========================================
-- 2. SESSION FEEDBACK TABLE
-- ========================================
-- Stores feedback from both student and tutor
CREATE TABLE IF NOT EXISTS public.session_feedback (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  session_id UUID NOT NULL, -- References individual_sessions(id) - will add FK after table exists
  recurring_session_id UUID REFERENCES public.recurring_sessions(id) ON DELETE SET NULL,
  
  -- Student Feedback
  student_rating INTEGER CHECK (student_rating BETWEEN 1 AND 5),
  student_review TEXT,
  student_what_went_well TEXT,
  student_what_could_improve TEXT,
  student_would_recommend BOOLEAN,
  student_feedback_submitted_at TIMESTAMPTZ,
  
  -- Tutor Feedback
  tutor_notes TEXT, -- General session notes
  tutor_progress_notes TEXT, -- Student progress observations
  tutor_homework_assigned TEXT, -- Homework/assignments given
  tutor_next_focus_areas TEXT, -- What to focus on next session
  tutor_student_engagement INTEGER CHECK (tutor_student_engagement BETWEEN 1 AND 5), -- 1-5 scale
  tutor_feedback_submitted_at TIMESTAMPTZ,
  
  -- Processing
  feedback_processed BOOLEAN DEFAULT FALSE,
  tutor_rating_updated BOOLEAN DEFAULT FALSE, -- Whether tutor's average rating was updated
  review_displayed BOOLEAN DEFAULT FALSE, -- Whether review is shown on tutor profile
  
  -- Timestamps
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_session_feedback_session ON public.session_feedback(session_id);
CREATE INDEX IF NOT EXISTS idx_session_feedback_recurring ON public.session_feedback(recurring_session_id);
CREATE INDEX IF NOT EXISTS idx_session_feedback_rating ON public.session_feedback(student_rating);
CREATE INDEX IF NOT EXISTS idx_session_feedback_processed ON public.session_feedback(feedback_processed);

COMMENT ON TABLE public.session_feedback IS 'Feedback from students and tutors after each session';
COMMENT ON COLUMN public.session_feedback.tutor_student_engagement IS 'Tutor assessment of student engagement (1-5 scale)';

-- ========================================
-- 3. SESSION ATTENDANCE TABLE
-- ========================================
-- Tracks who joined when for attendance monitoring
CREATE TABLE IF NOT EXISTS public.session_attendance (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  session_id UUID NOT NULL, -- References individual_sessions(id) - will add FK after table exists
  
  -- Attendance Details
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  user_type TEXT NOT NULL CHECK (user_type IN ('tutor', 'student', 'parent')),
  
  -- Join/Leave Tracking
  joined_at TIMESTAMPTZ,
  left_at TIMESTAMPTZ,
  duration_minutes INT, -- Calculated duration
  
  -- Attendance Status
  attendance_status TEXT NOT NULL DEFAULT 'pending' CHECK (attendance_status IN ('pending', 'present', 'late', 'no_show', 'left_early')),
  is_late BOOLEAN DEFAULT FALSE,
  late_by_minutes INT, -- Minutes late
  
  -- For Online Sessions
  meet_link_used BOOLEAN DEFAULT FALSE,
  device_type TEXT, -- mobile, desktop, tablet
  connection_quality TEXT, -- good, fair, poor
  
  -- For Onsite Sessions
  check_in_location TEXT, -- GPS coordinates or address
  check_in_verified BOOLEAN DEFAULT FALSE,
  
  -- Timestamps
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_session_attendance_session ON public.session_attendance(session_id);
CREATE INDEX IF NOT EXISTS idx_session_attendance_user ON public.session_attendance(user_id);
CREATE INDEX IF NOT EXISTS idx_session_attendance_status ON public.session_attendance(attendance_status);

COMMENT ON TABLE public.session_attendance IS 'Attendance tracking for individual sessions';
COMMENT ON COLUMN public.session_attendance.attendance_status IS 'pending = not yet started, present = attended, late = joined late, no_show = did not attend, left_early = left before end';

-- ========================================
-- 4. TUTOR EARNINGS TABLE
-- ========================================
-- Tracks earnings per session for tutors
CREATE TABLE IF NOT EXISTS public.tutor_earnings (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  tutor_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  session_id UUID NOT NULL, -- References individual_sessions(id) - will add FK after table exists
  recurring_session_id UUID REFERENCES public.recurring_sessions(id) ON DELETE SET NULL,
  
  -- Earnings Details
  session_fee DECIMAL(10, 2) NOT NULL CHECK (session_fee >= 0),
  platform_fee DECIMAL(10, 2) NOT NULL CHECK (platform_fee >= 0), -- 15%
  tutor_earnings DECIMAL(10, 2) NOT NULL CHECK (tutor_earnings >= 0), -- 85%
  
  -- Status
  earnings_status TEXT NOT NULL DEFAULT 'pending' CHECK (earnings_status IN ('pending', 'active', 'paid_out', 'cancelled')),
  -- pending = session completed, awaiting payment
  -- active = payment confirmed, available for withdrawal
  -- paid_out = withdrawn by tutor
  -- cancelled = session cancelled, no earnings
  
  -- Payment Link
  session_payment_id UUID REFERENCES public.session_payments(id) ON DELETE SET NULL,
  
  -- Wallet Updates
  added_to_pending_balance BOOLEAN DEFAULT FALSE,
  added_to_active_balance BOOLEAN DEFAULT FALSE,
  pending_balance_added_at TIMESTAMPTZ,
  active_balance_added_at TIMESTAMPTZ,
  
  -- Payout
  payout_request_id UUID, -- References payout_requests table (to be created)
  paid_out_at TIMESTAMPTZ,
  
  -- Timestamps
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_tutor_earnings_tutor ON public.tutor_earnings(tutor_id);
CREATE INDEX IF NOT EXISTS idx_tutor_earnings_session ON public.tutor_earnings(session_id);
CREATE INDEX IF NOT EXISTS idx_tutor_earnings_recurring ON public.tutor_earnings(recurring_session_id);
CREATE INDEX IF NOT EXISTS idx_tutor_earnings_status ON public.tutor_earnings(earnings_status);
CREATE INDEX IF NOT EXISTS idx_tutor_earnings_created ON public.tutor_earnings(created_at DESC);

COMMENT ON TABLE public.tutor_earnings IS 'Tracks tutor earnings per session';
COMMENT ON COLUMN public.tutor_earnings.earnings_status IS 'pending = awaiting payment, active = available for withdrawal, paid_out = withdrawn, cancelled = no earnings';

-- ========================================
-- 5. ADD FOREIGN KEY CONSTRAINTS
-- ========================================
-- Add foreign keys after tables are created (if individual_sessions exists)
DO $$
BEGIN
  -- Add FK to session_payments if individual_sessions exists
  IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'individual_sessions' AND table_schema = 'public') THEN
    -- Add foreign key constraint for session_payments
    IF NOT EXISTS (
      SELECT 1 FROM information_schema.table_constraints 
      WHERE constraint_name = 'session_payments_session_id_fkey'
    ) THEN
      ALTER TABLE public.session_payments
      ADD CONSTRAINT session_payments_session_id_fkey
      FOREIGN KEY (session_id) REFERENCES individual_sessions(id) ON DELETE CASCADE;
    END IF;

    -- Add foreign key constraint for session_feedback
    IF NOT EXISTS (
      SELECT 1 FROM information_schema.table_constraints 
      WHERE constraint_name = 'session_feedback_session_id_fkey'
    ) THEN
      ALTER TABLE public.session_feedback
      ADD CONSTRAINT session_feedback_session_id_fkey
      FOREIGN KEY (session_id) REFERENCES individual_sessions(id) ON DELETE CASCADE;
    END IF;

    -- Add foreign key constraint for session_attendance
    IF NOT EXISTS (
      SELECT 1 FROM information_schema.table_constraints 
      WHERE constraint_name = 'session_attendance_session_id_fkey'
    ) THEN
      ALTER TABLE public.session_attendance
      ADD CONSTRAINT session_attendance_session_id_fkey
      FOREIGN KEY (session_id) REFERENCES individual_sessions(id) ON DELETE CASCADE;
    END IF;

    -- Add foreign key constraint for tutor_earnings
    IF NOT EXISTS (
      SELECT 1 FROM information_schema.table_constraints 
      WHERE constraint_name = 'tutor_earnings_session_id_fkey'
    ) THEN
      ALTER TABLE public.tutor_earnings
      ADD CONSTRAINT tutor_earnings_session_id_fkey
      FOREIGN KEY (session_id) REFERENCES individual_sessions(id) ON DELETE CASCADE;
    END IF;

    -- Update individual_sessions table with new columns
    ALTER TABLE individual_sessions
    ADD COLUMN IF NOT EXISTS payment_id UUID REFERENCES public.session_payments(id) ON DELETE SET NULL,
    ADD COLUMN IF NOT EXISTS feedback_id UUID REFERENCES public.session_feedback(id) ON DELETE SET NULL,
    ADD COLUMN IF NOT EXISTS learner_joined_at TIMESTAMPTZ, -- When student joined (for online sessions)
    ADD COLUMN IF NOT EXISTS no_show_detected_at TIMESTAMPTZ, -- When no-show was detected
    ADD COLUMN IF NOT EXISTS cancellation_requested_at TIMESTAMPTZ,
    ADD COLUMN IF NOT EXISTS cancellation_approved_at TIMESTAMPTZ;
  ELSE
    RAISE NOTICE 'individual_sessions table does not exist. Please run migration 002 first.';
  END IF;
END $$;

-- ========================================
-- 6. AUTO-UPDATE TRIGGERS
-- ========================================
-- Function for auto-updating updated_at
CREATE OR REPLACE FUNCTION update_normal_sessions_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Triggers for all tables
DROP TRIGGER IF EXISTS update_session_payments_modtime ON public.session_payments;
CREATE TRIGGER update_session_payments_modtime
  BEFORE UPDATE ON public.session_payments
  FOR EACH ROW
  EXECUTE FUNCTION update_normal_sessions_updated_at();

DROP TRIGGER IF EXISTS update_session_feedback_modtime ON public.session_feedback;
CREATE TRIGGER update_session_feedback_modtime
  BEFORE UPDATE ON public.session_feedback
  FOR EACH ROW
  EXECUTE FUNCTION update_normal_sessions_updated_at();

DROP TRIGGER IF EXISTS update_session_attendance_modtime ON public.session_attendance;
CREATE TRIGGER update_session_attendance_modtime
  BEFORE UPDATE ON public.session_attendance
  FOR EACH ROW
  EXECUTE FUNCTION update_normal_sessions_updated_at();

DROP TRIGGER IF EXISTS update_tutor_earnings_modtime ON public.tutor_earnings;
CREATE TRIGGER update_tutor_earnings_modtime
  BEFORE UPDATE ON public.tutor_earnings
  FOR EACH ROW
  EXECUTE FUNCTION update_normal_sessions_updated_at();

-- ========================================
-- 7. RLS POLICIES
-- ========================================

-- Session Payments
ALTER TABLE public.session_payments ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Users can view their session payments" ON public.session_payments;
CREATE POLICY "Users can view their session payments" ON public.session_payments
  FOR SELECT
  USING (
    -- Tutor can see payments for their sessions
    EXISTS (
      SELECT 1 FROM individual_sessions
      WHERE individual_sessions.id = session_payments.session_id
      AND individual_sessions.tutor_id = auth.uid()
    )
    OR
    -- Student/parent can see payments for their sessions
    EXISTS (
      SELECT 1 FROM individual_sessions
      WHERE individual_sessions.id = session_payments.session_id
      AND (individual_sessions.learner_id = auth.uid() OR individual_sessions.parent_id = auth.uid())
    )
  );

-- Session Feedback
ALTER TABLE public.session_feedback ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Users can view their session feedback" ON public.session_feedback;
CREATE POLICY "Users can view their session feedback" ON public.session_feedback
  FOR SELECT
  USING (
    -- Tutor can see feedback for their sessions
    EXISTS (
      SELECT 1 FROM individual_sessions
      WHERE individual_sessions.id = session_feedback.session_id
      AND individual_sessions.tutor_id = auth.uid()
    )
    OR
    -- Student/parent can see feedback for their sessions
    EXISTS (
      SELECT 1 FROM individual_sessions
      WHERE individual_sessions.id = session_feedback.session_id
      AND (individual_sessions.learner_id = auth.uid() OR individual_sessions.parent_id = auth.uid())
    )
  );

DROP POLICY IF EXISTS "Users can create/update their session feedback" ON public.session_feedback;
CREATE POLICY "Users can create/update their session feedback" ON public.session_feedback
  FOR ALL
  USING (
    -- Tutor can create/update tutor feedback
    EXISTS (
      SELECT 1 FROM individual_sessions
      WHERE individual_sessions.id = session_feedback.session_id
      AND individual_sessions.tutor_id = auth.uid()
    )
    OR
    -- Student/parent can create/update student feedback
    EXISTS (
      SELECT 1 FROM individual_sessions
      WHERE individual_sessions.id = session_feedback.session_id
      AND (individual_sessions.learner_id = auth.uid() OR individual_sessions.parent_id = auth.uid())
    )
  );

-- Session Attendance
ALTER TABLE public.session_attendance ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Users can view their session attendance" ON public.session_attendance;
CREATE POLICY "Users can view their session attendance" ON public.session_attendance
  FOR SELECT
  USING (
    -- Users can see their own attendance
    user_id = auth.uid()
    OR
    -- Tutor can see all attendance for their sessions
    EXISTS (
      SELECT 1 FROM individual_sessions
      WHERE individual_sessions.id = session_attendance.session_id
      AND individual_sessions.tutor_id = auth.uid()
    )
  );

DROP POLICY IF EXISTS "Users can create/update their attendance" ON public.session_attendance;
CREATE POLICY "Users can create/update their attendance" ON public.session_attendance
  FOR ALL
  USING (
    -- Users can create/update their own attendance
    user_id = auth.uid()
    OR
    -- Tutor can create/update attendance for their sessions
    EXISTS (
      SELECT 1 FROM individual_sessions
      WHERE individual_sessions.id = session_attendance.session_id
      AND individual_sessions.tutor_id = auth.uid()
    )
  );

-- Tutor Earnings
ALTER TABLE public.tutor_earnings ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Tutors can view their earnings" ON public.tutor_earnings;
CREATE POLICY "Tutors can view their earnings" ON public.tutor_earnings
  FOR SELECT
  USING (tutor_id = auth.uid());

COMMENT ON SCHEMA public IS 'Normal recurring sessions tables for payments, feedback, attendance, and earnings';


-- Creates tables for payments, feedback, attendance, and earnings
-- ======================================================

-- ========================================
-- 1. SESSION PAYMENTS TABLE
-- ========================================
-- Links payments to individual sessions
-- Note: individual_sessions table should exist from migration 002
CREATE TABLE IF NOT EXISTS public.session_payments (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  session_id UUID NOT NULL, -- References individual_sessions(id) - will add FK after table exists
  recurring_session_id UUID REFERENCES public.recurring_sessions(id) ON DELETE SET NULL,
  
  -- Payment Details
  session_fee DECIMAL(10, 2) NOT NULL CHECK (session_fee >= 0),
  platform_fee DECIMAL(10, 2) NOT NULL CHECK (platform_fee >= 0), -- 15% of session_fee
  tutor_earnings DECIMAL(10, 2) NOT NULL CHECK (tutor_earnings >= 0), -- 85% of session_fee
  
  -- Payment Status
  payment_status TEXT NOT NULL DEFAULT 'unpaid' CHECK (payment_status IN ('unpaid', 'pending', 'paid', 'failed', 'refunded')),
  payment_id UUID REFERENCES public.payments(id) ON DELETE SET NULL,
  fapshi_trans_id TEXT, -- Fapshi transaction ID
  
  -- Payment Timestamps
  payment_initiated_at TIMESTAMPTZ,
  payment_confirmed_at TIMESTAMPTZ,
  payment_failed_at TIMESTAMPTZ,
  refunded_at TIMESTAMPTZ,
  refund_reason TEXT,
  
  -- Wallet Status
  earnings_added_to_wallet BOOLEAN DEFAULT FALSE,
  wallet_updated_at TIMESTAMPTZ,
  
  -- Timestamps
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_session_payments_session ON public.session_payments(session_id);
CREATE INDEX IF NOT EXISTS idx_session_payments_recurring ON public.session_payments(recurring_session_id);
CREATE INDEX IF NOT EXISTS idx_session_payments_status ON public.session_payments(payment_status);
CREATE INDEX IF NOT EXISTS idx_session_payments_fapshi ON public.session_payments(fapshi_trans_id);

COMMENT ON TABLE public.session_payments IS 'Payment tracking for individual recurring sessions';
COMMENT ON COLUMN public.session_payments.platform_fee IS '15% platform fee (automatically calculated)';
COMMENT ON COLUMN public.session_payments.tutor_earnings IS '85% of session fee (automatically calculated)';

-- ========================================
-- 2. SESSION FEEDBACK TABLE
-- ========================================
-- Stores feedback from both student and tutor
CREATE TABLE IF NOT EXISTS public.session_feedback (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  session_id UUID NOT NULL, -- References individual_sessions(id) - will add FK after table exists
  recurring_session_id UUID REFERENCES public.recurring_sessions(id) ON DELETE SET NULL,
  
  -- Student Feedback
  student_rating INTEGER CHECK (student_rating BETWEEN 1 AND 5),
  student_review TEXT,
  student_what_went_well TEXT,
  student_what_could_improve TEXT,
  student_would_recommend BOOLEAN,
  student_feedback_submitted_at TIMESTAMPTZ,
  
  -- Tutor Feedback
  tutor_notes TEXT, -- General session notes
  tutor_progress_notes TEXT, -- Student progress observations
  tutor_homework_assigned TEXT, -- Homework/assignments given
  tutor_next_focus_areas TEXT, -- What to focus on next session
  tutor_student_engagement INTEGER CHECK (tutor_student_engagement BETWEEN 1 AND 5), -- 1-5 scale
  tutor_feedback_submitted_at TIMESTAMPTZ,
  
  -- Processing
  feedback_processed BOOLEAN DEFAULT FALSE,
  tutor_rating_updated BOOLEAN DEFAULT FALSE, -- Whether tutor's average rating was updated
  review_displayed BOOLEAN DEFAULT FALSE, -- Whether review is shown on tutor profile
  
  -- Timestamps
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_session_feedback_session ON public.session_feedback(session_id);
CREATE INDEX IF NOT EXISTS idx_session_feedback_recurring ON public.session_feedback(recurring_session_id);
CREATE INDEX IF NOT EXISTS idx_session_feedback_rating ON public.session_feedback(student_rating);
CREATE INDEX IF NOT EXISTS idx_session_feedback_processed ON public.session_feedback(feedback_processed);

COMMENT ON TABLE public.session_feedback IS 'Feedback from students and tutors after each session';
COMMENT ON COLUMN public.session_feedback.tutor_student_engagement IS 'Tutor assessment of student engagement (1-5 scale)';

-- ========================================
-- 3. SESSION ATTENDANCE TABLE
-- ========================================
-- Tracks who joined when for attendance monitoring
CREATE TABLE IF NOT EXISTS public.session_attendance (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  session_id UUID NOT NULL, -- References individual_sessions(id) - will add FK after table exists
  
  -- Attendance Details
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  user_type TEXT NOT NULL CHECK (user_type IN ('tutor', 'student', 'parent')),
  
  -- Join/Leave Tracking
  joined_at TIMESTAMPTZ,
  left_at TIMESTAMPTZ,
  duration_minutes INT, -- Calculated duration
  
  -- Attendance Status
  attendance_status TEXT NOT NULL DEFAULT 'pending' CHECK (attendance_status IN ('pending', 'present', 'late', 'no_show', 'left_early')),
  is_late BOOLEAN DEFAULT FALSE,
  late_by_minutes INT, -- Minutes late
  
  -- For Online Sessions
  meet_link_used BOOLEAN DEFAULT FALSE,
  device_type TEXT, -- mobile, desktop, tablet
  connection_quality TEXT, -- good, fair, poor
  
  -- For Onsite Sessions
  check_in_location TEXT, -- GPS coordinates or address
  check_in_verified BOOLEAN DEFAULT FALSE,
  
  -- Timestamps
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_session_attendance_session ON public.session_attendance(session_id);
CREATE INDEX IF NOT EXISTS idx_session_attendance_user ON public.session_attendance(user_id);
CREATE INDEX IF NOT EXISTS idx_session_attendance_status ON public.session_attendance(attendance_status);

COMMENT ON TABLE public.session_attendance IS 'Attendance tracking for individual sessions';
COMMENT ON COLUMN public.session_attendance.attendance_status IS 'pending = not yet started, present = attended, late = joined late, no_show = did not attend, left_early = left before end';

-- ========================================
-- 4. TUTOR EARNINGS TABLE
-- ========================================
-- Tracks earnings per session for tutors
CREATE TABLE IF NOT EXISTS public.tutor_earnings (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  tutor_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  session_id UUID NOT NULL, -- References individual_sessions(id) - will add FK after table exists
  recurring_session_id UUID REFERENCES public.recurring_sessions(id) ON DELETE SET NULL,
  
  -- Earnings Details
  session_fee DECIMAL(10, 2) NOT NULL CHECK (session_fee >= 0),
  platform_fee DECIMAL(10, 2) NOT NULL CHECK (platform_fee >= 0), -- 15%
  tutor_earnings DECIMAL(10, 2) NOT NULL CHECK (tutor_earnings >= 0), -- 85%
  
  -- Status
  earnings_status TEXT NOT NULL DEFAULT 'pending' CHECK (earnings_status IN ('pending', 'active', 'paid_out', 'cancelled')),
  -- pending = session completed, awaiting payment
  -- active = payment confirmed, available for withdrawal
  -- paid_out = withdrawn by tutor
  -- cancelled = session cancelled, no earnings
  
  -- Payment Link
  session_payment_id UUID REFERENCES public.session_payments(id) ON DELETE SET NULL,
  
  -- Wallet Updates
  added_to_pending_balance BOOLEAN DEFAULT FALSE,
  added_to_active_balance BOOLEAN DEFAULT FALSE,
  pending_balance_added_at TIMESTAMPTZ,
  active_balance_added_at TIMESTAMPTZ,
  
  -- Payout
  payout_request_id UUID, -- References payout_requests table (to be created)
  paid_out_at TIMESTAMPTZ,
  
  -- Timestamps
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_tutor_earnings_tutor ON public.tutor_earnings(tutor_id);
CREATE INDEX IF NOT EXISTS idx_tutor_earnings_session ON public.tutor_earnings(session_id);
CREATE INDEX IF NOT EXISTS idx_tutor_earnings_recurring ON public.tutor_earnings(recurring_session_id);
CREATE INDEX IF NOT EXISTS idx_tutor_earnings_status ON public.tutor_earnings(earnings_status);
CREATE INDEX IF NOT EXISTS idx_tutor_earnings_created ON public.tutor_earnings(created_at DESC);

COMMENT ON TABLE public.tutor_earnings IS 'Tracks tutor earnings per session';
COMMENT ON COLUMN public.tutor_earnings.earnings_status IS 'pending = awaiting payment, active = available for withdrawal, paid_out = withdrawn, cancelled = no earnings';

-- ========================================
-- 5. ADD FOREIGN KEY CONSTRAINTS
-- ========================================
-- Add foreign keys after tables are created (if individual_sessions exists)
DO $$
BEGIN
  -- Add FK to session_payments if individual_sessions exists
  IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'individual_sessions' AND table_schema = 'public') THEN
    -- Add foreign key constraint for session_payments
    IF NOT EXISTS (
      SELECT 1 FROM information_schema.table_constraints 
      WHERE constraint_name = 'session_payments_session_id_fkey'
    ) THEN
      ALTER TABLE public.session_payments
      ADD CONSTRAINT session_payments_session_id_fkey
      FOREIGN KEY (session_id) REFERENCES individual_sessions(id) ON DELETE CASCADE;
    END IF;

    -- Add foreign key constraint for session_feedback
    IF NOT EXISTS (
      SELECT 1 FROM information_schema.table_constraints 
      WHERE constraint_name = 'session_feedback_session_id_fkey'
    ) THEN
      ALTER TABLE public.session_feedback
      ADD CONSTRAINT session_feedback_session_id_fkey
      FOREIGN KEY (session_id) REFERENCES individual_sessions(id) ON DELETE CASCADE;
    END IF;

    -- Add foreign key constraint for session_attendance
    IF NOT EXISTS (
      SELECT 1 FROM information_schema.table_constraints 
      WHERE constraint_name = 'session_attendance_session_id_fkey'
    ) THEN
      ALTER TABLE public.session_attendance
      ADD CONSTRAINT session_attendance_session_id_fkey
      FOREIGN KEY (session_id) REFERENCES individual_sessions(id) ON DELETE CASCADE;
    END IF;

    -- Add foreign key constraint for tutor_earnings
    IF NOT EXISTS (
      SELECT 1 FROM information_schema.table_constraints 
      WHERE constraint_name = 'tutor_earnings_session_id_fkey'
    ) THEN
      ALTER TABLE public.tutor_earnings
      ADD CONSTRAINT tutor_earnings_session_id_fkey
      FOREIGN KEY (session_id) REFERENCES individual_sessions(id) ON DELETE CASCADE;
    END IF;

    -- Update individual_sessions table with new columns
    ALTER TABLE individual_sessions
    ADD COLUMN IF NOT EXISTS payment_id UUID REFERENCES public.session_payments(id) ON DELETE SET NULL,
    ADD COLUMN IF NOT EXISTS feedback_id UUID REFERENCES public.session_feedback(id) ON DELETE SET NULL,
    ADD COLUMN IF NOT EXISTS learner_joined_at TIMESTAMPTZ, -- When student joined (for online sessions)
    ADD COLUMN IF NOT EXISTS no_show_detected_at TIMESTAMPTZ, -- When no-show was detected
    ADD COLUMN IF NOT EXISTS cancellation_requested_at TIMESTAMPTZ,
    ADD COLUMN IF NOT EXISTS cancellation_approved_at TIMESTAMPTZ;
  ELSE
    RAISE NOTICE 'individual_sessions table does not exist. Please run migration 002 first.';
  END IF;
END $$;

-- ========================================
-- 6. AUTO-UPDATE TRIGGERS
-- ========================================
-- Function for auto-updating updated_at
CREATE OR REPLACE FUNCTION update_normal_sessions_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Triggers for all tables
DROP TRIGGER IF EXISTS update_session_payments_modtime ON public.session_payments;
CREATE TRIGGER update_session_payments_modtime
  BEFORE UPDATE ON public.session_payments
  FOR EACH ROW
  EXECUTE FUNCTION update_normal_sessions_updated_at();

DROP TRIGGER IF EXISTS update_session_feedback_modtime ON public.session_feedback;
CREATE TRIGGER update_session_feedback_modtime
  BEFORE UPDATE ON public.session_feedback
  FOR EACH ROW
  EXECUTE FUNCTION update_normal_sessions_updated_at();

DROP TRIGGER IF EXISTS update_session_attendance_modtime ON public.session_attendance;
CREATE TRIGGER update_session_attendance_modtime
  BEFORE UPDATE ON public.session_attendance
  FOR EACH ROW
  EXECUTE FUNCTION update_normal_sessions_updated_at();

DROP TRIGGER IF EXISTS update_tutor_earnings_modtime ON public.tutor_earnings;
CREATE TRIGGER update_tutor_earnings_modtime
  BEFORE UPDATE ON public.tutor_earnings
  FOR EACH ROW
  EXECUTE FUNCTION update_normal_sessions_updated_at();

-- ========================================
-- 7. RLS POLICIES
-- ========================================

-- Session Payments
ALTER TABLE public.session_payments ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Users can view their session payments" ON public.session_payments;
CREATE POLICY "Users can view their session payments" ON public.session_payments
  FOR SELECT
  USING (
    -- Tutor can see payments for their sessions
    EXISTS (
      SELECT 1 FROM individual_sessions
      WHERE individual_sessions.id = session_payments.session_id
      AND individual_sessions.tutor_id = auth.uid()
    )
    OR
    -- Student/parent can see payments for their sessions
    EXISTS (
      SELECT 1 FROM individual_sessions
      WHERE individual_sessions.id = session_payments.session_id
      AND (individual_sessions.learner_id = auth.uid() OR individual_sessions.parent_id = auth.uid())
    )
  );

-- Session Feedback
ALTER TABLE public.session_feedback ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Users can view their session feedback" ON public.session_feedback;
CREATE POLICY "Users can view their session feedback" ON public.session_feedback
  FOR SELECT
  USING (
    -- Tutor can see feedback for their sessions
    EXISTS (
      SELECT 1 FROM individual_sessions
      WHERE individual_sessions.id = session_feedback.session_id
      AND individual_sessions.tutor_id = auth.uid()
    )
    OR
    -- Student/parent can see feedback for their sessions
    EXISTS (
      SELECT 1 FROM individual_sessions
      WHERE individual_sessions.id = session_feedback.session_id
      AND (individual_sessions.learner_id = auth.uid() OR individual_sessions.parent_id = auth.uid())
    )
  );

DROP POLICY IF EXISTS "Users can create/update their session feedback" ON public.session_feedback;
CREATE POLICY "Users can create/update their session feedback" ON public.session_feedback
  FOR ALL
  USING (
    -- Tutor can create/update tutor feedback
    EXISTS (
      SELECT 1 FROM individual_sessions
      WHERE individual_sessions.id = session_feedback.session_id
      AND individual_sessions.tutor_id = auth.uid()
    )
    OR
    -- Student/parent can create/update student feedback
    EXISTS (
      SELECT 1 FROM individual_sessions
      WHERE individual_sessions.id = session_feedback.session_id
      AND (individual_sessions.learner_id = auth.uid() OR individual_sessions.parent_id = auth.uid())
    )
  );

-- Session Attendance
ALTER TABLE public.session_attendance ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Users can view their session attendance" ON public.session_attendance;
CREATE POLICY "Users can view their session attendance" ON public.session_attendance
  FOR SELECT
  USING (
    -- Users can see their own attendance
    user_id = auth.uid()
    OR
    -- Tutor can see all attendance for their sessions
    EXISTS (
      SELECT 1 FROM individual_sessions
      WHERE individual_sessions.id = session_attendance.session_id
      AND individual_sessions.tutor_id = auth.uid()
    )
  );

DROP POLICY IF EXISTS "Users can create/update their attendance" ON public.session_attendance;
CREATE POLICY "Users can create/update their attendance" ON public.session_attendance
  FOR ALL
  USING (
    -- Users can create/update their own attendance
    user_id = auth.uid()
    OR
    -- Tutor can create/update attendance for their sessions
    EXISTS (
      SELECT 1 FROM individual_sessions
      WHERE individual_sessions.id = session_attendance.session_id
      AND individual_sessions.tutor_id = auth.uid()
    )
  );

-- Tutor Earnings
ALTER TABLE public.tutor_earnings ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Tutors can view their earnings" ON public.tutor_earnings;
CREATE POLICY "Tutors can view their earnings" ON public.tutor_earnings
  FOR SELECT
  USING (tutor_id = auth.uid());

COMMENT ON SCHEMA public IS 'Normal recurring sessions tables for payments, feedback, attendance, and earnings';


-- Creates tables for payments, feedback, attendance, and earnings
-- ======================================================

-- ========================================
-- 1. SESSION PAYMENTS TABLE
-- ========================================
-- Links payments to individual sessions
-- Note: individual_sessions table should exist from migration 002
CREATE TABLE IF NOT EXISTS public.session_payments (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  session_id UUID NOT NULL, -- References individual_sessions(id) - will add FK after table exists
  recurring_session_id UUID REFERENCES public.recurring_sessions(id) ON DELETE SET NULL,
  
  -- Payment Details
  session_fee DECIMAL(10, 2) NOT NULL CHECK (session_fee >= 0),
  platform_fee DECIMAL(10, 2) NOT NULL CHECK (platform_fee >= 0), -- 15% of session_fee
  tutor_earnings DECIMAL(10, 2) NOT NULL CHECK (tutor_earnings >= 0), -- 85% of session_fee
  
  -- Payment Status
  payment_status TEXT NOT NULL DEFAULT 'unpaid' CHECK (payment_status IN ('unpaid', 'pending', 'paid', 'failed', 'refunded')),
  payment_id UUID REFERENCES public.payments(id) ON DELETE SET NULL,
  fapshi_trans_id TEXT, -- Fapshi transaction ID
  
  -- Payment Timestamps
  payment_initiated_at TIMESTAMPTZ,
  payment_confirmed_at TIMESTAMPTZ,
  payment_failed_at TIMESTAMPTZ,
  refunded_at TIMESTAMPTZ,
  refund_reason TEXT,
  
  -- Wallet Status
  earnings_added_to_wallet BOOLEAN DEFAULT FALSE,
  wallet_updated_at TIMESTAMPTZ,
  
  -- Timestamps
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_session_payments_session ON public.session_payments(session_id);
CREATE INDEX IF NOT EXISTS idx_session_payments_recurring ON public.session_payments(recurring_session_id);
CREATE INDEX IF NOT EXISTS idx_session_payments_status ON public.session_payments(payment_status);
CREATE INDEX IF NOT EXISTS idx_session_payments_fapshi ON public.session_payments(fapshi_trans_id);

COMMENT ON TABLE public.session_payments IS 'Payment tracking for individual recurring sessions';
COMMENT ON COLUMN public.session_payments.platform_fee IS '15% platform fee (automatically calculated)';
COMMENT ON COLUMN public.session_payments.tutor_earnings IS '85% of session fee (automatically calculated)';

-- ========================================
-- 2. SESSION FEEDBACK TABLE
-- ========================================
-- Stores feedback from both student and tutor
CREATE TABLE IF NOT EXISTS public.session_feedback (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  session_id UUID NOT NULL, -- References individual_sessions(id) - will add FK after table exists
  recurring_session_id UUID REFERENCES public.recurring_sessions(id) ON DELETE SET NULL,
  
  -- Student Feedback
  student_rating INTEGER CHECK (student_rating BETWEEN 1 AND 5),
  student_review TEXT,
  student_what_went_well TEXT,
  student_what_could_improve TEXT,
  student_would_recommend BOOLEAN,
  student_feedback_submitted_at TIMESTAMPTZ,
  
  -- Tutor Feedback
  tutor_notes TEXT, -- General session notes
  tutor_progress_notes TEXT, -- Student progress observations
  tutor_homework_assigned TEXT, -- Homework/assignments given
  tutor_next_focus_areas TEXT, -- What to focus on next session
  tutor_student_engagement INTEGER CHECK (tutor_student_engagement BETWEEN 1 AND 5), -- 1-5 scale
  tutor_feedback_submitted_at TIMESTAMPTZ,
  
  -- Processing
  feedback_processed BOOLEAN DEFAULT FALSE,
  tutor_rating_updated BOOLEAN DEFAULT FALSE, -- Whether tutor's average rating was updated
  review_displayed BOOLEAN DEFAULT FALSE, -- Whether review is shown on tutor profile
  
  -- Timestamps
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_session_feedback_session ON public.session_feedback(session_id);
CREATE INDEX IF NOT EXISTS idx_session_feedback_recurring ON public.session_feedback(recurring_session_id);
CREATE INDEX IF NOT EXISTS idx_session_feedback_rating ON public.session_feedback(student_rating);
CREATE INDEX IF NOT EXISTS idx_session_feedback_processed ON public.session_feedback(feedback_processed);

COMMENT ON TABLE public.session_feedback IS 'Feedback from students and tutors after each session';
COMMENT ON COLUMN public.session_feedback.tutor_student_engagement IS 'Tutor assessment of student engagement (1-5 scale)';

-- ========================================
-- 3. SESSION ATTENDANCE TABLE
-- ========================================
-- Tracks who joined when for attendance monitoring
CREATE TABLE IF NOT EXISTS public.session_attendance (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  session_id UUID NOT NULL, -- References individual_sessions(id) - will add FK after table exists
  
  -- Attendance Details
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  user_type TEXT NOT NULL CHECK (user_type IN ('tutor', 'student', 'parent')),
  
  -- Join/Leave Tracking
  joined_at TIMESTAMPTZ,
  left_at TIMESTAMPTZ,
  duration_minutes INT, -- Calculated duration
  
  -- Attendance Status
  attendance_status TEXT NOT NULL DEFAULT 'pending' CHECK (attendance_status IN ('pending', 'present', 'late', 'no_show', 'left_early')),
  is_late BOOLEAN DEFAULT FALSE,
  late_by_minutes INT, -- Minutes late
  
  -- For Online Sessions
  meet_link_used BOOLEAN DEFAULT FALSE,
  device_type TEXT, -- mobile, desktop, tablet
  connection_quality TEXT, -- good, fair, poor
  
  -- For Onsite Sessions
  check_in_location TEXT, -- GPS coordinates or address
  check_in_verified BOOLEAN DEFAULT FALSE,
  
  -- Timestamps
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_session_attendance_session ON public.session_attendance(session_id);
CREATE INDEX IF NOT EXISTS idx_session_attendance_user ON public.session_attendance(user_id);
CREATE INDEX IF NOT EXISTS idx_session_attendance_status ON public.session_attendance(attendance_status);

COMMENT ON TABLE public.session_attendance IS 'Attendance tracking for individual sessions';
COMMENT ON COLUMN public.session_attendance.attendance_status IS 'pending = not yet started, present = attended, late = joined late, no_show = did not attend, left_early = left before end';

-- ========================================
-- 4. TUTOR EARNINGS TABLE
-- ========================================
-- Tracks earnings per session for tutors
CREATE TABLE IF NOT EXISTS public.tutor_earnings (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  tutor_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  session_id UUID NOT NULL, -- References individual_sessions(id) - will add FK after table exists
  recurring_session_id UUID REFERENCES public.recurring_sessions(id) ON DELETE SET NULL,
  
  -- Earnings Details
  session_fee DECIMAL(10, 2) NOT NULL CHECK (session_fee >= 0),
  platform_fee DECIMAL(10, 2) NOT NULL CHECK (platform_fee >= 0), -- 15%
  tutor_earnings DECIMAL(10, 2) NOT NULL CHECK (tutor_earnings >= 0), -- 85%
  
  -- Status
  earnings_status TEXT NOT NULL DEFAULT 'pending' CHECK (earnings_status IN ('pending', 'active', 'paid_out', 'cancelled')),
  -- pending = session completed, awaiting payment
  -- active = payment confirmed, available for withdrawal
  -- paid_out = withdrawn by tutor
  -- cancelled = session cancelled, no earnings
  
  -- Payment Link
  session_payment_id UUID REFERENCES public.session_payments(id) ON DELETE SET NULL,
  
  -- Wallet Updates
  added_to_pending_balance BOOLEAN DEFAULT FALSE,
  added_to_active_balance BOOLEAN DEFAULT FALSE,
  pending_balance_added_at TIMESTAMPTZ,
  active_balance_added_at TIMESTAMPTZ,
  
  -- Payout
  payout_request_id UUID, -- References payout_requests table (to be created)
  paid_out_at TIMESTAMPTZ,
  
  -- Timestamps
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_tutor_earnings_tutor ON public.tutor_earnings(tutor_id);
CREATE INDEX IF NOT EXISTS idx_tutor_earnings_session ON public.tutor_earnings(session_id);
CREATE INDEX IF NOT EXISTS idx_tutor_earnings_recurring ON public.tutor_earnings(recurring_session_id);
CREATE INDEX IF NOT EXISTS idx_tutor_earnings_status ON public.tutor_earnings(earnings_status);
CREATE INDEX IF NOT EXISTS idx_tutor_earnings_created ON public.tutor_earnings(created_at DESC);

COMMENT ON TABLE public.tutor_earnings IS 'Tracks tutor earnings per session';
COMMENT ON COLUMN public.tutor_earnings.earnings_status IS 'pending = awaiting payment, active = available for withdrawal, paid_out = withdrawn, cancelled = no earnings';

-- ========================================
-- 5. ADD FOREIGN KEY CONSTRAINTS
-- ========================================
-- Add foreign keys after tables are created (if individual_sessions exists)
DO $$
BEGIN
  -- Add FK to session_payments if individual_sessions exists
  IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'individual_sessions' AND table_schema = 'public') THEN
    -- Add foreign key constraint for session_payments
    IF NOT EXISTS (
      SELECT 1 FROM information_schema.table_constraints 
      WHERE constraint_name = 'session_payments_session_id_fkey'
    ) THEN
      ALTER TABLE public.session_payments
      ADD CONSTRAINT session_payments_session_id_fkey
      FOREIGN KEY (session_id) REFERENCES individual_sessions(id) ON DELETE CASCADE;
    END IF;

    -- Add foreign key constraint for session_feedback
    IF NOT EXISTS (
      SELECT 1 FROM information_schema.table_constraints 
      WHERE constraint_name = 'session_feedback_session_id_fkey'
    ) THEN
      ALTER TABLE public.session_feedback
      ADD CONSTRAINT session_feedback_session_id_fkey
      FOREIGN KEY (session_id) REFERENCES individual_sessions(id) ON DELETE CASCADE;
    END IF;

    -- Add foreign key constraint for session_attendance
    IF NOT EXISTS (
      SELECT 1 FROM information_schema.table_constraints 
      WHERE constraint_name = 'session_attendance_session_id_fkey'
    ) THEN
      ALTER TABLE public.session_attendance
      ADD CONSTRAINT session_attendance_session_id_fkey
      FOREIGN KEY (session_id) REFERENCES individual_sessions(id) ON DELETE CASCADE;
    END IF;

    -- Add foreign key constraint for tutor_earnings
    IF NOT EXISTS (
      SELECT 1 FROM information_schema.table_constraints 
      WHERE constraint_name = 'tutor_earnings_session_id_fkey'
    ) THEN
      ALTER TABLE public.tutor_earnings
      ADD CONSTRAINT tutor_earnings_session_id_fkey
      FOREIGN KEY (session_id) REFERENCES individual_sessions(id) ON DELETE CASCADE;
    END IF;

    -- Update individual_sessions table with new columns
    ALTER TABLE individual_sessions
    ADD COLUMN IF NOT EXISTS payment_id UUID REFERENCES public.session_payments(id) ON DELETE SET NULL,
    ADD COLUMN IF NOT EXISTS feedback_id UUID REFERENCES public.session_feedback(id) ON DELETE SET NULL,
    ADD COLUMN IF NOT EXISTS learner_joined_at TIMESTAMPTZ, -- When student joined (for online sessions)
    ADD COLUMN IF NOT EXISTS no_show_detected_at TIMESTAMPTZ, -- When no-show was detected
    ADD COLUMN IF NOT EXISTS cancellation_requested_at TIMESTAMPTZ,
    ADD COLUMN IF NOT EXISTS cancellation_approved_at TIMESTAMPTZ;
  ELSE
    RAISE NOTICE 'individual_sessions table does not exist. Please run migration 002 first.';
  END IF;
END $$;

-- ========================================
-- 6. AUTO-UPDATE TRIGGERS
-- ========================================
-- Function for auto-updating updated_at
CREATE OR REPLACE FUNCTION update_normal_sessions_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Triggers for all tables
DROP TRIGGER IF EXISTS update_session_payments_modtime ON public.session_payments;
CREATE TRIGGER update_session_payments_modtime
  BEFORE UPDATE ON public.session_payments
  FOR EACH ROW
  EXECUTE FUNCTION update_normal_sessions_updated_at();

DROP TRIGGER IF EXISTS update_session_feedback_modtime ON public.session_feedback;
CREATE TRIGGER update_session_feedback_modtime
  BEFORE UPDATE ON public.session_feedback
  FOR EACH ROW
  EXECUTE FUNCTION update_normal_sessions_updated_at();

DROP TRIGGER IF EXISTS update_session_attendance_modtime ON public.session_attendance;
CREATE TRIGGER update_session_attendance_modtime
  BEFORE UPDATE ON public.session_attendance
  FOR EACH ROW
  EXECUTE FUNCTION update_normal_sessions_updated_at();

DROP TRIGGER IF EXISTS update_tutor_earnings_modtime ON public.tutor_earnings;
CREATE TRIGGER update_tutor_earnings_modtime
  BEFORE UPDATE ON public.tutor_earnings
  FOR EACH ROW
  EXECUTE FUNCTION update_normal_sessions_updated_at();

-- ========================================
-- 7. RLS POLICIES
-- ========================================

-- Session Payments
ALTER TABLE public.session_payments ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Users can view their session payments" ON public.session_payments;
CREATE POLICY "Users can view their session payments" ON public.session_payments
  FOR SELECT
  USING (
    -- Tutor can see payments for their sessions
    EXISTS (
      SELECT 1 FROM individual_sessions
      WHERE individual_sessions.id = session_payments.session_id
      AND individual_sessions.tutor_id = auth.uid()
    )
    OR
    -- Student/parent can see payments for their sessions
    EXISTS (
      SELECT 1 FROM individual_sessions
      WHERE individual_sessions.id = session_payments.session_id
      AND (individual_sessions.learner_id = auth.uid() OR individual_sessions.parent_id = auth.uid())
    )
  );

-- Session Feedback
ALTER TABLE public.session_feedback ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Users can view their session feedback" ON public.session_feedback;
CREATE POLICY "Users can view their session feedback" ON public.session_feedback
  FOR SELECT
  USING (
    -- Tutor can see feedback for their sessions
    EXISTS (
      SELECT 1 FROM individual_sessions
      WHERE individual_sessions.id = session_feedback.session_id
      AND individual_sessions.tutor_id = auth.uid()
    )
    OR
    -- Student/parent can see feedback for their sessions
    EXISTS (
      SELECT 1 FROM individual_sessions
      WHERE individual_sessions.id = session_feedback.session_id
      AND (individual_sessions.learner_id = auth.uid() OR individual_sessions.parent_id = auth.uid())
    )
  );

DROP POLICY IF EXISTS "Users can create/update their session feedback" ON public.session_feedback;
CREATE POLICY "Users can create/update their session feedback" ON public.session_feedback
  FOR ALL
  USING (
    -- Tutor can create/update tutor feedback
    EXISTS (
      SELECT 1 FROM individual_sessions
      WHERE individual_sessions.id = session_feedback.session_id
      AND individual_sessions.tutor_id = auth.uid()
    )
    OR
    -- Student/parent can create/update student feedback
    EXISTS (
      SELECT 1 FROM individual_sessions
      WHERE individual_sessions.id = session_feedback.session_id
      AND (individual_sessions.learner_id = auth.uid() OR individual_sessions.parent_id = auth.uid())
    )
  );

-- Session Attendance
ALTER TABLE public.session_attendance ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Users can view their session attendance" ON public.session_attendance;
CREATE POLICY "Users can view their session attendance" ON public.session_attendance
  FOR SELECT
  USING (
    -- Users can see their own attendance
    user_id = auth.uid()
    OR
    -- Tutor can see all attendance for their sessions
    EXISTS (
      SELECT 1 FROM individual_sessions
      WHERE individual_sessions.id = session_attendance.session_id
      AND individual_sessions.tutor_id = auth.uid()
    )
  );

DROP POLICY IF EXISTS "Users can create/update their attendance" ON public.session_attendance;
CREATE POLICY "Users can create/update their attendance" ON public.session_attendance
  FOR ALL
  USING (
    -- Users can create/update their own attendance
    user_id = auth.uid()
    OR
    -- Tutor can create/update attendance for their sessions
    EXISTS (
      SELECT 1 FROM individual_sessions
      WHERE individual_sessions.id = session_attendance.session_id
      AND individual_sessions.tutor_id = auth.uid()
    )
  );

-- Tutor Earnings
ALTER TABLE public.tutor_earnings ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Tutors can view their earnings" ON public.tutor_earnings;
CREATE POLICY "Tutors can view their earnings" ON public.tutor_earnings
  FOR SELECT
  USING (tutor_id = auth.uid());

COMMENT ON SCHEMA public IS 'Normal recurring sessions tables for payments, feedback, attendance, and earnings';

