-- Run this in your Supabase SQL Editor to create the lessons table

-- Lessons Table
CREATE TABLE IF NOT EXISTS public.lessons (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  tutor_id UUID REFERENCES public.profiles(id) ON DELETE CASCADE,
  learner_id UUID REFERENCES public.profiles(id) ON DELETE CASCADE,
  subject TEXT NOT NULL,
  description TEXT,
  start_time TIMESTAMP WITH TIME ZONE NOT NULL,
  end_time TIMESTAMP WITH TIME ZONE NOT NULL,
  status TEXT DEFAULT 'scheduled' CHECK (status IN ('scheduled', 'completed', 'cancelled')),
  meeting_link TEXT,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Add RLS policy
ALTER TABLE public.lessons ENABLE ROW LEVEL SECURITY;

-- Add trigger for updated_at
CREATE TRIGGER update_lessons_modtime
BEFORE UPDATE ON public.lessons
FOR EACH ROW EXECUTE FUNCTION update_modified_column();

-- OPTIONAL: Add some sample data for testing
-- Uncomment the lines below if you want to test with sample data

-- INSERT INTO public.lessons (tutor_id, learner_id, subject, description, start_time, end_time, status, meeting_link)
-- SELECT 
--   (SELECT id FROM profiles WHERE user_type = 'tutor' LIMIT 1),
--   (SELECT id FROM profiles WHERE user_type = 'learner' LIMIT 1),
--   'Mathematics',
--   'Algebra basics and equations',
--   NOW() + INTERVAL '1 hour',
--   NOW() + INTERVAL '2 hours',
--   'scheduled',
--   'https://meet.google.com/abc-defg-hij'
-- WHERE EXISTS (SELECT 1 FROM profiles WHERE user_type = 'tutor')
-- AND EXISTS (SELECT 1 FROM profiles WHERE user_type = 'learner');

