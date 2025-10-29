-- Check the user_type constraint to see what values are allowed
SELECT
    pg_get_constraintdef(oid) as constraint_definition
FROM pg_constraint
WHERE conname = 'profiles_user_type_check';

-- Also check if there's an enum type
SELECT 
    t.typname,
    e.enumlabel
FROM pg_type t
JOIN pg_enum e ON t.oid = e.enumtypid
WHERE t.typname = 'user_type'
ORDER BY e.enumsortorder;

