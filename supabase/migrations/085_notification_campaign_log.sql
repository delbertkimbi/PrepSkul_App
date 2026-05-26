-- Campaign send log for engagement analytics and dedupe support

CREATE TABLE IF NOT EXISTS public.notification_campaign_log (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  campaign_id TEXT NOT NULL,
  notification_type TEXT NOT NULL,
  channel TEXT NOT NULL DEFAULT 'push' CHECK (channel IN ('push', 'in_app', 'both', 'email')),
  sent_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  metadata JSONB NOT NULL DEFAULT '{}'::jsonb
);

CREATE INDEX IF NOT EXISTS idx_notification_campaign_log_user_sent
  ON public.notification_campaign_log(user_id, sent_at DESC);

CREATE INDEX IF NOT EXISTS idx_notification_campaign_log_campaign_sent
  ON public.notification_campaign_log(campaign_id, sent_at DESC);

ALTER TABLE public.notification_preferences
  ADD COLUMN IF NOT EXISTS engagement_push_enabled BOOLEAN DEFAULT TRUE;

COMMENT ON COLUMN public.notification_preferences.engagement_push_enabled IS
  'When false, engagement cron types (daily_, weekly_, calendar_, etc.) will not send push.';

ALTER TABLE public.notification_campaign_log ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Service role manages campaign log" ON public.notification_campaign_log;
CREATE POLICY "Service role manages campaign log"
  ON public.notification_campaign_log
  FOR ALL
  USING (true)
  WITH CHECK (true);
