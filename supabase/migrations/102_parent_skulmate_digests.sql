-- Parent SkulMate digests: weekly email + in-app feed (post-session highlights).

CREATE TABLE IF NOT EXISTS public.parent_skulmate_digests (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  parent_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  child_id UUID,
  digest_type TEXT NOT NULL DEFAULT 'weekly'
    CHECK (digest_type IN ('weekly', 'post_session')),
  digest_json JSONB NOT NULL DEFAULT '{}'::jsonb,
  sent_email_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_parent_skulmate_digests_parent_created
  ON public.parent_skulmate_digests (parent_id, created_at DESC);

CREATE INDEX IF NOT EXISTS idx_parent_skulmate_digests_weekly_cap
  ON public.parent_skulmate_digests (parent_id, digest_type, created_at DESC);

COMMENT ON TABLE public.parent_skulmate_digests IS
  'Structured parent learning updates (weekly email + session highlights).';

ALTER TABLE public.parent_skulmate_digests ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Parents read own digests" ON public.parent_skulmate_digests;
CREATE POLICY "Parents read own digests"
  ON public.parent_skulmate_digests FOR SELECT TO authenticated
  USING (auth.uid() = parent_id);

DROP POLICY IF EXISTS "Service role manages parent digests" ON public.parent_skulmate_digests;
CREATE POLICY "Service role manages parent digests"
  ON public.parent_skulmate_digests FOR ALL TO service_role
  USING (true) WITH CHECK (true);
