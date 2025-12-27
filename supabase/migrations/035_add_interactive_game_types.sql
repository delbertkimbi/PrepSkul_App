-- ======================================================
-- MIGRATION 035: Add Interactive Game Types
-- Adds new game types: match3, bubble_pop, word_search, crossword, diagram_label, drag_drop, puzzle_pieces
-- ======================================================

-- Drop the existing CHECK constraint
ALTER TABLE public.skulmate_games 
  DROP CONSTRAINT IF EXISTS skulmate_games_game_type_check;

-- Add new CHECK constraint with all game types
ALTER TABLE public.skulmate_games 
  ADD CONSTRAINT skulmate_games_game_type_check 
  CHECK (game_type IN (
    'quiz', 
    'flashcards', 
    'matching', 
    'fill_blank',
    'match3',
    'bubble_pop',
    'word_search',
    'crossword',
    'diagram_label',
    'drag_drop',
    'puzzle_pieces'
  ));

-- Note: Existing games with old types (quiz, flashcards, matching, fill_blank) will continue to work
-- The new game types can now be used for new games

