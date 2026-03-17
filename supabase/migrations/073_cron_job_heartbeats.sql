-- Cron heartbeat table for monitoring external cron execution health.
-- Stores one row per cron job and updates status on each run.

CREATE TABLE IF NOT EXISTS public.cron_job_heartbeats (
  job_name TEXT PRIMARY KEY,
  last_status TEXT NOT NULL DEFAULT 'unknown' CHECK (last_status IN ('unknown', 'success', 'failed')),
  last_run_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  last_success_at TIMESTAMPTZ,
  last_error TEXT,
  processed_count INTEGER,
  failed_count INTEGER,
  metadata JSONB,
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_cron_job_heartbeats_last_run
  ON public.cron_job_heartbeats(last_run_at DESC);

ALTER TABLE public.cron_job_heartbeats ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Admins can view cron heartbeats" ON public.cron_job_heartbeats;
CREATE POLICY "Admins can view cron heartbeats"
  ON public.cron_job_heartbeats FOR SELECT
  USING (
    EXISTS (
      SELECT 1
      FROM public.profiles p
      WHERE p.id = auth.uid()
        AND p.is_admin = TRUE
    )
  );

CREATE OR REPLACE FUNCTION public.set_cron_heartbeat_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_cron_job_heartbeats_updated_at ON public.cron_job_heartbeats;
CREATE TRIGGER trg_cron_job_heartbeats_updated_at
BEFORE UPDATE ON public.cron_job_heartbeats
FOR EACH ROW
EXECUTE FUNCTION public.set_cron_heartbeat_updated_at();
