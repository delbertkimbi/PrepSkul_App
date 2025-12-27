-- ======================================================
-- MIGRATION 032: Add skulMate Character Selection
-- Adds character_id column to profiles table for storing user's selected character
-- ======================================================

-- 1. Add skulmate_character_id column to profiles table
ALTER TABLE public.profiles 
ADD COLUMN IF NOT EXISTS skulmate_character_id TEXT;

-- 2. Add comment for documentation
COMMENT ON COLUMN public.profiles.skulmate_character_id IS 
'ID of the selected skulMate character (e.g., elementary_male, middle_female, high_male). 
Stored locally in app and synced to database for cross-device consistency.';

-- 3. Create index for faster queries (optional, but helpful if we query by character)
CREATE INDEX IF NOT EXISTS idx_profiles_skulmate_character_id 
ON public.profiles(skulmate_character_id) 
WHERE skulmate_character_id IS NOT NULL;

-- 4. Verification query
DO $$
BEGIN
  IF EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_schema = 'public' 
    AND table_name = 'profiles' 
    AND column_name = 'skulmate_character_id'
  ) THEN
    RAISE NOTICE '✅ skulmate_character_id column added successfully';
  ELSE
    RAISE EXCEPTION '❌ Failed to add skulmate_character_id column';
  END IF;
END $$;





-- MIGRATION 032: Add skulMate Character Selection
-- Adds character_id column to profiles table for storing user's selected character
-- ======================================================

-- 1. Add skulmate_character_id column to profiles table
ALTER TABLE public.profiles 
ADD COLUMN IF NOT EXISTS skulmate_character_id TEXT;

-- 2. Add comment for documentation
COMMENT ON COLUMN public.profiles.skulmate_character_id IS 
'ID of the selected skulMate character (e.g., elementary_male, middle_female, high_male). 
Stored locally in app and synced to database for cross-device consistency.';

-- 3. Create index for faster queries (optional, but helpful if we query by character)
CREATE INDEX IF NOT EXISTS idx_profiles_skulmate_character_id 
ON public.profiles(skulmate_character_id) 
WHERE skulmate_character_id IS NOT NULL;

-- 4. Verification query
DO $$
BEGIN
  IF EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_schema = 'public' 
    AND table_name = 'profiles' 
    AND column_name = 'skulmate_character_id'
  ) THEN
    RAISE NOTICE '✅ skulmate_character_id column added successfully';
  ELSE
    RAISE EXCEPTION '❌ Failed to add skulmate_character_id column';
  END IF;
END $$;




