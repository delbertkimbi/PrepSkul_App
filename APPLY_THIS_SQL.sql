-- ======================================================
-- COPY AND PASTE THIS ENTIRE FILE INTO SUPABASE SQL EDITOR
-- ======================================================

-- MIGRATION 004: Create tutor_requests table
-- ============================================

CREATE TABLE IF NOT EXISTS public.tutor_requests (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  requester_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  
  -- Request details
  subjects TEXT[] NOT NULL,
  education_level TEXT NOT NULL,
  specific_requirements TEXT,
  
  -- Tutor preferences
  teaching_mode TEXT NOT NULL CHECK (teaching_mode IN ('online', 'onsite', 'hybrid')),
  budget_min INTEGER NOT NULL,
  budget_max INTEGER NOT NULL,
  tutor_gender TEXT,
  tutor_qualification TEXT,
  
  -- Schedule & Location
  preferred_days TEXT[] NOT NULL,
  preferred_time TEXT NOT NULL,
  location TEXT NOT NULL,
  
  -- Request metadata
  urgency TEXT NOT NULL DEFAULT 'normal' CHECK (urgency IN ('urgent', 'normal', 'flexible')),
  additional_notes TEXT,
  status TEXT NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'in_progress', 'matched', 'closed')),
  
  -- Matching
  matched_tutor_id UUID REFERENCES public.profiles(id) ON DELETE SET NULL,
  admin_notes TEXT,
  
  -- Timestamps
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  matched_at TIMESTAMPTZ,
  updated_at TIMESTAMPTZ,
  
  -- Denormalized user data for easy display
  requester_name TEXT,
  requester_phone TEXT,
  requester_type TEXT
);

-- Indexes for performance
CREATE INDEX IF NOT EXISTS idx_tutor_requests_requester ON public.tutor_requests(requester_id);
CREATE INDEX IF NOT EXISTS idx_tutor_requests_status ON public.tutor_requests(status);
CREATE INDEX IF NOT EXISTS idx_tutor_requests_urgency ON public.tutor_requests(urgency);
CREATE INDEX IF NOT EXISTS idx_tutor_requests_created_at ON public.tutor_requests(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_tutor_requests_matched_tutor ON public.tutor_requests(matched_tutor_id) WHERE matched_tutor_id IS NOT NULL;

-- RLS Policies
ALTER TABLE public.tutor_requests ENABLE ROW LEVEL SECURITY;

-- Users can view their own requests
CREATE POLICY "Users can view own tutor requests"
  ON public.tutor_requests
  FOR SELECT
  USING (auth.uid() = requester_id);

-- Users can create requests
CREATE POLICY "Users can create tutor requests"
  ON public.tutor_requests
  FOR INSERT
  WITH CHECK (auth.uid() = requester_id);

-- Users can update their own pending requests
CREATE POLICY "Users can update own pending requests"
  ON public.tutor_requests
  FOR UPDATE
  USING (auth.uid() = requester_id AND status = 'pending')
  WITH CHECK (auth.uid() = requester_id);

-- Admins can view all requests
CREATE POLICY "Admins can view all tutor requests"
  ON public.tutor_requests
  FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM public.profiles
      WHERE id = auth.uid() AND is_admin = true
    )
  );

-- Admins can update any request
CREATE POLICY "Admins can update tutor requests"
  ON public.tutor_requests
  FOR UPDATE
  USING (
    EXISTS (
      SELECT 1 FROM public.profiles
      WHERE id = auth.uid() AND is_admin = true
    )
  );

-- Function to auto-update updated_at timestamp
CREATE OR REPLACE FUNCTION update_tutor_request_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Trigger for updated_at
CREATE TRIGGER update_tutor_requests_updated_at
  BEFORE UPDATE ON public.tutor_requests
  FOR EACH ROW
  EXECUTE FUNCTION update_tutor_request_updated_at();

COMMENT ON TABLE public.tutor_requests IS 'Requests from users for tutors not available on the platform';


-- MIGRATION 005: Fix parent_profiles missing columns
-- ===================================================

-- Add child info columns if they don't exist
ALTER TABLE public.parent_profiles 
ADD COLUMN IF NOT EXISTS child_name TEXT,
ADD COLUMN IF NOT EXISTS child_date_of_birth DATE,
ADD COLUMN IF NOT EXISTS child_gender TEXT;

-- Add learning columns if they don't exist
ALTER TABLE public.parent_profiles 
ADD COLUMN IF NOT EXISTS child_confidence_level TEXT,
ADD COLUMN IF NOT EXISTS challenges TEXT[];

-- Add comments for documentation
COMMENT ON COLUMN public.parent_profiles.child_name IS 'Name of the child';
COMMENT ON COLUMN public.parent_profiles.child_date_of_birth IS 'Date of birth of the child';
COMMENT ON COLUMN public.parent_profiles.child_gender IS 'Gender of the child';
COMMENT ON COLUMN public.parent_profiles.child_confidence_level IS 'Child''s confidence level in learning';
COMMENT ON COLUMN public.parent_profiles.challenges IS 'Learning challenges faced by the child';


-- VERIFICATION QUERIES
-- ====================

-- Verify tutor_requests table exists
SELECT 'tutor_requests table created' AS status, COUNT(*) AS row_count FROM public.tutor_requests;

-- Verify parent_profiles columns were added
SELECT 'parent_profiles columns added' AS status, column_name, data_type
FROM information_schema.columns 
WHERE table_name = 'parent_profiles' 
AND table_schema = 'public'
AND column_name IN ('child_name', 'child_date_of_birth', 'child_gender', 'child_confidence_level', 'challenges')
ORDER BY column_name;

-- ======================================================
-- DONE! You should see 2 result sets confirming success
-- ======================================================

