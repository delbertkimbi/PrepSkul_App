-- SkulMate lecture transcripts (text only — audio is deleted after transcription)

CREATE TABLE IF NOT EXISTS public.skulmate_lecture_transcripts (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  child_id UUID REFERENCES public.profiles(id) ON DELETE SET NULL,
  title TEXT,
  transcript_text TEXT NOT NULL,
  duration_seconds INTEGER,
  language TEXT DEFAULT 'en',
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_skulmate_lecture_transcripts_user
  ON public.skulmate_lecture_transcripts(user_id, created_at DESC);

CREATE INDEX IF NOT EXISTS idx_skulmate_lecture_transcripts_child
  ON public.skulmate_lecture_transcripts(child_id)
  WHERE child_id IS NOT NULL;

ALTER TABLE public.skulmate_lecture_transcripts ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Users can view own lecture transcripts"
  ON public.skulmate_lecture_transcripts;
DROP POLICY IF EXISTS "Users can insert own lecture transcripts"
  ON public.skulmate_lecture_transcripts;

CREATE POLICY "Users can view own lecture transcripts"
  ON public.skulmate_lecture_transcripts FOR SELECT
  USING (auth.uid() = user_id OR auth.uid() = child_id);

CREATE POLICY "Users can insert own lecture transcripts"
  ON public.skulmate_lecture_transcripts FOR INSERT
  WITH CHECK (auth.uid() = user_id);

COMMENT ON TABLE public.skulmate_lecture_transcripts IS
  'Stored text transcripts from SkulMate lecture recordings (audio not retained).';
