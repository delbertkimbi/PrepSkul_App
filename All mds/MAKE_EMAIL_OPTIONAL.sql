-- Make email column optional in profiles table
-- This allows users to sign up with just their phone number

ALTER TABLE profiles 
ALTER COLUMN email DROP NOT NULL;

-- Verification query (run this after to confirm)
SELECT column_name, is_nullable, data_type 
FROM information_schema.columns 
WHERE table_name = 'profiles' AND column_name = 'email';

-- Expected result: is_nullable should be 'YES'

