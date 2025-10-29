-- ================================================
-- FIX DATABASE + ADD DEMO DATA
-- This adds ALL missing columns and creates test data
-- ================================================

-- STEP 1: Add missing columns to tutor_profiles
ALTER TABLE public.tutor_profiles 
ADD COLUMN IF NOT EXISTS bio TEXT;

ALTER TABLE public.tutor_profiles 
ADD COLUMN IF NOT EXISTS education TEXT;

ALTER TABLE public.tutor_profiles 
ADD COLUMN IF NOT EXISTS experience TEXT;

ALTER TABLE public.tutor_profiles 
ADD COLUMN IF NOT EXISTS subjects TEXT[];

ALTER TABLE public.tutor_profiles 
ADD COLUMN IF NOT EXISTS hourly_rate DECIMAL(10, 2);

ALTER TABLE public.tutor_profiles 
ADD COLUMN IF NOT EXISTS availability JSONB;

ALTER TABLE public.tutor_profiles 
ADD COLUMN IF NOT EXISTS is_verified BOOLEAN DEFAULT FALSE;

ALTER TABLE public.tutor_profiles 
ADD COLUMN IF NOT EXISTS rating DECIMAL(3, 2);

-- STEP 2: Add missing columns to profiles (if needed)
ALTER TABLE public.profiles 
ADD COLUMN IF NOT EXISTS phone_number TEXT;

ALTER TABLE public.profiles 
ADD COLUMN IF NOT EXISTS avatar_url TEXT;

-- STEP 3: Fix user_type constraint
ALTER TABLE public.profiles DROP CONSTRAINT IF EXISTS profiles_user_type_check;
ALTER TABLE public.profiles 
ADD CONSTRAINT profiles_user_type_check 
CHECK (user_type IN ('learner', 'tutor', 'parent'));

-- STEP 4: Clean up any existing test data
DELETE FROM public.payments WHERE payer_id IN (SELECT id FROM public.profiles WHERE email LIKE '%@test.com');
DELETE FROM public.lessons WHERE tutor_id IN (SELECT id FROM public.tutor_profiles WHERE id IN (SELECT id FROM public.profiles WHERE email LIKE '%@test.com'));
DELETE FROM public.tutor_profiles WHERE id IN (SELECT id FROM public.profiles WHERE email LIKE '%@test.com');
DELETE FROM public.learner_profiles WHERE id IN (SELECT id FROM public.profiles WHERE email LIKE '%@test.com');
DELETE FROM public.profiles WHERE email LIKE '%@test.com';
DELETE FROM auth.users WHERE email LIKE '%@test.com';

-- STEP 5: Create test users in auth.users
INSERT INTO auth.users (id, email, encrypted_password, email_confirmed_at, created_at, updated_at)
VALUES 
  ('11111111-1111-1111-1111-111111111111', 'tutor1@test.com', crypt('password123', gen_salt('bf')), NOW(), NOW(), NOW()),
  ('22222222-2222-2222-2222-222222222222', 'learner1@test.com', crypt('password123', gen_salt('bf')), NOW(), NOW(), NOW()),
  ('33333333-3333-3333-3333-333333333333', 'parent1@test.com', crypt('password123', gen_salt('bf')), NOW(), NOW(), NOW())
ON CONFLICT (id) DO NOTHING;

-- STEP 6: Create profiles
INSERT INTO public.profiles (id, email, full_name, phone_number, user_type, created_at, updated_at)
VALUES 
  ('11111111-1111-1111-1111-111111111111', 'tutor1@test.com', 'John Kamga', '+237671234567', 'tutor', NOW(), NOW()),
  ('22222222-2222-2222-2222-222222222222', 'learner1@test.com', 'Paul Etundi', '+237673456789', 'learner', NOW(), NOW()),
  ('33333333-3333-3333-3333-333333333333', 'parent1@test.com', 'David Fouda', '+237675678901', 'parent', NOW(), NOW())
ON CONFLICT (id) DO UPDATE SET
  full_name = EXCLUDED.full_name,
  phone_number = EXCLUDED.phone_number,
  updated_at = NOW();

-- STEP 7: Create tutor profile
INSERT INTO public.tutor_profiles (
  id, bio, education, experience, subjects, hourly_rate, is_verified, rating
)
VALUES (
  '11111111-1111-1111-1111-111111111111',
  'Experienced math tutor from Douala',
  'Masters Degree from University of Yaounde I',
  '5 years of tutoring experience',
  ARRAY['Mathematics', 'Physics'],
  50000,
  false,
  4.5
)
ON CONFLICT (id) DO UPDATE SET
  bio = EXCLUDED.bio,
  education = EXCLUDED.education,
  experience = EXCLUDED.experience,
  subjects = EXCLUDED.subjects,
  hourly_rate = EXCLUDED.hourly_rate,
  updated_at = NOW();

-- STEP 8: Create learner profile
INSERT INTO public.learner_profiles (
  id, grade_level, school, subjects, learning_goals
)
VALUES (
  '22222222-2222-2222-2222-222222222222',
  'Form 3',
  'Bilingual Grammar School',
  ARRAY['Mathematics', 'Physics'],
  'Improve math grades for GCE exams'
)
ON CONFLICT (id) DO UPDATE SET
  grade_level = EXCLUDED.grade_level,
  updated_at = NOW();

-- STEP 9: Create a lesson
INSERT INTO public.lessons (
  id, tutor_id, learner_id, subject, description,
  start_time, end_time, status, meeting_link
)
VALUES (
  'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa',
  '11111111-1111-1111-1111-111111111111',
  '22222222-2222-2222-2222-222222222222',
  'Mathematics',
  'Algebra - Quadratic equations',
  NOW() + INTERVAL '2 hours',
  NOW() + INTERVAL '3 hours',
  'scheduled',
  'https://meet.prepskul.com/abc123'
)
ON CONFLICT (id) DO NOTHING;

-- STEP 10: Create a payment
INSERT INTO public.payments (
  id, lesson_id, payer_id, amount, currency, status, payment_method, transaction_id
)
VALUES (
  gen_random_uuid(),
  'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa',
  '33333333-3333-3333-3333-333333333333',
  50000,
  'XAF',
  'completed',
  'MTN Mobile Money',
  'MTN-TXN-123456'
)
ON CONFLICT DO NOTHING;

-- ================================================
-- SUCCESS! Database fixed and demo data created
-- ================================================
-- Login credentials (password: password123):
-- - tutor1@test.com
-- - learner1@test.com
-- - parent1@test.com
-- ================================================

