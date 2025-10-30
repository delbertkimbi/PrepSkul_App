-- ======================================================
-- MIGRATION 008: Ensure tutor_profiles is Complete (FIXED)
-- Adds user_id and all missing columns
-- ======================================================

-- 1. Add user_id column first (CRITICAL - was missing!)
ALTER TABLE public.tutor_profiles 
ADD COLUMN IF NOT EXISTS user_id UUID REFERENCES public.profiles(id) ON DELETE CASCADE;

-- 2. Create unique index on user_id
CREATE UNIQUE INDEX IF NOT EXISTS idx_tutor_profiles_user_id ON public.tutor_profiles(user_id);

-- 3. Ensure all other tutor_profiles columns exist
ALTER TABLE public.tutor_profiles 
ADD COLUMN IF NOT EXISTS total_reviews INTEGER DEFAULT 0,
ADD COLUMN IF NOT EXISTS total_students INTEGER DEFAULT 0,
ADD COLUMN IF NOT EXISTS total_hours_taught INTEGER DEFAULT 0,
ADD COLUMN IF NOT EXISTS teaching_mode TEXT[],
ADD COLUMN IF NOT EXISTS availability_schedule JSONB,
ADD COLUMN IF NOT EXISTS pricing_details JSONB,
ADD COLUMN IF NOT EXISTS certifications JSONB,
ADD COLUMN IF NOT EXISTS languages TEXT[],
ADD COLUMN IF NOT EXISTS video_url TEXT,
ADD COLUMN IF NOT EXISTS phone_number TEXT,
ADD COLUMN IF NOT EXISTS whatsapp_number TEXT,
ADD COLUMN IF NOT EXISTS status TEXT DEFAULT 'pending',
ADD COLUMN IF NOT EXISTS reviewed_by UUID REFERENCES public.profiles(id),
ADD COLUMN IF NOT EXISTS reviewed_at TIMESTAMPTZ,
ADD COLUMN IF NOT EXISTS admin_review_notes TEXT;

-- 4. Add check constraint for status if it doesn't exist
DO $$ 
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint 
    WHERE conname = 'tutor_profiles_status_check'
  ) THEN
    ALTER TABLE public.tutor_profiles 
    ADD CONSTRAINT tutor_profiles_status_check 
    CHECK (status IN ('pending', 'approved', 'rejected', 'suspended'));
  END IF;
END $$;

-- 5. Set default UUID generation for id column
ALTER TABLE public.tutor_profiles 
ALTER COLUMN id SET DEFAULT gen_random_uuid();

-- 6. Enable RLS
ALTER TABLE public.tutor_profiles ENABLE ROW LEVEL SECURITY;

-- 7. Drop existing policies if they exist
DROP POLICY IF EXISTS "Anyone can view approved tutors" ON public.tutor_profiles;
DROP POLICY IF EXISTS "Tutors can view own profile" ON public.tutor_profiles;
DROP POLICY IF EXISTS "Tutors can insert own profile" ON public.tutor_profiles;
DROP POLICY IF EXISTS "Tutors can update own profile" ON public.tutor_profiles;
DROP POLICY IF EXISTS "Admins can view all tutor profiles" ON public.tutor_profiles;
DROP POLICY IF EXISTS "Admins can update tutor profiles" ON public.tutor_profiles;

-- 8. Create RLS policies

-- Anyone can view approved tutors
CREATE POLICY "Anyone can view approved tutors"
  ON public.tutor_profiles
  FOR SELECT
  USING (status = 'approved');

-- Tutors can view their own profile (regardless of status)
CREATE POLICY "Tutors can view own profile"
  ON public.tutor_profiles
  FOR SELECT
  USING (auth.uid() = user_id);

-- Tutors can insert their own profile
CREATE POLICY "Tutors can insert own profile"
  ON public.tutor_profiles
  FOR INSERT
  WITH CHECK (auth.uid() = user_id);

-- Tutors can update their own profile
CREATE POLICY "Tutors can update own profile"
  ON public.tutor_profiles
  FOR UPDATE
  USING (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);

-- Admins can view all tutor profiles
CREATE POLICY "Admins can view all tutor profiles"
  ON public.tutor_profiles
  FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM public.profiles
      WHERE id = auth.uid() AND is_admin = true
    )
  );

-- Admins can update any tutor profile
CREATE POLICY "Admins can update tutor profiles"
  ON public.tutor_profiles
  FOR UPDATE
  USING (
    EXISTS (
      SELECT 1 FROM public.profiles
      WHERE id = auth.uid() AND is_admin = true
    )
  );

-- 9. Add column comments for documentation
COMMENT ON COLUMN public.tutor_profiles.user_id IS 'Reference to the user in profiles table';
COMMENT ON COLUMN public.tutor_profiles.status IS 'Approval status: pending, approved, rejected, suspended';
COMMENT ON COLUMN public.tutor_profiles.reviewed_by IS 'Admin who reviewed the tutor profile';
COMMENT ON COLUMN public.tutor_profiles.reviewed_at IS 'When the profile was reviewed';
COMMENT ON COLUMN public.tutor_profiles.admin_review_notes IS 'Admin notes about the review';

-- ======================================================
-- Verification
-- ======================================================
SELECT 
  'tutor_profiles setup complete!' AS status,
  COUNT(*) AS total_columns
FROM information_schema.columns 
WHERE table_name = 'tutor_profiles' 
AND table_schema = 'public';

