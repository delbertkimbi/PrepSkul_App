-- Persist original upload label and typed-note snapshot for SkulMate games
-- Align source_type CHECK with API (docx from DOCX extraction)

ALTER TABLE public.skulmate_games
  DROP CONSTRAINT IF EXISTS skulmate_games_source_type_check;

ALTER TABLE public.skulmate_games
  ADD CONSTRAINT skulmate_games_source_type_check
  CHECK (
    source_type IS NULL
    OR source_type IN ('pdf', 'image', 'text', 'session', 'docx')
  );

ALTER TABLE public.skulmate_games
  ADD COLUMN IF NOT EXISTS source_file_name TEXT,
  ADD COLUMN IF NOT EXISTS source_text_snapshot TEXT;

COMMENT ON COLUMN public.skulmate_games.source_file_name IS 'Original filename from the client when uploading a file or image (for display and history).';
COMMENT ON COLUMN public.skulmate_games.source_text_snapshot IS 'Copy of pasted/typed source text for text-sourced games (enables reuse without re-pasting).';
