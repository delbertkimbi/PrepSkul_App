-- ================================================
-- DELETE ALL DEMO DATA
-- Run this when you're ready to go live
-- Removes all @test.com users and related data
-- ================================================

-- Delete in correct order (respecting foreign keys)
DELETE FROM public.reviews 
WHERE learner_id IN (SELECT id FROM public.profiles WHERE email LIKE '%@test.com');

DELETE FROM public.payment_webhooks 
WHERE payment_id IN (
  SELECT id FROM public.payments 
  WHERE payer_id IN (SELECT id FROM public.profiles WHERE email LIKE '%@test.com')
);

DELETE FROM public.bookings 
WHERE learner_id IN (SELECT id FROM public.profiles WHERE email LIKE '%@test.com') 
   OR tutor_id IN (SELECT id FROM public.profiles WHERE email LIKE '%@test.com');

DELETE FROM public.tutor_availability 
WHERE tutor_id IN (SELECT id FROM public.profiles WHERE email LIKE '%@test.com');

DELETE FROM public.payments 
WHERE payer_id IN (SELECT id FROM public.profiles WHERE email LIKE '%@test.com');

DELETE FROM public.lessons 
WHERE tutor_id IN (SELECT id FROM public.profiles WHERE email LIKE '%@test.com') 
   OR learner_id IN (SELECT id FROM public.profiles WHERE email LIKE '%@test.com');

DELETE FROM public.tutor_profiles 
WHERE user_id IN (SELECT id FROM public.profiles WHERE email LIKE '%@test.com');

DELETE FROM public.learner_profiles 
WHERE user_id IN (SELECT id FROM public.profiles WHERE email LIKE '%@test.com');

DELETE FROM public.profiles 
WHERE email LIKE '%@test.com';

DELETE FROM auth.users 
WHERE email LIKE '%@test.com';

-- ================================================
-- SUCCESS! All demo data deleted
-- ================================================
-- Your database is now clean and ready for production
-- ================================================

