-- ================================================
-- DROP ALL TABLES (Nuclear Reset)
-- Safe to run since no real users yet
-- ================================================

-- Drop tables in correct order (respecting foreign keys)
DROP TABLE IF EXISTS public.feedback CASCADE;
DROP TABLE IF EXISTS public.progress_reports CASCADE;
DROP TABLE IF EXISTS public.lesson_resources CASCADE;
DROP TABLE IF EXISTS public.payments CASCADE;
DROP TABLE IF EXISTS public.lessons CASCADE;
DROP TABLE IF EXISTS public.learner_profiles CASCADE;
DROP TABLE IF EXISTS public.tutor_profiles CASCADE;
DROP TABLE IF EXISTS public.profiles CASCADE;

-- Note: We don't drop auth.users as that's managed by Supabase
-- But we can clean it up
DELETE FROM auth.users WHERE email LIKE '%@test.com';

-- ================================================
-- SUCCESS! All tables dropped
-- Now run your schema.sql to recreate them
-- ================================================

