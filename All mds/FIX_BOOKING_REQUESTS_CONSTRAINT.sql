-- Fix booking_requests_student_type_check Constraint
-- The constraint is rejecting valid 'learner' values, so we need to check and fix it

-- STEP 1: Check current constraint definition
SELECT 
    conname AS constraint_name,
    pg_get_constraintdef(oid) AS constraint_definition
FROM pg_constraint
WHERE conname = 'booking_requests_student_type_check'
  AND conrelid = 'public.booking_requests'::regclass;

-- STEP 2: Check existing student_type values in the table
SELECT 
    student_type,
    COUNT(*) as count
FROM public.booking_requests
GROUP BY student_type
ORDER BY count DESC;

-- STEP 3: Drop the existing constraint
ALTER TABLE public.booking_requests 
DROP CONSTRAINT IF EXISTS booking_requests_student_type_check;

-- STEP 4: Recreate the constraint with explicit lowercase values
-- This ensures case-insensitive matching
ALTER TABLE public.booking_requests
ADD CONSTRAINT booking_requests_student_type_check
CHECK (
    student_type IS NOT NULL 
    AND LOWER(TRIM(student_type)) IN ('learner', 'parent')
);

-- STEP 5: Verify the constraint was created correctly
SELECT 
    conname AS constraint_name,
    pg_get_constraintdef(oid) AS constraint_definition
FROM pg_constraint
WHERE conname = 'booking_requests_student_type_check'
  AND conrelid = 'public.booking_requests'::regclass;

-- STEP 6: The constraint is now fixed!
-- You can test it by trying to create a booking request from the app.
-- The constraint will now accept 'learner' and 'parent' values (case-insensitive).

