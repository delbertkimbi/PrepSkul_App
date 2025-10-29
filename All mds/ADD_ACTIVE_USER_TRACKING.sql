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

-- Success! Active user tracking is now enabled.

