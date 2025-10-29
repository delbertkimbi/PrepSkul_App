-- Booking System Tables Migration
-- This adds session_requests and recurring_sessions tables

-- Session Requests Table
-- Stores booking requests from students/parents to tutors
CREATE TABLE IF NOT EXISTS public.session_requests (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  student_id UUID REFERENCES public.profiles(id) ON DELETE CASCADE NOT NULL,
  tutor_id UUID REFERENCES public.profiles(id) ON DELETE CASCADE NOT NULL,
  
  -- Request details
  frequency INTEGER NOT NULL CHECK (frequency BETWEEN 1 AND 7), -- Sessions per week
  days TEXT[] NOT NULL, -- e.g., ['Monday', 'Wednesday']
  times JSONB NOT NULL, -- e.g., {'Monday': '4:00 PM', 'Wednesday': '4:00 PM'}
  location TEXT NOT NULL CHECK (location IN ('online', 'onsite', 'hybrid')),
  address TEXT,
  
  -- Payment details
  payment_plan TEXT NOT NULL CHECK (payment_plan IN ('monthly', 'biweekly', 'weekly')),
  monthly_total DECIMAL(10, 2) NOT NULL,
  
  -- Status tracking
  status TEXT NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'approved', 'rejected', 'cancelled')),
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  responded_at TIMESTAMP WITH TIME ZONE,
  
  -- Responses
  tutor_response TEXT,
  rejection_reason TEXT,
  
  -- Conflict detection
  has_conflict BOOLEAN DEFAULT FALSE,
  conflict_details TEXT,
  
  -- Denormalized data for easy display (reduces joins)
  student_name TEXT NOT NULL,
  student_avatar_url TEXT,
  student_type TEXT NOT NULL CHECK (student_type IN ('learner', 'parent')),
  tutor_name TEXT NOT NULL,
  tutor_avatar_url TEXT,
  tutor_rating DECIMAL(3, 2),
  tutor_is_verified BOOLEAN DEFAULT FALSE,
  
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Recurring Sessions Table
-- Stores approved, ongoing tutoring arrangements
CREATE TABLE IF NOT EXISTS public.recurring_sessions (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  request_id UUID REFERENCES public.session_requests(id) ON DELETE SET NULL,
  student_id UUID REFERENCES public.profiles(id) ON DELETE CASCADE NOT NULL,
  tutor_id UUID REFERENCES public.profiles(id) ON DELETE CASCADE NOT NULL,
  
  -- Session details (copied from approved request)
  frequency INTEGER NOT NULL CHECK (frequency BETWEEN 1 AND 7),
  days TEXT[] NOT NULL,
  times JSONB NOT NULL,
  location TEXT NOT NULL CHECK (location IN ('online', 'onsite', 'hybrid')),
  address TEXT,
  
  -- Payment details
  payment_plan TEXT NOT NULL CHECK (payment_plan IN ('monthly', 'biweekly', 'weekly')),
  monthly_total DECIMAL(10, 2) NOT NULL,
  
  -- Session lifecycle
  start_date TIMESTAMP WITH TIME ZONE NOT NULL,
  end_date TIMESTAMP WITH TIME ZONE, -- NULL means ongoing
  status TEXT NOT NULL DEFAULT 'active' CHECK (status IN ('active', 'paused', 'completed', 'cancelled')),
  
  -- Progress tracking
  last_session_date TIMESTAMP WITH TIME ZONE,
  total_sessions_completed INTEGER DEFAULT 0,
  total_revenue DECIMAL(10, 2) DEFAULT 0,
  
  -- Denormalized data
  student_name TEXT NOT NULL,
  student_avatar_url TEXT,
  student_type TEXT NOT NULL CHECK (student_type IN ('learner', 'parent')),
  tutor_name TEXT NOT NULL,
  tutor_avatar_url TEXT,
  tutor_rating DECIMAL(3, 2),
  
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Indexes for performance
CREATE INDEX IF NOT EXISTS idx_session_requests_student ON public.session_requests(student_id);
CREATE INDEX IF NOT EXISTS idx_session_requests_tutor ON public.session_requests(tutor_id);
CREATE INDEX IF NOT EXISTS idx_session_requests_status ON public.session_requests(status);
CREATE INDEX IF NOT EXISTS idx_session_requests_created ON public.session_requests(created_at DESC);

CREATE INDEX IF NOT EXISTS idx_recurring_sessions_student ON public.recurring_sessions(student_id);
CREATE INDEX IF NOT EXISTS idx_recurring_sessions_tutor ON public.recurring_sessions(tutor_id);
CREATE INDEX IF NOT EXISTS idx_recurring_sessions_status ON public.recurring_sessions(status);
CREATE INDEX IF NOT EXISTS idx_recurring_sessions_start_date ON public.recurring_sessions(start_date DESC);

-- Row Level Security (RLS)
ALTER TABLE public.session_requests ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.recurring_sessions ENABLE ROW LEVEL SECURITY;

-- RLS Policies for session_requests

-- Students/Parents can view their own requests
CREATE POLICY "Users can view their own session requests"
  ON public.session_requests FOR SELECT
  USING (auth.uid() = student_id);

-- Tutors can view requests sent to them
CREATE POLICY "Tutors can view requests sent to them"
  ON public.session_requests FOR SELECT
  USING (auth.uid() = tutor_id);

-- Students/Parents can create requests
CREATE POLICY "Students/Parents can create session requests"
  ON public.session_requests FOR INSERT
  WITH CHECK (auth.uid() = student_id);

-- Students/Parents can cancel their pending requests
CREATE POLICY "Students/Parents can cancel their requests"
  ON public.session_requests FOR UPDATE
  USING (auth.uid() = student_id AND status = 'pending')
  WITH CHECK (status = 'cancelled');

-- Tutors can update requests sent to them (approve/reject)
CREATE POLICY "Tutors can respond to requests"
  ON public.session_requests FOR UPDATE
  USING (auth.uid() = tutor_id AND status = 'pending')
  WITH CHECK (status IN ('approved', 'rejected'));

-- RLS Policies for recurring_sessions

-- Students/Parents can view their sessions
CREATE POLICY "Users can view their recurring sessions"
  ON public.recurring_sessions FOR SELECT
  USING (auth.uid() = student_id);

-- Tutors can view their sessions
CREATE POLICY "Tutors can view their recurring sessions"
  ON public.recurring_sessions FOR SELECT
  USING (auth.uid() = tutor_id);

-- Only system can create recurring sessions (from approved requests)
CREATE POLICY "System can create recurring sessions"
  ON public.recurring_sessions FOR INSERT
  WITH CHECK (true); -- Will be called by authenticated backend

-- Students/Parents can cancel their sessions
CREATE POLICY "Users can update their sessions"
  ON public.recurring_sessions FOR UPDATE
  USING (auth.uid() = student_id);

-- Tutors can update their sessions
CREATE POLICY "Tutors can update their sessions"
  ON public.recurring_sessions FOR UPDATE
  USING (auth.uid() = tutor_id);

-- Update tutor_profiles to add fields needed for booking
-- Check if columns exist before adding them
DO $$ 
BEGIN
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns 
                 WHERE table_name='tutor_profiles' AND column_name='available_schedule') THEN
    ALTER TABLE public.tutor_profiles ADD COLUMN available_schedule TEXT[];
  END IF;
  
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns 
                 WHERE table_name='tutor_profiles' AND column_name='availability_schedule') THEN
    ALTER TABLE public.tutor_profiles ADD COLUMN availability_schedule JSONB;
  END IF;
  
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns 
                 WHERE table_name='tutor_profiles' AND column_name='teaching_mode') THEN
    ALTER TABLE public.tutor_profiles ADD COLUMN teaching_mode TEXT;
  END IF;
END $$;

-- Update profiles table to add fields
DO $$ 
BEGIN
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns 
                 WHERE table_name='profiles' AND column_name='survey_completed') THEN
    ALTER TABLE public.profiles ADD COLUMN survey_completed BOOLEAN DEFAULT FALSE;
  END IF;
  
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns 
                 WHERE table_name='profiles' AND column_name='is_admin') THEN
    ALTER TABLE public.profiles ADD COLUMN is_admin BOOLEAN DEFAULT FALSE;
  END IF;
  
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns 
                 WHERE table_name='profiles' AND column_name='last_seen') THEN
    ALTER TABLE public.profiles ADD COLUMN last_seen TIMESTAMP WITH TIME ZONE DEFAULT NOW();
  END IF;
END $$;

-- Update tutor_profiles to add review fields
DO $$ 
BEGIN
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns 
                 WHERE table_name='tutor_profiles' AND column_name='status') THEN
    ALTER TABLE public.tutor_profiles ADD COLUMN status TEXT DEFAULT 'pending' CHECK (status IN ('pending', 'approved', 'rejected'));
  END IF;
  
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns 
                 WHERE table_name='tutor_profiles' AND column_name='reviewed_by') THEN
    ALTER TABLE public.tutor_profiles ADD COLUMN reviewed_by UUID REFERENCES public.profiles(id);
  END IF;
  
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns 
                 WHERE table_name='tutor_profiles' AND column_name='reviewed_at') THEN
    ALTER TABLE public.tutor_profiles ADD COLUMN reviewed_at TIMESTAMP WITH TIME ZONE;
  END IF;
  
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns 
                 WHERE table_name='tutor_profiles' AND column_name='admin_review_notes') THEN
    ALTER TABLE public.tutor_profiles ADD COLUMN admin_review_notes TEXT;
  END IF;
END $$;

-- Function to update updated_at timestamp
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Triggers for updated_at
DROP TRIGGER IF EXISTS update_session_requests_updated_at ON public.session_requests;
CREATE TRIGGER update_session_requests_updated_at
  BEFORE UPDATE ON public.session_requests
  FOR EACH ROW
  EXECUTE FUNCTION update_updated_at_column();

DROP TRIGGER IF EXISTS update_recurring_sessions_updated_at ON public.recurring_sessions;
CREATE TRIGGER update_recurring_sessions_updated_at
  BEFORE UPDATE ON public.recurring_sessions
  FOR EACH ROW
  EXECUTE FUNCTION update_updated_at_column();

