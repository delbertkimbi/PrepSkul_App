-- ================================================
-- ADD DEMO DATA FOR TESTING
-- Run this AFTER CREATE_ALL_TABLES.sql
-- Easy to delete later with DELETE_DEMO_DATA.sql
-- ================================================

-- Clean up any existing test data first
DELETE FROM public.reviews WHERE learner_id IN (SELECT id FROM public.profiles WHERE email LIKE '%@test.com');
DELETE FROM public.payment_webhooks WHERE payment_id IN (SELECT id FROM public.payments WHERE payer_id IN (SELECT id FROM public.profiles WHERE email LIKE '%@test.com'));
DELETE FROM public.bookings WHERE learner_id IN (SELECT id FROM public.profiles WHERE email LIKE '%@test.com') OR tutor_id IN (SELECT id FROM public.profiles WHERE email LIKE '%@test.com');
DELETE FROM public.tutor_availability WHERE tutor_id IN (SELECT id FROM public.profiles WHERE email LIKE '%@test.com');
DELETE FROM public.payments WHERE payer_id IN (SELECT id FROM public.profiles WHERE email LIKE '%@test.com');
DELETE FROM public.lessons WHERE tutor_id IN (SELECT id FROM public.profiles WHERE email LIKE '%@test.com') OR learner_id IN (SELECT id FROM public.profiles WHERE email LIKE '%@test.com');
DELETE FROM public.tutor_profiles WHERE id IN (SELECT id FROM public.profiles WHERE email LIKE '%@test.com');
DELETE FROM public.learner_profiles WHERE id IN (SELECT id FROM public.profiles WHERE email LIKE '%@test.com');
DELETE FROM public.profiles WHERE email LIKE '%@test.com';
DELETE FROM auth.users WHERE email LIKE '%@test.com';

-- Create test users in auth.users
INSERT INTO auth.users (id, email, encrypted_password, email_confirmed_at, created_at, updated_at)
VALUES 
  ('11111111-1111-1111-1111-111111111111', 'tutor1@test.com', crypt('password123', gen_salt('bf')), NOW(), NOW(), NOW()),
  ('22222222-2222-2222-2222-222222222222', 'tutor2@test.com', crypt('password123', gen_salt('bf')), NOW(), NOW(), NOW()),
  ('33333333-3333-3333-3333-333333333333', 'learner1@test.com', crypt('password123', gen_salt('bf')), NOW(), NOW(), NOW()),
  ('44444444-4444-4444-4444-444444444444', 'learner2@test.com', crypt('password123', gen_salt('bf')), NOW(), NOW(), NOW()),
  ('55555555-5555-5555-5555-555555555555', 'parent1@test.com', crypt('password123', gen_salt('bf')), NOW(), NOW(), NOW())
ON CONFLICT (id) DO NOTHING;

-- Create profiles
INSERT INTO public.profiles (id, email, full_name, phone_number, user_type, last_seen, created_at, updated_at)
VALUES 
  ('11111111-1111-1111-1111-111111111111', 'tutor1@test.com', 'John Kamga', '+237671234567', 'tutor', NOW() - INTERVAL '2 minutes', NOW(), NOW()),
  ('22222222-2222-2222-2222-222222222222', 'tutor2@test.com', 'Marie Ngono', '+237672345678', 'tutor', NOW() - INTERVAL '4 minutes', NOW(), NOW()),
  ('33333333-3333-3333-3333-333333333333', 'learner1@test.com', 'Paul Etundi', '+237673456789', 'learner', NOW() - INTERVAL '2 hours', NOW(), NOW()),
  ('44444444-4444-4444-4444-444444444444', 'learner2@test.com', 'Sarah Mballa', '+237674567890', 'learner', NOW() - INTERVAL '1 minute', NOW(), NOW()),
  ('55555555-5555-5555-5555-555555555555', 'parent1@test.com', 'David Fouda', '+237675678901', 'parent', NOW() - INTERVAL '3 minutes', NOW(), NOW())
ON CONFLICT (id) DO UPDATE SET
  last_seen = EXCLUDED.last_seen,
  phone_number = EXCLUDED.phone_number,
  full_name = EXCLUDED.full_name,
  user_type = EXCLUDED.user_type,
  updated_at = NOW();

-- Create tutor profiles
INSERT INTO public.tutor_profiles (
  id, bio, education, experience, subjects, hourly_rate, 
  is_verified, rating, created_at, updated_at
)
VALUES 
  ('11111111-1111-1111-1111-111111111111', 
   'Experienced math tutor with 5 years of teaching in Cameroon', 
   'Masters Degree from University of Yaounde I (2018)',
   '5 years of tutoring experience',
   ARRAY['Mathematics', 'Physics'], 
   50000, false, 4.5, NOW() - INTERVAL '2 days', NOW()),
   
  ('22222222-2222-2222-2222-222222222222',
   'English and French language specialist from Buea',
   'Bachelors Degree from University of Buea (2020)',
   '3 years of language tutoring',
   ARRAY['English', 'French'],
   35000, false, 4.2, NOW() - INTERVAL '1 day', NOW())
ON CONFLICT (id) DO UPDATE SET
  is_verified = EXCLUDED.is_verified,
  updated_at = NOW();

-- Create lessons
INSERT INTO public.lessons (
  id, tutor_id, learner_id, subject, description, 
  start_time, end_time, status, meeting_link, created_at, updated_at
)
VALUES 
  ('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', '11111111-1111-1111-1111-111111111111', '33333333-3333-3333-3333-333333333333',
   'Mathematics', 'Algebra basics - Quadratic equations',
   NOW() - INTERVAL '30 minutes', NOW() + INTERVAL '30 minutes',
   'in_progress', 'https://meet.prepskul.com/abc123', NOW(), NOW()),
   
  ('bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb', '22222222-2222-2222-2222-222222222222', '44444444-4444-4444-4444-444444444444',
   'English', 'Essay writing techniques',
   NOW() + INTERVAL '2 hours', NOW() + INTERVAL '3 hours',
   'scheduled', 'https://meet.prepskul.com/def456', NOW(), NOW()),
   
  ('cccccccc-cccc-cccc-cccc-cccccccccccc', '11111111-1111-1111-1111-111111111111', '33333333-3333-3333-3333-333333333333',
   'Physics', 'Newton laws of motion',
   NOW() - INTERVAL '2 days', NOW() - INTERVAL '2 days' + INTERVAL '1 hour',
   'completed', 'https://meet.prepskul.com/ghi789', NOW() - INTERVAL '2 days', NOW())
ON CONFLICT (id) DO NOTHING;

-- Create a completed payment (Fapshi MTN Mobile Money)
INSERT INTO public.payments (
  id, lesson_id, payer_id, amount, currency, status, 
  payment_method, transaction_id, transaction_reference,
  fapshi_transaction_id, description,
  paid_at, created_at, updated_at
)
VALUES (
  gen_random_uuid(),
  'cccccccc-cccc-cccc-cccc-cccccccccccc',
  '55555555-5555-5555-5555-555555555555',
  50000,
  'XAF',
  'completed',
  'MTN Mobile Money',
  'TXN-2025-001234',
  'PAY-2025-001234',
  'FAPSHI-MTN-20251028-1234567',
  'Payment for Physics lesson - Newton laws of motion',
  NOW() - INTERVAL '2 days',
  NOW() - INTERVAL '2 days',
  NOW()
)
ON CONFLICT DO NOTHING;

-- Create a pending payment
INSERT INTO public.payments (
  id, lesson_id, payer_id, amount, currency, status, 
  payment_method, transaction_reference,
  fapshi_payment_link, description,
  expires_at, created_at, updated_at
)
VALUES (
  gen_random_uuid(),
  'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb',
  '55555555-5555-5555-5555-555555555555',
  35000,
  'XAF',
  'pending',
  'Orange Money',
  'PAY-2025-001235',
  'https://pay.fapshi.com/checkout/abc123xyz',
  'Payment for English lesson - Essay writing',
  NOW() + INTERVAL '24 hours',
  NOW(),
  NOW()
)
ON CONFLICT DO NOTHING;

-- Create tutor availability (John Kamga's schedule)
INSERT INTO public.tutor_availability (tutor_id, day_of_week, start_time, end_time)
VALUES 
  ('11111111-1111-1111-1111-111111111111', 1, '08:00', '12:00'), -- Monday morning
  ('11111111-1111-1111-1111-111111111111', 1, '14:00', '18:00'), -- Monday afternoon
  ('11111111-1111-1111-1111-111111111111', 3, '08:00', '12:00'), -- Wednesday morning
  ('11111111-1111-1111-1111-111111111111', 5, '14:00', '18:00')  -- Friday afternoon
ON CONFLICT DO NOTHING;

-- Create a booking request
INSERT INTO public.bookings (
  learner_id, tutor_id, subject, preferred_date, preferred_time,
  duration_minutes, message, status
)
VALUES (
  '44444444-4444-4444-4444-444444444444',
  '11111111-1111-1111-1111-111111111111',
  'Mathematics',
  CURRENT_DATE + 3,
  '15:00',
  90,
  'I need help with calculus. Can we do a 90-minute session?',
  'pending'
)
ON CONFLICT DO NOTHING;

-- Create a review
INSERT INTO public.reviews (
  tutor_id, learner_id, lesson_id, rating, comment
)
VALUES (
  '11111111-1111-1111-1111-111111111111',
  '33333333-3333-3333-3333-333333333333',
  'cccccccc-cccc-cccc-cccc-cccccccccccc',
  5,
  'Excellent teacher! John explained Newton''s laws very clearly. Highly recommended!'
)
ON CONFLICT DO NOTHING;

-- ================================================
-- SUCCESS! Demo data added
-- ================================================
-- You now have:
-- ✅ 5 users (2 tutors, 2 learners, 1 parent)
-- ✅ 2 pending tutors (for admin review)
-- ✅ 1 active session (happening now)
-- ✅ 1 upcoming session (in 2 hours)
-- ✅ 1 completed session
-- ✅ 1 completed payment (50,000 XAF via MTN)
-- ✅ 1 pending payment (35,000 XAF via Orange Money)
-- ✅ Tutor availability schedules
-- ✅ 1 booking request
-- ✅ 1 review
--
-- Login credentials (all passwords: password123):
-- - tutor1@test.com
-- - learner1@test.com
-- - parent1@test.com
-- ================================================

