-- FCM Tokens Migration
-- Stores Firebase Cloud Messaging tokens for push notifications

-- FCM Tokens Table
-- Stores FCM tokens for each user/device combination
CREATE TABLE IF NOT EXISTS public.fcm_tokens (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id UUID REFERENCES public.profiles(id) ON DELETE CASCADE NOT NULL,
  token TEXT NOT NULL UNIQUE,
  platform TEXT CHECK (platform IN ('ios', 'android', 'web')) NOT NULL,
  device_id TEXT, -- Optional: device identifier
  device_name TEXT, -- Optional: device name (e.g., "John's iPhone")
  app_version TEXT, -- Optional: app version
  is_active BOOLEAN DEFAULT TRUE,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW(),
  
  -- Ensure one active token per user per device
  CONSTRAINT unique_active_token_per_user_device UNIQUE (user_id, device_id, is_active) 
    DEFERRABLE INITIALLY DEFERRED
);

-- Indexes for performance
CREATE INDEX IF NOT EXISTS idx_fcm_tokens_user_id ON public.fcm_tokens(user_id);
CREATE INDEX IF NOT EXISTS idx_fcm_tokens_token ON public.fcm_tokens(token);
CREATE INDEX IF NOT EXISTS idx_fcm_tokens_active ON public.fcm_tokens(user_id, is_active) 
  WHERE is_active = TRUE;
CREATE INDEX IF NOT EXISTS idx_fcm_tokens_platform ON public.fcm_tokens(platform);

-- Function to update updated_at timestamp
CREATE OR REPLACE FUNCTION update_fcm_tokens_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Trigger to auto-update updated_at (drop if exists first)
DROP TRIGGER IF EXISTS update_fcm_tokens_updated_at ON public.fcm_tokens;
CREATE TRIGGER update_fcm_tokens_updated_at
  BEFORE UPDATE ON public.fcm_tokens
  FOR EACH ROW
  EXECUTE FUNCTION update_fcm_tokens_updated_at();

-- Function to deactivate old tokens when a new one is added
-- This ensures only the latest token per device is active
CREATE OR REPLACE FUNCTION deactivate_old_fcm_tokens()
RETURNS TRIGGER AS $$
BEGIN
  -- Deactivate old tokens for the same user and device
  IF NEW.is_active = TRUE AND NEW.device_id IS NOT NULL THEN
    UPDATE public.fcm_tokens
    SET is_active = FALSE
    WHERE user_id = NEW.user_id
      AND device_id = NEW.device_id
      AND id != NEW.id
      AND is_active = TRUE;
  END IF;
  
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Trigger to deactivate old tokens (drop if exists first)
DROP TRIGGER IF EXISTS deactivate_old_fcm_tokens ON public.fcm_tokens;
CREATE TRIGGER deactivate_old_fcm_tokens
  AFTER INSERT OR UPDATE ON public.fcm_tokens
  FOR EACH ROW
  WHEN (NEW.is_active = TRUE)
  EXECUTE FUNCTION deactivate_old_fcm_tokens();

-- RLS Policies
ALTER TABLE public.fcm_tokens ENABLE ROW LEVEL SECURITY;

-- Users can only see their own tokens (drop if exists first)
DROP POLICY IF EXISTS "Users can view their own FCM tokens" ON public.fcm_tokens;
CREATE POLICY "Users can view their own FCM tokens"
  ON public.fcm_tokens
  FOR SELECT
  USING (auth.uid() = user_id);

-- Users can insert their own tokens (drop if exists first)
DROP POLICY IF EXISTS "Users can insert their own FCM tokens" ON public.fcm_tokens;
CREATE POLICY "Users can insert their own FCM tokens"
  ON public.fcm_tokens
  FOR INSERT
  WITH CHECK (auth.uid() = user_id);

-- Users can update their own tokens (drop if exists first)
DROP POLICY IF EXISTS "Users can update their own FCM tokens" ON public.fcm_tokens;
CREATE POLICY "Users can update their own FCM tokens"
  ON public.fcm_tokens
  FOR UPDATE
  USING (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);

-- Users can delete their own tokens (drop if exists first)
DROP POLICY IF EXISTS "Users can delete their own FCM tokens" ON public.fcm_tokens;
CREATE POLICY "Users can delete their own FCM tokens"
  ON public.fcm_tokens
  FOR DELETE
  USING (auth.uid() = user_id);

-- Function to get active FCM tokens for a user
CREATE OR REPLACE FUNCTION get_active_fcm_tokens(p_user_id UUID)
RETURNS TABLE (
  id UUID,
  token TEXT,
  platform TEXT,
  device_id TEXT,
  device_name TEXT
) AS $$
BEGIN
  RETURN QUERY
  SELECT 
    fcm_tokens.id,
    fcm_tokens.token,
    fcm_tokens.platform,
    fcm_tokens.device_id,
    fcm_tokens.device_name
  FROM public.fcm_tokens
  WHERE fcm_tokens.user_id = p_user_id
    AND fcm_tokens.is_active = TRUE
  ORDER BY fcm_tokens.updated_at DESC;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to deactivate all tokens for a user (e.g., on logout)
CREATE OR REPLACE FUNCTION deactivate_user_fcm_tokens(p_user_id UUID)
RETURNS INTEGER AS $$
DECLARE
  updated_count INTEGER;
BEGIN
  UPDATE public.fcm_tokens
  SET is_active = FALSE
  WHERE user_id = p_user_id
    AND is_active = TRUE;
  
  GET DIAGNOSTICS updated_count = ROW_COUNT;
  RETURN updated_count;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

COMMENT ON TABLE public.fcm_tokens IS 'Stores Firebase Cloud Messaging tokens for push notifications';
COMMENT ON COLUMN public.fcm_tokens.token IS 'FCM token for the device';
COMMENT ON COLUMN public.fcm_tokens.platform IS 'Platform: ios, android, or web';
COMMENT ON COLUMN public.fcm_tokens.device_id IS 'Optional device identifier';
COMMENT ON COLUMN public.fcm_tokens.is_active IS 'Whether the token is currently active';

