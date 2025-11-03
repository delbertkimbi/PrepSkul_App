-- Check the current structure of tutor_profiles table
SELECT column_name, data_type, is_nullable, column_default
FROM information_schema.columns 
WHERE table_name = 'tutor_profiles' 
AND table_schema = 'public'
ORDER BY ordinal_position;

