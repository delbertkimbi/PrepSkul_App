-- Notification System Enhancement Migration
-- Adds notification preferences, scheduled notifications, and enhances notifications table

-- ============================================
-- 1. ENHANCE NOTIFICATIONS TABLE
-- ============================================

-- Add missing columns to notifications table
ALTER TABLE public.notifications 
  ADD COLUMN IF NOT EXISTS type TEXT,
  ADD COLUMN IF NOT EXISTS priority TEXT DEFAULT 'normal' CHECK (priority IN ('low', 'normal', 'high', 'urgent')),
  ADD COLUMN IF NOT EXISTS action_url TEXT,
  ADD COLUMN IF NOT EXISTS action_text TEXT,
  ADD COLUMN IF NOT EXISTS icon TEXT,
  ADD COLUMN IF NOT EXISTS expires_at TIMESTAMPTZ,
  ADD COLUMN IF NOT EXISTS metadata JSONB;

-- Update existing notifications to have type if null
UPDATE public.notifications 
SET type = COALESCE(notification_type, 'general')
WHERE type IS NULL;

-- Set notification_type to type if type is set but notification_type is null
UPDATE public.notifications 
SET notification_type = type
WHERE notification_type IS NULL AND type IS NOT NULL;

-- Add indexes for performance
CREATE INDEX IF NOT EXISTS idx_notifications_type ON public.notifications(type);
CREATE INDEX IF NOT EXISTS idx_notifications_priority ON public.notifications(priority);
CREATE INDEX IF NOT EXISTS idx_notifications_expires ON public.notifications(expires_at) WHERE expires_at IS NOT NULL;

-- ============================================
-- 2. NOTIFICATION PREFERENCES TABLE
-- ============================================

CREATE TABLE IF NOT EXISTS public.notification_preferences (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id UUID REFERENCES public.profiles(id) ON DELETE CASCADE NOT NULL UNIQUE,
  
  -- Notification channels
  email_enabled BOOLEAN DEFAULT TRUE,
  in_app_enabled BOOLEAN DEFAULT TRUE,
  push_enabled BOOLEAN DEFAULT TRUE,
  
  -- Type-specific preferences (JSONB for flexibility)
  type_preferences JSONB DEFAULT '{
    "profile_approved": {"email": true, "in_app": true},
    "profile_rejected": {"email": true, "in_app": true},
    "profile_improvement": {"email": true, "in_app": true},
    "booking_request": {"email": true, "in_app": true},
    "booking_accepted": {"email": true, "in_app": true},
    "booking_rejected": {"email": true, "in_app": true},
    "payment_received": {"email": true, "in_app": true},
    "payment_failed": {"email": true, "in_app": true},
    "session_reminder": {"email": true, "in_app": true},
    "session_starting_soon": {"email": true, "in_app": true},
    "session_completed": {"email": true, "in_app": true},
    "review_received": {"email": false, "in_app": true},
    "tutor_message": {"email": true, "in_app": true},
    "unblock_request_response": {"email": true, "in_app": true}
  }'::jsonb,
  
  -- Quiet hours (no notifications during this time)
  quiet_hours_start TIME,
  quiet_hours_end TIME,
  
  -- Digest mode
  digest_enabled BOOLEAN DEFAULT FALSE,
  digest_frequency TEXT DEFAULT 'never' CHECK (digest_frequency IN ('daily', 'weekly', 'never')),
  digest_time TIME DEFAULT '09:00',
  
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Indexes
CREATE INDEX IF NOT EXISTS idx_notification_preferences_user 
  ON public.notification_preferences(user_id);

-- RLS Policies
ALTER TABLE public.notification_preferences ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Users can view own preferences" ON public.notification_preferences;
CREATE POLICY "Users can view own preferences"
  ON public.notification_preferences FOR SELECT
  USING (auth.uid() = user_id);

DROP POLICY IF EXISTS "Users can update own preferences" ON public.notification_preferences;
CREATE POLICY "Users can update own preferences"
  ON public.notification_preferences FOR UPDATE
  USING (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);

DROP POLICY IF EXISTS "Users can insert own preferences" ON public.notification_preferences;
CREATE POLICY "Users can insert own preferences"
  ON public.notification_preferences FOR INSERT
  WITH CHECK (auth.uid() = user_id);

-- Function to update updated_at timestamp (create if doesn't exist)
CREATE OR REPLACE FUNCTION update_modified_column()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Trigger for updated_at (drop if exists first)
DROP TRIGGER IF EXISTS update_notification_preferences_modtime ON public.notification_preferences;
CREATE TRIGGER update_notification_preferences_modtime
BEFORE UPDATE ON public.notification_preferences
FOR EACH ROW
EXECUTE FUNCTION update_modified_column();

-- ============================================
-- 3. SCHEDULED NOTIFICATIONS TABLE
-- ============================================

CREATE TABLE IF NOT EXISTS public.scheduled_notifications (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id UUID REFERENCES public.profiles(id) ON DELETE CASCADE NOT NULL,
  notification_type TEXT NOT NULL,
  title TEXT NOT NULL,
  message TEXT NOT NULL,
  scheduled_for TIMESTAMPTZ NOT NULL,
  status TEXT DEFAULT 'pending' CHECK (status IN ('pending', 'sent', 'cancelled', 'failed')),
  related_id UUID,
  metadata JSONB,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  sent_at TIMESTAMPTZ,
  error_message TEXT
);

-- Indexes
CREATE INDEX IF NOT EXISTS idx_scheduled_notifications_user 
  ON public.scheduled_notifications(user_id);
CREATE INDEX IF NOT EXISTS idx_scheduled_notifications_status 
  ON public.scheduled_notifications(status);
CREATE INDEX IF NOT EXISTS idx_scheduled_notifications_scheduled 
  ON public.scheduled_notifications(scheduled_for) 
  WHERE status = 'pending';
CREATE INDEX IF NOT EXISTS idx_scheduled_notifications_type 
  ON public.scheduled_notifications(notification_type);

-- RLS Policies
ALTER TABLE public.scheduled_notifications ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Users can view own scheduled notifications" ON public.scheduled_notifications;
CREATE POLICY "Users can view own scheduled notifications"
  ON public.scheduled_notifications FOR SELECT
  USING (auth.uid() = user_id);

-- System can create/update scheduled notifications (via service account or API)
DROP POLICY IF EXISTS "System can manage scheduled notifications" ON public.scheduled_notifications;
CREATE POLICY "System can manage scheduled notifications"
  ON public.scheduled_notifications FOR ALL
  USING (true) -- Allow system to manage all scheduled notifications
  WITH CHECK (true);

-- ============================================
-- 4. FUNCTION: Get or Create Notification Preferences
-- ============================================

CREATE OR REPLACE FUNCTION get_or_create_notification_preferences(p_user_id UUID)
RETURNS public.notification_preferences AS $$
DECLARE
  prefs public.notification_preferences;
BEGIN
  -- Try to get existing preferences
  SELECT * INTO prefs
  FROM public.notification_preferences
  WHERE user_id = p_user_id;
  
  -- If not found, create default preferences
  IF prefs IS NULL THEN
    INSERT INTO public.notification_preferences (user_id)
    VALUES (p_user_id)
    RETURNING * INTO prefs;
  END IF;
  
  RETURN prefs;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ============================================
-- 5. FUNCTION: Check if Notification Should Be Sent
-- ============================================

CREATE OR REPLACE FUNCTION should_send_notification(
  p_user_id UUID,
  p_notification_type TEXT,
  p_channel TEXT -- 'email', 'in_app', or 'push'
)
RETURNS BOOLEAN AS $$
DECLARE
  prefs public.notification_preferences;
  type_pref JSONB;
  channel_enabled BOOLEAN;
  type_enabled BOOLEAN;
  now_time TIME;
  is_quiet_hours BOOLEAN;
BEGIN
  -- Get user preferences
  SELECT * INTO prefs
  FROM public.notification_preferences
  WHERE user_id = p_user_id;
  
  -- If no preferences, use defaults (send everything)
  IF prefs IS NULL THEN
    RETURN TRUE;
  END IF;
  
  -- Check channel-level enablement
  IF p_channel = 'email' THEN
    channel_enabled := prefs.email_enabled;
  ELSIF p_channel = 'in_app' THEN
    channel_enabled := prefs.in_app_enabled;
  ELSIF p_channel = 'push' THEN
    channel_enabled := prefs.push_enabled;
  ELSE
    RETURN FALSE;
  END IF;
  
  IF NOT channel_enabled THEN
    RETURN FALSE;
  END IF;
  
  -- Check type-specific preferences
  type_pref := prefs.type_preferences->p_notification_type;
  IF type_pref IS NOT NULL THEN
    type_enabled := COALESCE((type_pref->>p_channel)::boolean, TRUE);
    IF NOT type_enabled THEN
      RETURN FALSE;
    END IF;
  END IF;
  
  -- Check quiet hours
  IF prefs.quiet_hours_start IS NOT NULL AND prefs.quiet_hours_end IS NOT NULL THEN
    now_time := CURRENT_TIME;
    -- Handle quiet hours that span midnight (e.g., 22:00 to 08:00)
    IF prefs.quiet_hours_start > prefs.quiet_hours_end THEN
      -- Quiet hours span midnight
      is_quiet_hours := now_time >= prefs.quiet_hours_start OR now_time <= prefs.quiet_hours_end;
    ELSE
      -- Quiet hours in same day
      is_quiet_hours := now_time >= prefs.quiet_hours_start AND now_time <= prefs.quiet_hours_end;
    END IF;
    
    IF is_quiet_hours THEN
      RETURN FALSE;
    END IF;
  END IF;
  
  RETURN TRUE;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ============================================
-- 6. FUNCTION: Cleanup Expired Notifications
-- ============================================

CREATE OR REPLACE FUNCTION cleanup_expired_notifications()
RETURNS INTEGER AS $$
DECLARE
  deleted_count INTEGER;
BEGIN
  DELETE FROM public.notifications
  WHERE expires_at IS NOT NULL 
    AND expires_at < NOW();
  
  GET DIAGNOSTICS deleted_count = ROW_COUNT;
  RETURN deleted_count;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ============================================
-- 7. COMMENTS
-- ============================================

COMMENT ON TABLE public.notification_preferences IS 'User preferences for notification delivery and types';
COMMENT ON TABLE public.scheduled_notifications IS 'Notifications scheduled for future delivery (reminders, etc.)';
COMMENT ON FUNCTION get_or_create_notification_preferences(UUID) IS 'Get or create default notification preferences for a user';
COMMENT ON FUNCTION should_send_notification(UUID, TEXT, TEXT) IS 'Check if a notification should be sent based on user preferences';
COMMENT ON FUNCTION cleanup_expired_notifications() IS 'Delete expired notifications (can be run as a cron job)';
