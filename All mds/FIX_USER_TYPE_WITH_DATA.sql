-- Step 1: First, let's see what user_type values currently exist
SELECT user_type, COUNT(*) 
FROM profiles 
GROUP BY user_type;

-- Step 2: Update any old values to new ones (uncomment after checking above)
-- UPDATE profiles SET user_type = 'student' WHERE user_type = 'learner';
-- UPDATE profiles SET user_type = 'parent' WHERE user_type = 'guardian';

-- Step 3: Drop the old constraint
ALTER TABLE profiles 
DROP CONSTRAINT IF EXISTS profiles_user_type_check;

-- Step 4: Add new constraint with correct values
ALTER TABLE profiles 
ADD CONSTRAINT profiles_user_type_check 
CHECK (user_type IN ('student', 'tutor', 'parent', 'admin'));

-- Step 5: Verify it worked
SELECT pg_get_constraintdef(oid) as constraint_definition
FROM pg_constraint
WHERE conname = 'profiles_user_type_check';

