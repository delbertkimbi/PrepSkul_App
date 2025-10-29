-- Add is_admin column to profiles table
ALTER TABLE public.profiles 
ADD COLUMN IF NOT EXISTS is_admin BOOLEAN DEFAULT FALSE;

-- Make prepskul@gmail.com an admin
UPDATE public.profiles 
SET is_admin = true 
WHERE email = 'prepskul@gmail.com';

-- Also make tutor1 an admin (for testing)
UPDATE public.profiles 
SET is_admin = true 
WHERE email = 'tutor1@test.com';

-- Success! Admin column added and users updated

