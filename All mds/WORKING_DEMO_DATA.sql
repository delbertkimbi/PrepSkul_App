-- ================================================
-- SIMPLE DEMO DATA - MATCHES YOUR EXACT SCHEMA
-- Run this AFTER your tables are created
-- ================================================

-- Clean up existing test data
DELETE FROM public.payments WHERE payer_id IN (SELECT id FROM public.profiles WHERE email LIKE '%@test.com');
DELETE FROM public.lessons WHERE tutor_id IN (SELECT id FROM public.tutor_profiles WHERE id IN (SELECT id FROM public.profiles WHERE email LIKE '%@test.com'));
DELETE FROM public.tutor_profiles WHERE id IN (SELECT id FROM public.profiles WHERE email LIKE '%@test.com');
DELETE FROM public.learner_profiles WHERE id IN (SELECT id FROM public.profiles WHERE email LIKE '%@test.com');
DELETE FROM public.profiles WHERE email LIKE '%@test.com';
DELETE FROM auth.users WHERE email LIKE '%@test.com';

-- Create auth users
INSERT INTO auth.users (id, email, encrypted_password, email_confirmed_at, created_at, updated_at)
VALUES 
  ('11111111-1111-1111-1111-111111111111', 'tutor1@test.com', crypt('password123', gen_salt('bf')), NOW(), NOW(), NOW()),
  ('22222222-2222-2222-2222-222222222222', 'learner1@test.com', crypt('password123', gen_salt('bf')), NOW(), NOW(), NOW()),
  ('33333333-3333-3333-3333-333333333333', 'parent1@test.com', crypt('password123', gen_salt('bf')), NOW(), NOW(), NOW())
ON CONFLICT (id) DO NOTHING;

-- Create profiles
INSERT INTO public.profiles (id, email, full_name, phone_number, user_type, created_at, updated_at)
VALUES 
  ('11111111-1111-1111-1111-111111111111', 'tutor1@test.com', 'John Kamga', '+237671234567', 'tutor', NOW(), NOW()),
  ('22222222-2222-2222-2222-222222222222', 'learner1@test.com', 'Paul Etundi', '+237673456789', 'learner', NOW(), NOW()),
  ('33333333-3333-3333-3333-333333333333', 'parent1@test.com', 'David Fouda', '+237675678901', 'parent', NOW(), NOW())
ON CONFLICT (id) DO UPDATE SET
  full_name = EXCLUDED.full_name,
  phone_number = EXCLUDED.phone_number,
  updated_at = NOW();

-- Create tutor profile (matching YOUR schema exactly)
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
  updated_at = NOW();

-- Create learner profile
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

-- Create a lesson (matching YOUR schema)
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

-- Create a payment (matching YOUR schema)
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
-- SUCCESS! Demo data created
-- ================================================
-- Login credentials (password: password123):
-- - tutor1@test.com
-- - learner1@test.com
-- - parent1@test.com
-- ================================================

