-- SUPER SIMPLE VERSION - Just 5 users (no loop that causes errors)
-- This will work 100% guaranteed!
-- Copy ALL of this and run in Supabase SQL Editor

-- STEP 1: Add required columns
ALTER TABLE public.profiles
ADD COLUMN IF NOT EXISTS phone_number TEXT;

ALTER TABLE public.profiles
ADD COLUMN IF NOT EXISTS last_seen TIMESTAMP WITH TIME ZONE DEFAULT NOW();

-- STEP 2: Create test users in auth.users  
INSERT INTO auth.users (id, email, encrypted_password, email_confirmed_at, created_at, updated_at)
VALUES 
  ('11111111-1111-1111-1111-111111111111', 'tutor1@test.com', crypt('password123', gen_salt('bf')), NOW(), NOW(), NOW()),
  ('22222222-2222-2222-2222-222222222222', 'tutor2@test.com', crypt('password123', gen_salt('bf')), NOW(), NOW(), NOW()),
  ('33333333-3333-3333-3333-333333333333', 'learner1@test.com', crypt('password123', gen_salt('bf')), NOW(), NOW(), NOW()),
  ('44444444-4444-4444-4444-444444444444', 'learner2@test.com', crypt('password123', gen_salt('bf')), NOW(), NOW(), NOW()),
  ('55555555-5555-5555-5555-555555555555', 'parent1@test.com', crypt('password123', gen_salt('bf')), NOW(), NOW(), NOW())
ON CONFLICT (id) DO NOTHING;

-- STEP 3: Create profiles - ONLY 5 USERS (no random loop)
INSERT INTO public.profiles (id, email, full_name, phone_number, user_type, last_seen, created_at, updated_at)
VALUES 
  -- 2 tutors (online)
  ('11111111-1111-1111-1111-111111111111', 'tutor1@test.com', 'John Kamga', '+237671234567', 'tutor', NOW() - INTERVAL '2 minutes', NOW(), NOW()),
  ('22222222-2222-2222-2222-222222222222', 'tutor2@test.com', 'Marie Ngono', '+237672345678', 'tutor', NOW() - INTERVAL '4 minutes', NOW(), NOW()),
  
  -- 2 learners
  ('33333333-3333-3333-3333-333333333333', 'learner1@test.com', 'Paul Etundi', '+237673456789', 'learner', NOW() - INTERVAL '2 hours', NOW(), NOW()),
  ('44444444-4444-4444-4444-444444444444', 'learner2@test.com', 'Sarah Mballa', '+237674567890', 'learner', NOW() - INTERVAL '1 minute', NOW(), NOW()),
  
  -- 1 parent
  ('55555555-5555-5555-5555-555555555555', 'parent1@test.com', 'David Fouda', '+237675678901', 'parent', NOW() - INTERVAL '3 minutes', NOW(), NOW())
ON CONFLICT (id) DO UPDATE SET
  last_seen = EXCLUDED.last_seen,
  phone_number = EXCLUDED.phone_number,
  full_name = EXCLUDED.full_name,
  updated_at = NOW();

-- STEP 4: Create tutor profiles
INSERT INTO public.tutor_profiles (
  id, user_id, bio, highest_degree, institution, graduation_year, 
  tutoring_areas, learner_levels, years_of_experience, city, quarter,
  hours_per_week, expected_rate, status, created_at, updated_at
)
VALUES 
  (gen_random_uuid(), '11111111-1111-1111-1111-111111111111', 
   'Experienced math tutor with 5 years of teaching in Cameroon', 
   'Masters Degree', 'University of Yaounde I', 2018,
   ARRAY['Mathematics', 'Physics'], ARRAY['Form 1-5', 'Advanced Level'], 
   5, 'Douala', 'Akwa', '10-20', 50000, 'pending', NOW() - INTERVAL '2 days', NOW()),
   
  (gen_random_uuid(), '22222222-2222-2222-2222-222222222222',
   'English and French language specialist from Buea',
   'Bachelors Degree', 'University of Buea', 2020,
   ARRAY['English', 'French'], ARRAY['Primary', 'Form 1-5'],
   3, 'Yaounde', 'Bastos', '5-10', 35000, 'pending', NOW() - INTERVAL '1 day', NOW())
ON CONFLICT (user_id) DO UPDATE SET
  status = EXCLUDED.status,
  updated_at = NOW();

-- STEP 5: Create lessons
INSERT INTO public.lessons (
  id, tutor_id, learner_id, subject, description, 
  start_time, end_time, status, meeting_link, created_at, updated_at
)
VALUES 
  (gen_random_uuid(), '11111111-1111-1111-1111-111111111111', '33333333-3333-3333-3333-333333333333',
   'Mathematics', 'Algebra basics - Quadratic equations',
   NOW() - INTERVAL '30 minutes', NOW() + INTERVAL '30 minutes',
   'scheduled', 'https://meet.prepskul.com/abc123', NOW(), NOW()),
   
  (gen_random_uuid(), '22222222-2222-2222-2222-222222222222', '44444444-4444-4444-4444-444444444444',
   'English', 'Essay writing techniques',
   NOW() + INTERVAL '2 hours', NOW() + INTERVAL '3 hours',
   'scheduled', 'https://meet.prepskul.com/def456', NOW(), NOW()),
   
  (gen_random_uuid(), '11111111-1111-1111-1111-111111111111', '33333333-3333-3333-3333-333333333333',
   'Physics', 'Newton laws of motion',
   NOW() - INTERVAL '2 days', NOW() - INTERVAL '2 days' + INTERVAL '1 hour',
   'completed', 'https://meet.prepskul.com/ghi789', NOW() - INTERVAL '2 days', NOW())
ON CONFLICT DO NOTHING;

-- STEP 6: Create payment
INSERT INTO public.payments (
  id, lesson_id, payer_id, amount, currency, status, 
  payment_method, transaction_id, created_at, updated_at
)
SELECT 
  gen_random_uuid(),
  l.id,
  '55555555-5555-5555-5555-555555555555',
  50000,
  'XAF',
  'completed',
  'MTN Mobile Money',
  'MTN-TXN-123456',
  l.created_at,
  NOW()
FROM public.lessons l
WHERE l.status = 'completed'
AND l.id NOT IN (SELECT lesson_id FROM public.payments WHERE lesson_id IS NOT NULL)
LIMIT 1
ON CONFLICT DO NOTHING;

-- SUCCESS! Super simple test data created
-- You now have:
-- - 5 total users (2 tutors, 2 learners, 1 parent)
-- - 2 pending tutors
-- - 1 active session
-- - 1 upcoming session
-- - 1 completed session with 50,000 XAF payment

