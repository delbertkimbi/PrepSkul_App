-- Drop the old constraint
ALTER TABLE profiles 
DROP CONSTRAINT IF EXISTS profiles_user_type_check;

-- Add new constraint with correct values
ALTER TABLE profiles 
ADD CONSTRAINT profiles_user_type_check 
CHECK (user_type IN ('student', 'tutor', 'parent', 'admin'));

-- Verify it worked
SELECT pg_get_constraintdef(oid) as constraint_definition
FROM pg_constraint
WHERE conname = 'profiles_user_type_check';

