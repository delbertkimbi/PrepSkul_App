-- Clear old/incomplete parent profiles from testing

-- Delete parent profiles for this user
DELETE FROM public.parent_profiles
WHERE user_id = '2c0842b6-db72-4871-b432-9c9f67a5faa0';

-- Verify deletion
SELECT 
  'parent_profiles cleared!' AS status,
  COUNT(*) AS remaining_profiles
FROM public.parent_profiles
WHERE user_id = '2c0842b6-db72-4871-b432-9c9f67a5faa0';

-- Also clear learner_profiles if they exist
DELETE FROM public.learner_profiles
WHERE user_id = '2c0842b6-db72-4871-b432-9c9f67a5faa0';

-- Reset survey completion status
UPDATE public.profiles
SET survey_completed = FALSE
WHERE id = '2c0842b6-db72-4871-b432-9c9f67a5faa0';

-- Verify reset
SELECT 
  id,
  full_name,
  user_type,
  survey_completed
FROM public.profiles
WHERE id = '2c0842b6-db72-4871-b432-9c9f67a5faa0';

