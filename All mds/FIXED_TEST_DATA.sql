-- FIXED: PrepSkul Test Data (works with your current database schema)
-- Copy and run this in Supabase SQL Editor

-- STEP 1: Check and add missing column if needed
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

-- STEP 3: Create profiles (using only columns that exist)
INSERT INTO public.profiles (id, email, full_name, user_type, last_seen, created_at, updated_at)
VALUES 
  -- Online tutors (active in last 5 min)
  ('11111111-1111-1111-1111-111111111111', 'tutor1@test.com', 'John Kamga', 'tutor', NOW() - INTERVAL '2 minutes', NOW(), NOW()),
  ('22222222-2222-2222-2222-222222222222', 'tutor2@test.com', 'Marie Ngono', 'tutor', NOW() - INTERVAL '4 minutes', NOW(), NOW()),
  
  -- Active learners
  ('33333333-3333-3333-3333-333333333333', 'learner1@test.com', 'Paul Etundi', 'learner', NOW() - INTERVAL '2 hours', NOW(), NOW()),
  ('44444444-4444-4444-4444-444444444444', 'learner2@test.com', 'Sarah Mballa', 'learner', NOW() - INTERVAL '1 minute', NOW(), NOW()),
  
  -- Active parent
  ('55555555-5555-5555-5555-555555555555', 'parent1@test.com', 'David Fouda', 'parent', NOW() - INTERVAL '3 minutes', NOW(), NOW())
ON CONFLICT (id) DO UPDATE SET
  last_seen = EXCLUDED.last_seen,
  updated_at = NOW();

-- STEP 4: Add phone numbers separately (if column exists)
UPDATE public.profiles
SET phone_number = CASE id
  WHEN '11111111-1111-1111-1111-111111111111' THEN '+237671234567'
  WHEN '22222222-2222-2222-2222-222222222222' THEN '+237672345678'
  WHEN '33333333-3333-3333-3333-333333333333' THEN '+237673456789'
  WHEN '44444444-4444-4444-4444-444444444444' THEN '+237674567890'
  WHEN '55555555-5555-5555-5555-555555555555' THEN '+237675678901'
END
WHERE id IN (
  '11111111-1111-1111-1111-111111111111',
  '22222222-2222-2222-2222-222222222222',
  '33333333-3333-3333-3333-333333333333',
  '44444444-4444-4444-4444-444444444444',
  '55555555-5555-5555-5555-555555555555'
);

-- STEP 5: Create tutor profiles
INSERT INTO public.tutor_profiles (
  id, user_id, bio, highest_degree, institution, graduation_year, 
  tutoring_areas, learner_levels, years_of_experience, city, quarter,
  hours_per_week, expected_rate, status, created_at, updated_at
)
VALUES 
  (gen_random_uuid(), '11111111-1111-1111-1111-111111111111', 
   'Experienced math tutor with 5 years of teaching', 
   'Masters Degree', 'University of Yaounde I', 2018,
   ARRAY['Mathematics', 'Physics'], ARRAY['Form 1-5', 'Advanced Level'], 
   5, 'Douala', 'Akwa', '10-20', 50000, 'pending', NOW() - INTERVAL '2 days', NOW()),
   
  (gen_random_uuid(), '22222222-2222-2222-2222-222222222222',
   'English and French language specialist',
   'Bachelors Degree', 'University of Buea', 2020,
   ARRAY['English', 'French'], ARRAY['Primary', 'Form 1-5'],
   3, 'Yaounde', 'Bastos', '5-10', 35000, 'pending', NOW() - INTERVAL '1 day', NOW())
ON CONFLICT (user_id) DO UPDATE SET
  status = EXCLUDED.status,
  updated_at = NOW();

-- STEP 6: Create lessons
INSERT INTO public.lessons (
  id, tutor_id, learner_id, subject, description, 
  start_time, end_time, status, meeting_link, created_at, updated_at
)
VALUES 
  -- Active session (happening now)
  (gen_random_uuid(), '11111111-1111-1111-1111-111111111111', '33333333-3333-3333-3333-333333333333',
   'Mathematics', 'Algebra basics - Quadratic equations',
   NOW() - INTERVAL '30 minutes', NOW() + INTERVAL '30 minutes',
   'scheduled', 'https://meet.prepskul.com/abc123', NOW(), NOW()),
   
  -- Upcoming session today
  (gen_random_uuid(), '22222222-2222-2222-2222-222222222222', '44444444-4444-4444-4444-444444444444',
   'English', 'Essay writing techniques',
   NOW() + INTERVAL '2 hours', NOW() + INTERVAL '3 hours',
   'scheduled', 'https://meet.prepskul.com/def456', NOW(), NOW()),
   
  -- Completed session
  (gen_random_uuid(), '11111111-1111-1111-1111-111111111111', '33333333-3333-3333-3333-333333333333',
   'Physics', 'Newton laws of motion',
   NOW() - INTERVAL '2 days', NOW() - INTERVAL '2 days' + INTERVAL '1 hour',
   'completed', 'https://meet.prepskul.com/ghi789', NOW() - INTERVAL '2 days', NOW())
ON CONFLICT DO NOTHING;

-- STEP 7: Create payments
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
  'TXN' || floor(random() * 1000000)::text,
  l.created_at,
  NOW()
FROM public.lessons l
WHERE l.status = 'completed'
ON CONFLICT DO NOTHING;

-- STEP 8: Add 20 more users for activity data
DO $$
DECLARE
  i INTEGER;
  user_id UUID;
BEGIN
  FOR i IN 1..20 LOOP
    user_id := gen_random_uuid();
    
    INSERT INTO auth.users (id, email, encrypted_password, email_confirmed_at, created_at, updated_at)
    VALUES (
      user_id,
      'testuser' || i || '@test.com',
      crypt('password123', gen_salt('bf')),
      NOW(),
      NOW() - INTERVAL '1 week',
      NOW()
    )
    ON CONFLICT (id) DO NOTHING;
    
    INSERT INTO public.profiles (id, email, full_name, user_type, last_seen, created_at, updated_at)
    VALUES (
      user_id,
      'testuser' || i || '@test.com',
      'Test User ' || i,
      (ARRAY['tutor', 'learner', 'parent'])[floor(random() * 3 + 1)],
      CURRENT_DATE + (floor(random() * 24) || ' hours')::INTERVAL + (floor(random() * 60) || ' minutes')::INTERVAL,
      NOW() - INTERVAL '1 week',
      NOW()
    )
    ON CONFLICT (id) DO UPDATE SET
      last_seen = EXCLUDED.last_seen,
      updated_at = NOW();
  END LOOP;
END $$;

-- SUCCESS! Test data created.

