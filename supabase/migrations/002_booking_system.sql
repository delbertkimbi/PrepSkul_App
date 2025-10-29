-- =====================================================
-- Migration: Booking System & Monthly Pricing
-- Date: October 29, 2025
-- Description: Add tables and columns for monthly pricing,
--              booking flow, and recurring sessions
-- =====================================================

-- ========================================
-- 1. UPDATE TUTOR PROFILES FOR PRICING
-- ========================================

ALTER TABLE tutor_profiles
ADD COLUMN IF NOT EXISTS per_session_rate DECIMAL(10,2),
ADD COLUMN IF NOT EXISTS visibility_subscription_active BOOLEAN DEFAULT FALSE,
ADD COLUMN IF NOT EXISTS visibility_subscription_expires DATE,
ADD COLUMN IF NOT EXISTS credential_multiplier DECIMAL(3,2) DEFAULT 1.0,
ADD COLUMN IF NOT EXISTS admin_price_override DECIMAL(10,2),
ADD COLUMN IF NOT EXISTS prepskul_certified BOOLEAN DEFAULT FALSE;

COMMENT ON COLUMN tutor_profiles.per_session_rate IS 'Base rate per session (not hourly)';
COMMENT ON COLUMN tutor_profiles.visibility_subscription_active IS 'Paid subscription for better visibility';
COMMENT ON COLUMN tutor_profiles.credential_multiplier IS 'Admin-adjustable credential multiplier';
COMMENT ON COLUMN tutor_profiles.admin_price_override IS 'Admin can manually override calculated price';
COMMENT ON COLUMN tutor_profiles.prepskul_certified IS 'Completed PrepSkul Academy training';

-- ========================================
-- 2. UPDATE LEARNER & PARENT PROFILES
-- ========================================

ALTER TABLE learner_profiles
ADD COLUMN IF NOT EXISTS preferred_schedule JSONB,
ADD COLUMN IF NOT EXISTS preferred_session_frequency INT,
ADD COLUMN IF NOT EXISTS preferred_location TEXT CHECK (preferred_location IN ('online', 'onsite', 'hybrid'));

ALTER TABLE parent_profiles
ADD COLUMN IF NOT EXISTS preferred_schedule JSONB,
ADD COLUMN IF NOT EXISTS preferred_session_frequency INT,
ADD COLUMN IF NOT EXISTS preferred_location TEXT CHECK (preferred_location IN ('online', 'onsite', 'hybrid'));

COMMENT ON COLUMN learner_profiles.preferred_schedule IS 'User preferences from survey (days/times)';
COMMENT ON COLUMN learner_profiles.preferred_session_frequency IS 'Preferred sessions per week';
COMMENT ON COLUMN learner_profiles.preferred_location IS 'Online, onsite, or hybrid preference';

COMMENT ON COLUMN parent_profiles.preferred_schedule IS 'Parent preferences for child (days/times)';
COMMENT ON COLUMN parent_profiles.preferred_session_frequency IS 'Preferred sessions per week';
COMMENT ON COLUMN parent_profiles.preferred_location IS 'Online, onsite, or hybrid preference';

-- ========================================
-- 3. CREATE SESSION REQUESTS TABLE
-- ========================================

CREATE TABLE IF NOT EXISTS session_requests (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  tutor_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  requester_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  requester_type TEXT NOT NULL CHECK (requester_type IN ('student', 'parent')),
  learner_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
  
  -- Session Details
  subject TEXT NOT NULL,
  session_frequency INT NOT NULL CHECK (session_frequency > 0),
  total_monthly_sessions INT NOT NULL CHECK (total_monthly_sessions > 0),
  
  -- Schedule (JSONB for flexibility)
  requested_schedule JSONB NOT NULL,
  -- Example: [{"day": "Monday", "time": "15:00", "duration": 60, "location": "online"}, ...]
  
  -- Location
  location_preference TEXT NOT NULL CHECK (location_preference IN ('online', 'onsite', 'hybrid')),
  onsite_address TEXT,
  onsite_city TEXT,
  onsite_quarter TEXT,
  
  -- Payment
  monthly_total DECIMAL(10,2) NOT NULL CHECK (monthly_total > 0),
  per_session_rate DECIMAL(10,2) NOT NULL CHECK (per_session_rate > 0),
  payment_plan TEXT NOT NULL CHECK (payment_plan IN ('monthly', 'biweekly', 'weekly')),
  discount_percent DECIMAL(5,2) DEFAULT 0,
  final_amount DECIMAL(10,2) NOT NULL CHECK (final_amount > 0),
  
  -- Request Details
  learner_survey_data JSONB,
  special_requests TEXT,
  
  -- Status
  status TEXT DEFAULT 'pending' CHECK (status IN ('pending', 'approved', 'rejected', 'modified', 'cancelled', 'expired')),
  tutor_response_notes TEXT,
  modified_schedule JSONB,
  rejection_reason TEXT,
  
  -- Timestamps
  created_at TIMESTAMPTZ DEFAULT NOW(),
  responded_at TIMESTAMPTZ,
  expires_at TIMESTAMPTZ DEFAULT NOW() + INTERVAL '7 days'
);

CREATE INDEX idx_session_requests_tutor_id ON session_requests(tutor_id);
CREATE INDEX idx_session_requests_requester_id ON session_requests(requester_id);
CREATE INDEX idx_session_requests_status ON session_requests(status);
CREATE INDEX idx_session_requests_created_at ON session_requests(created_at DESC);

COMMENT ON TABLE session_requests IS 'Pending booking requests from students/parents to tutors';
COMMENT ON COLUMN session_requests.requested_schedule IS 'JSON array of schedule objects with day, time, duration, location';
COMMENT ON COLUMN session_requests.learner_survey_data IS 'Relevant survey responses to help tutor decide';
COMMENT ON COLUMN session_requests.modified_schedule IS 'Tutor-proposed alternative schedule';

-- ========================================
-- 4. CREATE RECURRING SESSIONS TABLE
-- ========================================

CREATE TABLE IF NOT EXISTS recurring_sessions (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  request_id UUID REFERENCES session_requests(id) ON DELETE SET NULL,
  tutor_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  learner_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  parent_id UUID REFERENCES auth.users(id) ON DELETE SET NULL,
  
  -- Subject & Details
  subject TEXT NOT NULL,
  
  -- Schedule
  weekly_schedule JSONB NOT NULL,
  -- Example: [{"day": "Monday", "time": "15:00", "duration": 60, "location": "online"}, ...]
  
  -- Location
  location_preference TEXT NOT NULL CHECK (location_preference IN ('online', 'onsite', 'hybrid')),
  onsite_address TEXT,
  
  -- Payment
  monthly_total DECIMAL(10,2) NOT NULL CHECK (monthly_total > 0),
  per_session_rate DECIMAL(10,2) NOT NULL CHECK (per_session_rate > 0),
  payment_plan TEXT NOT NULL CHECK (payment_plan IN ('monthly', 'biweekly', 'weekly')),
  next_payment_due DATE,
  
  -- Credits
  credits_allocated INT DEFAULT 0 CHECK (credits_allocated >= 0),
  credits_used INT DEFAULT 0 CHECK (credits_used >= 0),
  
  -- Status
  is_active BOOLEAN DEFAULT TRUE,
  start_date DATE NOT NULL,
  end_date DATE,
  pause_reason TEXT,
  
  -- Timestamps
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_recurring_sessions_tutor_id ON recurring_sessions(tutor_id);
CREATE INDEX idx_recurring_sessions_learner_id ON recurring_sessions(learner_id);
CREATE INDEX idx_recurring_sessions_is_active ON recurring_sessions(is_active);
CREATE INDEX idx_recurring_sessions_start_date ON recurring_sessions(start_date DESC);

COMMENT ON TABLE recurring_sessions IS 'Confirmed ongoing tutoring arrangements';
COMMENT ON COLUMN recurring_sessions.weekly_schedule IS 'JSON array of weekly recurring schedule';
COMMENT ON COLUMN recurring_sessions.credits_allocated IS 'Sessions paid for';
COMMENT ON COLUMN recurring_sessions.credits_used IS 'Sessions completed';

-- ========================================
-- 5. CREATE INDIVIDUAL SESSIONS TABLE
-- ========================================

CREATE TABLE IF NOT EXISTS individual_sessions (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  recurring_session_id UUID REFERENCES recurring_sessions(id) ON DELETE CASCADE,
  tutor_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  learner_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  parent_id UUID REFERENCES auth.users(id) ON DELETE SET NULL,
  
  -- Session Details
  subject TEXT NOT NULL,
  scheduled_date DATE NOT NULL,
  scheduled_time TIME NOT NULL,
  duration_minutes INT NOT NULL CHECK (duration_minutes > 0),
  location TEXT NOT NULL CHECK (location IN ('online', 'onsite')),
  onsite_address TEXT,
  meeting_link TEXT,
  
  -- Status
  status TEXT DEFAULT 'scheduled' CHECK (status IN ('scheduled', 'in_progress', 'completed', 'cancelled', 'no_show_tutor', 'no_show_learner')),
  cancellation_reason TEXT,
  cancelled_by UUID REFERENCES auth.users(id) ON DELETE SET NULL,
  
  -- Attendance
  tutor_joined_at TIMESTAMPTZ,
  learner_joined_at TIMESTAMPTZ,
  session_started_at TIMESTAMPTZ,
  session_ended_at TIMESTAMPTZ,
  actual_duration_minutes INT,
  
  -- Notes
  session_notes TEXT,
  homework_assigned TEXT,
  
  -- Timestamps
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_individual_sessions_tutor_id ON individual_sessions(tutor_id);
CREATE INDEX idx_individual_sessions_learner_id ON individual_sessions(learner_id);
CREATE INDEX idx_individual_sessions_scheduled_date ON individual_sessions(scheduled_date DESC);
CREATE INDEX idx_individual_sessions_status ON individual_sessions(status);

COMMENT ON TABLE individual_sessions IS 'Each individual session instance (generated from recurring_sessions)';

-- ========================================
-- 6. UPDATE PAYMENTS TABLE
-- ========================================

ALTER TABLE payments
ADD COLUMN IF NOT EXISTS recurring_session_id UUID REFERENCES recurring_sessions(id) ON DELETE SET NULL,
ADD COLUMN IF NOT EXISTS credits_purchased INT CHECK (credits_purchased >= 0),
ADD COLUMN IF NOT EXISTS payment_plan TEXT CHECK (payment_plan IN ('monthly', 'biweekly', 'weekly', 'one_time'));

COMMENT ON COLUMN payments.recurring_session_id IS 'Linked recurring session for subscription payments';
COMMENT ON COLUMN payments.credits_purchased IS 'Number of session credits purchased';
COMMENT ON COLUMN payments.payment_plan IS 'Payment frequency for recurring sessions';

-- ========================================
-- 7. CREATE TRIAL SESSIONS TABLE
-- ========================================

CREATE TABLE IF NOT EXISTS trial_sessions (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  tutor_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  learner_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  parent_id UUID REFERENCES auth.users(id) ON DELETE SET NULL,
  requester_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  
  -- Session Details
  subject TEXT NOT NULL,
  scheduled_date DATE NOT NULL,
  scheduled_time TIME NOT NULL,
  duration_minutes INT NOT NULL CHECK (duration_minutes IN (30, 60)),
  location TEXT NOT NULL CHECK (location IN ('online', 'onsite')),
  
  -- Trial Details
  trial_goal TEXT,
  learner_challenges TEXT,
  learner_level TEXT,
  
  -- Status
  status TEXT DEFAULT 'pending' CHECK (status IN ('pending', 'approved', 'rejected', 'scheduled', 'completed', 'cancelled', 'no_show')),
  tutor_response_notes TEXT,
  rejection_reason TEXT,
  
  -- Payment
  trial_fee DECIMAL(10,2) NOT NULL CHECK (trial_fee >= 0),
  payment_status TEXT DEFAULT 'unpaid' CHECK (payment_status IN ('unpaid', 'paid', 'refunded')),
  payment_id UUID REFERENCES payments(id) ON DELETE SET NULL,
  
  -- Outcome
  converted_to_recurring BOOLEAN DEFAULT FALSE,
  recurring_session_id UUID REFERENCES recurring_sessions(id) ON DELETE SET NULL,
  
  -- Timestamps
  created_at TIMESTAMPTZ DEFAULT NOW(),
  responded_at TIMESTAMPTZ,
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_trial_sessions_tutor_id ON trial_sessions(tutor_id);
CREATE INDEX idx_trial_sessions_learner_id ON trial_sessions(learner_id);
CREATE INDEX idx_trial_sessions_status ON trial_sessions(status);
CREATE INDEX idx_trial_sessions_scheduled_date ON trial_sessions(scheduled_date DESC);

COMMENT ON TABLE trial_sessions IS 'Trial session requests and outcomes';
COMMENT ON COLUMN trial_sessions.converted_to_recurring IS 'Did trial lead to booking?';

-- ========================================
-- 8. CREATE FUNCTIONS FOR AUTO-UPDATES
-- ========================================

-- Function to update updated_at timestamp
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Triggers for updated_at
CREATE TRIGGER update_recurring_sessions_updated_at BEFORE UPDATE ON recurring_sessions
  FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_individual_sessions_updated_at BEFORE UPDATE ON individual_sessions
  FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_trial_sessions_updated_at BEFORE UPDATE ON trial_sessions
  FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- Function to auto-expire old requests
CREATE OR REPLACE FUNCTION expire_old_session_requests()
RETURNS void AS $$
BEGIN
  UPDATE session_requests
  SET status = 'expired'
  WHERE status = 'pending'
    AND expires_at < NOW();
END;
$$ LANGUAGE plpgsql;

-- ========================================
-- 9. ROW LEVEL SECURITY (RLS) POLICIES
-- ========================================

-- Enable RLS on new tables
ALTER TABLE session_requests ENABLE ROW LEVEL SECURITY;
ALTER TABLE recurring_sessions ENABLE ROW LEVEL SECURITY;
ALTER TABLE individual_sessions ENABLE ROW LEVEL SECURITY;
ALTER TABLE trial_sessions ENABLE ROW LEVEL SECURITY;

-- Session Requests Policies
CREATE POLICY "Users can view their own session requests"
  ON session_requests FOR SELECT
  USING (auth.uid() = requester_id OR auth.uid() = tutor_id);

CREATE POLICY "Users can create their own session requests"
  ON session_requests FOR INSERT
  WITH CHECK (auth.uid() = requester_id);

CREATE POLICY "Tutors can update requests sent to them"
  ON session_requests FOR UPDATE
  USING (auth.uid() = tutor_id);

CREATE POLICY "Requesters can cancel their own requests"
  ON session_requests FOR UPDATE
  USING (auth.uid() = requester_id AND status = 'pending');

-- Recurring Sessions Policies
CREATE POLICY "Users can view their own recurring sessions"
  ON recurring_sessions FOR SELECT
  USING (auth.uid() = tutor_id OR auth.uid() = learner_id OR auth.uid() = parent_id);

CREATE POLICY "System can create recurring sessions"
  ON recurring_sessions FOR INSERT
  WITH CHECK (true);

CREATE POLICY "Participants can update their recurring sessions"
  ON recurring_sessions FOR UPDATE
  USING (auth.uid() = tutor_id OR auth.uid() = learner_id OR auth.uid() = parent_id);

-- Individual Sessions Policies
CREATE POLICY "Users can view their own sessions"
  ON individual_sessions FOR SELECT
  USING (auth.uid() = tutor_id OR auth.uid() = learner_id OR auth.uid() = parent_id);

CREATE POLICY "Participants can update their sessions"
  ON individual_sessions FOR UPDATE
  USING (auth.uid() = tutor_id OR auth.uid() = learner_id);

-- Trial Sessions Policies
CREATE POLICY "Users can view their own trial sessions"
  ON trial_sessions FOR SELECT
  USING (auth.uid() = requester_id OR auth.uid() = tutor_id);

CREATE POLICY "Users can create their own trial requests"
  ON trial_sessions FOR INSERT
  WITH CHECK (auth.uid() = requester_id);

CREATE POLICY "Tutors can respond to trial requests"
  ON trial_sessions FOR UPDATE
  USING (auth.uid() = tutor_id);

-- ========================================
-- 10. SAMPLE DATA (for testing)
-- ========================================

-- You can uncomment this to add sample data for testing

/*
-- Update existing tutors with per-session rates
UPDATE tutor_profiles
SET per_session_rate = hourly_rate
WHERE per_session_rate IS NULL;

-- Example: Add visibility subscription to top tutor
UPDATE tutor_profiles
SET visibility_subscription_active = TRUE,
    visibility_subscription_expires = NOW() + INTERVAL '30 days',
    prepskul_certified = TRUE
WHERE id = (SELECT id FROM tutor_profiles ORDER BY rating DESC LIMIT 1);
*/

-- ========================================
-- END OF MIGRATION
-- ========================================

