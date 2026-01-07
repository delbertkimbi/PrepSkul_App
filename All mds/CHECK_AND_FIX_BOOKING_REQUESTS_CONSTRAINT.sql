-- Check and Fix booking_requests_student_type_check Constraint
-- This script inspects the constraint definition and fixes it if needed

-- 1. Check the current constraint definition
SELECT 
    conname AS constraint_name,
    pg_get_constraintdef(oid) AS constraint_definition
FROM pg_constraint
WHERE conname = 'booking_requests_student_type_check'
  AND conrelid = 'public.booking_requests'::regclass;

-- 2. Check the table structure
SELECT 
    column_name,
    data_type,
    is_nullable,
    column_default
FROM information_schema.columns
WHERE table_schema = 'public'
  AND table_name = 'booking_requests'
  AND column_name = 'student_type';

-- 3. Check existing data in booking_requests to see what student_type values exist
SELECT 
    student_type,
    COUNT(*) as count
FROM public.booking_requests
GROUP BY student_type
ORDER BY count DESC;

-- 4. Check if there are any NULL values
SELECT 
    COUNT(*) as null_count
FROM public.booking_requests
WHERE student_type IS NULL;

-- 5. If the constraint is wrong, drop it and recreate it
-- First, let's see what the constraint currently allows
-- Then we'll fix it

-- DROP the existing constraint if it's incorrect
-- ALTER TABLE public.booking_requests 
-- DROP CONSTRAINT IF EXISTS booking_requests_student_type_check;

-- Recreate the constraint with the correct values
-- ALTER TABLE public.booking_requests
-- ADD CONSTRAINT booking_requests_student_type_check
-- CHECK (student_type IN ('learner', 'parent'));

-- 6. Verify the constraint after fixing
-- SELECT 
--     conname AS constraint_name,
--     pg_get_constraintdef(oid) AS constraint_definition
-- FROM pg_constraint
-- WHERE conname = 'booking_requests_student_type_check'
--   AND conrelid = 'public.booking_requests'::regclass;

