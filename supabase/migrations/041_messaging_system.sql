-- ======================================================
-- MIGRATION 041: Messaging System
-- Creates tables for conversations, messages, flagged messages, and user violations
-- ======================================================

-- ========================================
-- 1. CONVERSATIONS TABLE
-- ========================================

CREATE TABLE IF NOT EXISTS public.conversations (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  student_id UUID REFERENCES public.profiles(id) ON DELETE CASCADE NOT NULL,
  tutor_id UUID REFERENCES public.profiles(id) ON DELETE CASCADE NOT NULL,
  
  -- Context linking (one of these will be set)
  trial_session_id UUID REFERENCES public.trial_sessions(id) ON DELETE SET NULL,
  booking_request_id UUID REFERENCES public.booking_requests(id) ON DELETE SET NULL,
  recurring_session_id UUID REFERENCES public.recurring_sessions(id) ON DELETE SET NULL,
  individual_session_id UUID REFERENCES public.individual_sessions(id) ON DELETE SET NULL,
  
  -- Lifecycle
  status VARCHAR(20) DEFAULT 'active' CHECK (status IN ('active', 'expired', 'closed', 'blocked')),
  expires_at TIMESTAMPTZ, -- Auto-close after inactivity (e.g., 30 days after trial)
  last_message_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW(),
  
  -- Constraints
  CONSTRAINT one_context CHECK (
    (trial_session_id IS NOT NULL)::int +
    (booking_request_id IS NOT NULL)::int +
    (recurring_session_id IS NOT NULL)::int +
    (individual_session_id IS NOT NULL)::int = 1
  )
);

-- Indexes for conversations
CREATE INDEX IF NOT EXISTS idx_conversations_student ON public.conversations(student_id);
CREATE INDEX IF NOT EXISTS idx_conversations_tutor ON public.conversations(tutor_id);
CREATE INDEX IF NOT EXISTS idx_conversations_trial ON public.conversations(trial_session_id) WHERE trial_session_id IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_conversations_booking ON public.conversations(booking_request_id) WHERE booking_request_id IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_conversations_recurring ON public.conversations(recurring_session_id) WHERE recurring_session_id IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_conversations_individual ON public.conversations(individual_session_id) WHERE individual_session_id IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_conversations_status ON public.conversations(status);
CREATE INDEX IF NOT EXISTS idx_conversations_last_message ON public.conversations(last_message_at DESC NULLS LAST);
CREATE INDEX IF NOT EXISTS idx_conversations_expires ON public.conversations(expires_at) WHERE expires_at IS NOT NULL;

-- Unique constraints to ensure one conversation per context
CREATE UNIQUE INDEX IF NOT EXISTS idx_unique_trial_conversation ON public.conversations(trial_session_id) WHERE trial_session_id IS NOT NULL;
CREATE UNIQUE INDEX IF NOT EXISTS idx_unique_booking_conversation ON public.conversations(booking_request_id) WHERE booking_request_id IS NOT NULL;
CREATE UNIQUE INDEX IF NOT EXISTS idx_unique_recurring_conversation ON public.conversations(recurring_session_id) WHERE recurring_session_id IS NOT NULL;
CREATE UNIQUE INDEX IF NOT EXISTS idx_unique_individual_conversation ON public.conversations(individual_session_id) WHERE individual_session_id IS NOT NULL;

-- ========================================
-- 2. MESSAGES TABLE
-- ========================================

CREATE TABLE IF NOT EXISTS public.messages (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  conversation_id UUID REFERENCES public.conversations(id) ON DELETE CASCADE NOT NULL,
  sender_id UUID REFERENCES public.profiles(id) ON DELETE CASCADE NOT NULL,
  content TEXT NOT NULL,
  
  -- Read receipts
  is_read BOOLEAN DEFAULT FALSE,
  read_at TIMESTAMPTZ,
  
  -- Moderation
  is_filtered BOOLEAN DEFAULT FALSE,
  filter_reason VARCHAR(100), -- phone_number, email, payment_request, etc.
  moderation_status VARCHAR(20) DEFAULT 'approved' CHECK (moderation_status IN ('pending', 'approved', 'flagged')),
  
  -- Metadata
  created_at TIMESTAMPTZ DEFAULT NOW(),
  
  -- Constraints
  CONSTRAINT message_not_empty CHECK (LENGTH(TRIM(content)) > 0)
);

-- Indexes for messages
CREATE INDEX IF NOT EXISTS idx_messages_conversation ON public.messages(conversation_id);
CREATE INDEX IF NOT EXISTS idx_messages_sender ON public.messages(sender_id);
CREATE INDEX IF NOT EXISTS idx_messages_created ON public.messages(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_messages_unread ON public.messages(conversation_id, is_read) WHERE is_read = FALSE;
CREATE INDEX IF NOT EXISTS idx_messages_moderation ON public.messages(moderation_status) WHERE moderation_status != 'approved';

-- ========================================
-- 3. FLAGGED MESSAGES TABLE
-- ========================================

CREATE TABLE IF NOT EXISTS public.flagged_messages (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  conversation_id UUID REFERENCES public.conversations(id) ON DELETE CASCADE,
  sender_id UUID REFERENCES public.profiles(id) ON DELETE CASCADE,
  content TEXT NOT NULL, -- Original message content
  flags JSONB NOT NULL, -- Array of detected flags
  status VARCHAR(20) DEFAULT 'review' CHECK (status IN ('review', 'approved', 'blocked', 'resolved')),
  severity VARCHAR(20) CHECK (severity IN ('low', 'medium', 'high', 'critical')),
  reviewed_by UUID REFERENCES public.profiles(id),
  reviewed_at TIMESTAMPTZ,
  review_notes TEXT,
  action_taken VARCHAR(50), -- none, warning, mute_24h, mute_7d, ban
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Indexes for flagged messages
CREATE INDEX IF NOT EXISTS idx_flagged_messages_conversation ON public.flagged_messages(conversation_id);
CREATE INDEX IF NOT EXISTS idx_flagged_messages_sender ON public.flagged_messages(sender_id);
CREATE INDEX IF NOT EXISTS idx_flagged_messages_status ON public.flagged_messages(status);
CREATE INDEX IF NOT EXISTS idx_flagged_messages_severity ON public.flagged_messages(severity);
CREATE INDEX IF NOT EXISTS idx_flagged_messages_created ON public.flagged_messages(created_at DESC);

-- ========================================
-- 4. USER VIOLATIONS TABLE
-- ========================================

CREATE TABLE IF NOT EXISTS public.user_violations (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id UUID REFERENCES public.profiles(id) ON DELETE CASCADE NOT NULL,
  violation_type VARCHAR(50) NOT NULL, -- phone_number, payment_request, etc.
  severity VARCHAR(20) NOT NULL CHECK (severity IN ('low', 'medium', 'high', 'critical')),
  flagged_message_id UUID REFERENCES public.flagged_messages(id) ON DELETE SET NULL,
  warning_count INT DEFAULT 1,
  action_taken VARCHAR(50), -- warning, mute_24h, mute_7d, ban
  expires_at TIMESTAMPTZ, -- For temporary actions (mute)
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Indexes for user violations
CREATE INDEX IF NOT EXISTS idx_user_violations_user ON public.user_violations(user_id);
CREATE INDEX IF NOT EXISTS idx_user_violations_type ON public.user_violations(violation_type);
CREATE INDEX IF NOT EXISTS idx_user_violations_severity ON public.user_violations(severity);
CREATE INDEX IF NOT EXISTS idx_user_violations_created ON public.user_violations(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_user_violations_expires ON public.user_violations(expires_at) WHERE expires_at IS NOT NULL;

-- ========================================
-- 5. ROW LEVEL SECURITY POLICIES
-- ========================================

-- Enable RLS on all tables
ALTER TABLE public.conversations ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.messages ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.flagged_messages ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.user_violations ENABLE ROW LEVEL SECURITY;

-- Conversations: Users can only see their own conversations
DROP POLICY IF EXISTS "Users can view their own conversations" ON public.conversations;
CREATE POLICY "Users can view their own conversations"
  ON public.conversations FOR SELECT
  USING (auth.uid() = student_id OR auth.uid() = tutor_id);

-- Conversations: System can insert (via service role)
DROP POLICY IF EXISTS "System can insert conversations" ON public.conversations;
CREATE POLICY "System can insert conversations"
  ON public.conversations FOR INSERT
  WITH CHECK (true);

-- Conversations: Users can update their own conversations (e.g., mark as read)
DROP POLICY IF EXISTS "Users can update their own conversations" ON public.conversations;
CREATE POLICY "Users can update their own conversations"
  ON public.conversations FOR UPDATE
  USING (auth.uid() = student_id OR auth.uid() = tutor_id)
  WITH CHECK (auth.uid() = student_id OR auth.uid() = tutor_id);

-- Messages: Users can view messages in their conversations
DROP POLICY IF EXISTS "Users can view messages in their conversations" ON public.messages;
CREATE POLICY "Users can view messages in their conversations"
  ON public.messages FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM public.conversations
      WHERE conversations.id = messages.conversation_id
      AND (conversations.student_id = auth.uid() OR conversations.tutor_id = auth.uid())
    )
  );

-- Messages: Users can send messages in their active conversations
DROP POLICY IF EXISTS "Users can send messages in active conversations" ON public.messages;
CREATE POLICY "Users can send messages in active conversations"
  ON public.messages FOR INSERT
  WITH CHECK (
    sender_id = auth.uid()
    AND EXISTS (
      SELECT 1 FROM public.conversations
      WHERE conversations.id = messages.conversation_id
      AND conversations.status = 'active'
      AND (conversations.student_id = auth.uid() OR conversations.tutor_id = auth.uid())
    )
  );

-- Messages: Users can update their own messages (e.g., mark as read)
DROP POLICY IF EXISTS "Users can update messages in their conversations" ON public.messages;
CREATE POLICY "Users can update messages in their conversations"
  ON public.messages FOR UPDATE
  USING (
    EXISTS (
      SELECT 1 FROM public.conversations
      WHERE conversations.id = messages.conversation_id
      AND (conversations.student_id = auth.uid() OR conversations.tutor_id = auth.uid())
    )
  )
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM public.conversations
      WHERE conversations.id = messages.conversation_id
      AND (conversations.student_id = auth.uid() OR conversations.tutor_id = auth.uid())
    )
  );

-- Flagged Messages: Users can see their own flagged messages
DROP POLICY IF EXISTS "Users can view their own flagged messages" ON public.flagged_messages;
CREATE POLICY "Users can view their own flagged messages"
  ON public.flagged_messages FOR SELECT
  USING (sender_id = auth.uid());

-- Flagged Messages: Admins can view all flagged messages
DROP POLICY IF EXISTS "Admins can view all flagged messages" ON public.flagged_messages;
CREATE POLICY "Admins can view all flagged messages"
  ON public.flagged_messages FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM public.profiles
      WHERE id = auth.uid() AND is_admin = true
    )
  );

-- Flagged Messages: System can insert (via service role)
DROP POLICY IF EXISTS "System can insert flagged messages" ON public.flagged_messages;
CREATE POLICY "System can insert flagged messages"
  ON public.flagged_messages FOR INSERT
  WITH CHECK (true);

-- Flagged Messages: Admins can update (resolve)
DROP POLICY IF EXISTS "Admins can update flagged messages" ON public.flagged_messages;
CREATE POLICY "Admins can update flagged messages"
  ON public.flagged_messages FOR UPDATE
  USING (
    EXISTS (
      SELECT 1 FROM public.profiles
      WHERE id = auth.uid() AND is_admin = true
    )
  )
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM public.profiles
      WHERE id = auth.uid() AND is_admin = true
    )
  );

-- User Violations: Users can see their own violations
DROP POLICY IF EXISTS "Users can view their own violations" ON public.user_violations;
CREATE POLICY "Users can view their own violations"
  ON public.user_violations FOR SELECT
  USING (user_id = auth.uid());

-- User Violations: Admins can view all violations
DROP POLICY IF EXISTS "Admins can view all violations" ON public.user_violations;
CREATE POLICY "Admins can view all violations"
  ON public.user_violations FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM public.profiles
      WHERE id = auth.uid() AND is_admin = true
    )
  );

-- User Violations: System can insert (via service role)
DROP POLICY IF EXISTS "System can insert user violations" ON public.user_violations;
CREATE POLICY "System can insert user violations"
  ON public.user_violations FOR INSERT
  WITH CHECK (true);

-- ========================================
-- 6. DATABASE FUNCTIONS
-- ========================================

-- Function to auto-close expired conversations
CREATE OR REPLACE FUNCTION auto_close_expired_conversations()
RETURNS void AS $$
BEGIN
  UPDATE public.conversations
  SET status = 'expired'
  WHERE status = 'active'
    AND expires_at IS NOT NULL
    AND expires_at < NOW();
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to check and create conversation for trial session
CREATE OR REPLACE FUNCTION create_conversation_for_trial(
  p_trial_session_id UUID,
  p_student_id UUID,
  p_tutor_id UUID
)
RETURNS UUID AS $$
DECLARE
  v_conversation_id UUID;
  v_expires_at TIMESTAMPTZ;
BEGIN
  -- Check if conversation already exists
  SELECT id INTO v_conversation_id
  FROM public.conversations
  WHERE trial_session_id = p_trial_session_id
  LIMIT 1;
  
  IF v_conversation_id IS NOT NULL THEN
    RETURN v_conversation_id;
  END IF;
  
  -- Get trial session scheduled date to calculate expiration (30 days after session)
  SELECT scheduled_date + INTERVAL '30 days' INTO v_expires_at
  FROM public.trial_sessions
  WHERE id = p_trial_session_id;
  
  -- Create conversation
  INSERT INTO public.conversations (
    student_id,
    tutor_id,
    trial_session_id,
    status,
    expires_at
  ) VALUES (
    p_student_id,
    p_tutor_id,
    p_trial_session_id,
    'active',
    v_expires_at
  ) RETURNING id INTO v_conversation_id;
  
  RETURN v_conversation_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to check and create conversation for booking request
CREATE OR REPLACE FUNCTION create_conversation_for_booking(
  p_booking_request_id UUID,
  p_student_id UUID,
  p_tutor_id UUID
)
RETURNS UUID AS $$
DECLARE
  v_conversation_id UUID;
BEGIN
  -- Check if conversation already exists
  SELECT id INTO v_conversation_id
  FROM public.conversations
  WHERE booking_request_id = p_booking_request_id
  LIMIT 1;
  
  IF v_conversation_id IS NOT NULL THEN
    RETURN v_conversation_id;
  END IF;
  
  -- Create conversation (no expiration for booking-based conversations)
  INSERT INTO public.conversations (
    student_id,
    tutor_id,
    booking_request_id,
    status
  ) VALUES (
    p_student_id,
    p_tutor_id,
    p_booking_request_id,
    'active'
  ) RETURNING id INTO v_conversation_id;
  
  RETURN v_conversation_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to update conversation last_message_at when message is inserted
CREATE OR REPLACE FUNCTION update_conversation_last_message()
RETURNS TRIGGER AS $$
BEGIN
  UPDATE public.conversations
  SET last_message_at = NEW.created_at,
      updated_at = NOW()
  WHERE id = NEW.conversation_id;
  
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Trigger to update last_message_at
DROP TRIGGER IF EXISTS update_conversation_last_message_trigger ON public.messages;
CREATE TRIGGER update_conversation_last_message_trigger
  AFTER INSERT ON public.messages
  FOR EACH ROW
  EXECUTE FUNCTION update_conversation_last_message();

-- Function to update conversation updated_at on any update
CREATE OR REPLACE FUNCTION update_conversation_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Trigger to update updated_at on conversation updates
DROP TRIGGER IF EXISTS update_conversation_updated_at_trigger ON public.conversations;
CREATE TRIGGER update_conversation_updated_at_trigger
  BEFORE UPDATE ON public.conversations
  FOR EACH ROW
  EXECUTE FUNCTION update_conversation_updated_at();

-- Function to check user violations and auto-escalate
CREATE OR REPLACE FUNCTION check_user_violations()
RETURNS TRIGGER AS $$
DECLARE
  v_violation_count INT;
  v_recent_high_severity INT;
  v_user_id UUID;
BEGIN
  v_user_id := NEW.sender_id;
  
  -- Count violations in last 30 days
  SELECT COUNT(*) INTO v_violation_count
  FROM public.user_violations
  WHERE user_id = v_user_id
    AND created_at > NOW() - INTERVAL '30 days';
  
  -- Count high/critical violations in last 7 days
  SELECT COUNT(*) INTO v_recent_high_severity
  FROM public.user_violations
  WHERE user_id = v_user_id
    AND severity IN ('high', 'critical')
    AND created_at > NOW() - INTERVAL '7 days';
  
  -- Auto-mute after 3 violations
  IF v_violation_count >= 3 AND NOT EXISTS (
    SELECT 1 FROM public.user_violations
    WHERE user_id = v_user_id
      AND action_taken = 'mute_24h'
      AND expires_at > NOW()
  ) THEN
    INSERT INTO public.user_violations (user_id, violation_type, severity, action_taken, expires_at)
    VALUES (v_user_id, 'auto_mute', 'medium', 'mute_24h', NOW() + INTERVAL '24 hours');
  END IF;
  
  -- Auto-ban after 2 critical violations
  IF v_recent_high_severity >= 2 AND NOT EXISTS (
    SELECT 1 FROM public.user_violations
    WHERE user_id = v_user_id
      AND action_taken = 'ban'
  ) THEN
    INSERT INTO public.user_violations (user_id, violation_type, severity, action_taken)
    VALUES (v_user_id, 'auto_ban', 'critical', 'ban');
    
    -- Block all user's conversations
    UPDATE public.conversations
    SET status = 'blocked'
    WHERE student_id = v_user_id OR tutor_id = v_user_id;
  END IF;
  
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Trigger to check violations when flagged message is inserted
DROP TRIGGER IF EXISTS check_violations_trigger ON public.flagged_messages;
CREATE TRIGGER check_violations_trigger
  AFTER INSERT ON public.flagged_messages
  FOR EACH ROW
  EXECUTE FUNCTION check_user_violations();

-- ========================================
-- 7. COMMENTS
-- ========================================

COMMENT ON TABLE public.conversations IS 'Conversations between students/parents and tutors, linked to bookings/sessions';
COMMENT ON TABLE public.messages IS 'Individual messages within conversations';
COMMENT ON TABLE public.flagged_messages IS 'Messages flagged for admin review due to content violations';
COMMENT ON TABLE public.user_violations IS 'Tracks user violations and auto-escalation actions (mute/ban)';

COMMENT ON COLUMN public.conversations.expires_at IS 'Auto-close conversation after this date (e.g., 30 days after trial session)';
COMMENT ON COLUMN public.messages.filter_reason IS 'Reason message was filtered (phone_number, email, payment_request, etc.)';
COMMENT ON COLUMN public.flagged_messages.flags IS 'JSON array of detected flags with type and severity';
COMMENT ON COLUMN public.user_violations.expires_at IS 'Expiration for temporary actions (mute)';

