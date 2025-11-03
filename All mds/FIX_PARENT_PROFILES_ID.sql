-- ======================================================
-- FIX: Make parent_profiles.id auto-generate UUID
-- Run this in Supabase SQL Editor
-- ======================================================

-- Set default value for id column to auto-generate UUIDs
ALTER TABLE public.parent_profiles 
ALTER COLUMN id SET DEFAULT gen_random_uuid();

-- Verify the change
SELECT column_name, column_default, is_nullable
FROM information_schema.columns 
WHERE table_name = 'parent_profiles' 
AND table_schema = 'public'
AND column_name = 'id';

-- ======================================================
-- DONE! Now id will auto-generate if not provided
-- ======================================================

