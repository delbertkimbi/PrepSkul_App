# 📋 Easy Copy-Paste SQL Commands

## Step 1: Enable Active User Tracking

**Copy everything below this line and paste in Supabase SQL Editor:**

---

```sql
-- Active User Tracking Migration
-- Run this in your Supabase SQL Editor

-- 1. Add last_seen column to profiles table
ALTER TABLE public.profiles
ADD COLUMN IF NOT EXISTS last_seen TIMESTAMP WITH TIME ZONE DEFAULT NOW();

-- 2. Create function to update last_seen
CREATE OR REPLACE FUNCTION update_last_seen()
RETURNS TRIGGER AS $$
BEGIN
  NEW.last_seen = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- 3. Create trigger to automatically update last_seen on profile updates
DROP TRIGGER IF EXISTS update_profiles_last_seen ON public.profiles;
CREATE TRIGGER update_profiles_last_seen
BEFORE UPDATE ON public.profiles
FOR EACH ROW EXECUTE FUNCTION update_last_seen();

-- 4. Create indexes for better query performance
CREATE INDEX IF NOT EXISTS idx_profiles_last_seen ON public.profiles(last_seen DESC);
CREATE INDEX IF NOT EXISTS idx_profiles_user_type ON public.profiles(user_type);
CREATE INDEX IF NOT EXISTS idx_profiles_last_seen_user_type ON public.profiles(last_seen DESC, user_type);

-- 5. Create a view for active users (optional, for easier querying)
CREATE OR REPLACE VIEW public.active_users_stats AS
SELECT
  COUNT(*) FILTER (WHERE last_seen >= NOW() - INTERVAL '5 minutes') AS online_now,
  COUNT(*) FILTER (WHERE last_seen >= NOW() - INTERVAL '24 hours') AS active_today,
  COUNT(*) FILTER (WHERE last_seen >= NOW() - INTERVAL '7 days') AS active_week,
  COUNT(*) FILTER (WHERE last_seen >= NOW() - INTERVAL '5 minutes' AND user_type = 'tutor') AS tutors_online,
  COUNT(*) FILTER (WHERE last_seen >= NOW() - INTERVAL '5 minutes' AND user_type = 'learner') AS learners_online,
  COUNT(*) FILTER (WHERE last_seen >= NOW() - INTERVAL '5 minutes' AND user_type = 'parent') AS parents_online
FROM public.profiles;
```

---

**After running, you should see: "Success. No rows returned"**

---

## Step 2: Add Test Data

**Copy everything below this line and paste in Supabase SQL Editor:**

---

```sql
-- PrepSkul Admin Dashboard - Test Data
-- Run this to populate your database with sample data

-- STEP 1: Add last_seen column (run this first if you haven't)
ALTER TABLE public.profiles
ADD COLUMN IF NOT EXISTS last_seen TIMESTAMP WITH TIME ZONE DEFAULT NOW();

-- STEP 2: Create some test users
INSERT INTO auth.users (id, email, encrypted_password, email_confirmed_at, created_at, updated_at)
VALUES 
  ('11111111-1111-1111-1111-111111111111', 'tutor1@test.com', crypt('password123', gen_salt('bf')), NOW(), NOW(), NOW()),
  ('22222222-2222-2222-2222-222222222222', 'tutor2@test.com', crypt('password123', gen_salt('bf')), NOW(), NOW(), NOW()),
  ('33333333-3333-3333-3333-333333333333', 'learner1@test.com', crypt('password123', gen_salt('bf')), NOW(), NOW(), NOW()),
  ('44444444-4444-4444-4444-444444444444', 'learner2@test.com', crypt('password123', gen_salt('bf')), NOW(), NOW(), NOW()),
  ('55555555-5555-5555-5555-555555555555', 'parent1@test.com', crypt('password123', gen_salt('bf')), NOW(), NOW(), NOW())
ON CONFLICT (id) DO NOTHING;

-- STEP 3: Create profiles for these users
INSERT INTO public.profiles (id, email, full_name, phone_number, user_type, last_seen, created_at, updated_at)
VALUES 
  -- Online tutors (active in last 5 min)
  ('11111111-1111-1111-1111-111111111111', 'tutor1@test.com', 'John Kamga', '+237671234567', 'tutor', NOW() - INTERVAL '2 minutes', NOW(), NOW()),
  ('22222222-2222-2222-2222-222222222222', 'tutor2@test.com', 'Marie Ngono', '+237672345678', 'tutor', NOW() - INTERVAL '4 minutes', NOW(), NOW()),
  
  -- Active learners (active today)
  ('33333333-3333-3333-3333-333333333333', 'learner1@test.com', 'Paul Etundi', '+237673456789', 'learner', NOW() - INTERVAL '2 hours', NOW(), NOW()),
  ('44444444-4444-4444-4444-444444444444', 'learner2@test.com', 'Sarah Mballa', '+237674567890', 'learner', NOW() - INTERVAL '1 minute', NOW(), NOW()),
  
  -- Active parent
  ('55555555-5555-5555-5555-555555555555', 'parent1@test.com', 'David Fouda', '+237675678901', 'parent', NOW() - INTERVAL '3 minutes', NOW(), NOW())
ON CONFLICT (id) DO UPDATE SET
  last_seen = EXCLUDED.last_seen,
  updated_at = NOW();

-- STEP 4: Create tutor profiles (some pending for approval)
INSERT INTO public.tutor_profiles (
  id, user_id, bio, highest_degree, institution, graduation_year, 
  tutoring_areas, learner_levels, years_of_experience, city, quarter,
  hours_per_week, expected_rate, status, created_at, updated_at
)
VALUES 
  -- Pending tutor 1
  (gen_random_uuid(), '11111111-1111-1111-1111-111111111111', 
   'Experienced math tutor with 5 years of teaching', 
   'Masters Degree', 'University of Yaounde I', 2018,
   ARRAY['Mathematics', 'Physics'], ARRAY['Form 1-5', 'Advanced Level'], 
   5, 'Douala', 'Akwa', '10-20', 50000, 'pending', NOW() - INTERVAL '2 days', NOW()),
   
  -- Pending tutor 2
  (gen_random_uuid(), '22222222-2222-2222-2222-222222222222',
   'English and French language specialist',
   'Bachelors Degree', 'University of Buea', 2020,
   ARRAY['English', 'French'], ARRAY['Primary', 'Form 1-5'],
   3, 'Yaounde', 'Bastos', '5-10', 35000, 'pending', NOW() - INTERVAL '1 day', NOW())
ON CONFLICT (user_id) DO UPDATE SET
  status = EXCLUDED.status,
  updated_at = NOW();

-- STEP 5: Create some lessons (sessions)
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
   
  -- Completed session (for revenue)
  (gen_random_uuid(), '11111111-1111-1111-1111-111111111111', '33333333-3333-3333-3333-333333333333',
   'Physics', 'Newton laws of motion',
   NOW() - INTERVAL '2 days', NOW() - INTERVAL '2 days' + INTERVAL '1 hour',
   'completed', 'https://meet.prepskul.com/ghi789', NOW() - INTERVAL '2 days', NOW())
ON CONFLICT DO NOTHING;

-- STEP 6: Create payment records
INSERT INTO public.payments (
  id, lesson_id, payer_id, amount, currency, status, 
  payment_method, transaction_id, created_at, updated_at
)
SELECT 
  gen_random_uuid(),
  l.id,
  '55555555-5555-5555-5555-555555555555', -- parent paying
  50000, -- XAF
  'XAF',
  'completed', 
  'MTN Mobile Money',
  'TXN' || floor(random() * 1000000)::text,
  l.created_at,
  NOW()
FROM public.lessons l
WHERE l.status = 'completed'
ON CONFLICT DO NOTHING;

-- STEP 7: Add more historical data for peak activity chart
DO $$
DECLARE
  i INTEGER;
  user_id UUID;
BEGIN
  FOR i IN 1..20 LOOP
    -- Create random user
    user_id := gen_random_uuid();
    
    -- Insert into auth.users
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
    
    -- Insert into profiles with random last_seen times throughout the day
    INSERT INTO public.profiles (id, email, full_name, phone_number, user_type, last_seen, created_at, updated_at)
    VALUES (
      user_id,
      'testuser' || i || '@test.com',
      'Test User ' || i,
      '+23767' || (1000000 + floor(random() * 9000000)::INTEGER)::TEXT,
      (ARRAY['tutor', 'learner', 'parent'])[floor(random() * 3 + 1)],
      -- Random time today (for peak activity chart)
      CURRENT_DATE + (floor(random() * 24) || ' hours')::INTERVAL + (floor(random() * 60) || ' minutes')::INTERVAL,
      NOW() - INTERVAL '1 week',
      NOW()
    )
    ON CONFLICT (id) DO UPDATE SET
      last_seen = EXCLUDED.last_seen,
      updated_at = NOW();
  END LOOP;
END $$;
```

---

**After running, you should see: "Success. No rows returned"**

---

## ✅ Done!

Now go to **http://localhost:3001/admin** (your server is running on port 3001, not 3000)

You should see:
- Total Users: 25
- Active Users: 4 online
- Pending Tutors: 2
- Revenue: 50,000 XAF

---

## 🗑️ Want to Delete Test Data Later?

Copy and run this:

```sql
DELETE FROM payments;
DELETE FROM lessons;
DELETE FROM tutor_profiles;
DELETE FROM profiles WHERE email LIKE '%@test.com';
DELETE FROM auth.users WHERE email LIKE '%@test.com';
```

