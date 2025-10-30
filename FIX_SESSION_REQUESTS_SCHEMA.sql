-- Fix session_requests table to use learner_id instead of student_id
-- This aligns with how the app sends data

-- Drop existing check constraints
ALTER TABLE public.session_requests 
DROP CONSTRAINT IF EXISTS session_requests_student_type_check;

-- Rename student_id to learner_id for consistency
ALTER TABLE public.session_requests 
RENAME COLUMN student_id TO learner_id;

-- Rename student_type to learner_type
ALTER TABLE public.session_requests 
RENAME COLUMN student_name TO learner_name;

ALTER TABLE public.session_requests 
RENAME COLUMN student_avatar_url TO learner_avatar_url;

ALTER TABLE public.session_requests 
RENAME COLUMN student_type TO learner_type;

-- Add back check constraint with correct name
ALTER TABLE public.session_requests 
ADD CONSTRAINT session_requests_learner_type_check 
CHECK (learner_type IN ('learner', 'parent'));

-- Update RLS policies to use learner_id

-- Drop old policies
DROP POLICY IF EXISTS "Users can view their own session requests" ON public.session_requests;
DROP POLICY IF EXISTS "Students/Parents can create session requests" ON public.session_requests;
DROP POLICY IF EXISTS "Students/Parents can cancel their requests" ON public.session_requests;

-- Create new policies with learner_id
CREATE POLICY "Users can view their own session requests"
  ON public.session_requests FOR SELECT
  USING (auth.uid() = learner_id);

CREATE POLICY "Students/Parents can create session requests"
  ON public.session_requests FOR INSERT
  WITH CHECK (auth.uid() = learner_id);

CREATE POLICY "Students/Parents can cancel their requests"
  ON public.session_requests FOR UPDATE
  USING (auth.uid() = learner_id AND status = 'pending')
  WITH CHECK (status = 'cancelled');

-- Update indexes
DROP INDEX IF EXISTS idx_session_requests_student;
CREATE INDEX IF NOT EXISTS idx_session_requests_learner ON public.session_requests(learner_id);

-- Do the same for recurring_sessions table
ALTER TABLE public.recurring_sessions 
DROP CONSTRAINT IF EXISTS recurring_sessions_student_type_check;

ALTER TABLE public.recurring_sessions 
RENAME COLUMN student_id TO learner_id;

ALTER TABLE public.recurring_sessions 
RENAME COLUMN student_name TO learner_name;

ALTER TABLE public.recurring_sessions 
RENAME COLUMN student_avatar_url TO learner_avatar_url;

ALTER TABLE public.recurring_sessions 
RENAME COLUMN student_type TO learner_type;

ALTER TABLE public.recurring_sessions 
ADD CONSTRAINT recurring_sessions_learner_type_check 
CHECK (learner_type IN ('learner', 'parent'));

-- Update RLS policies for recurring_sessions
DROP POLICY IF EXISTS "Users can view their recurring sessions" ON public.recurring_sessions;
DROP POLICY IF EXISTS "Users can update their sessions" ON public.recurring_sessions;

CREATE POLICY "Users can view their recurring sessions"
  ON public.recurring_sessions FOR SELECT
  USING (auth.uid() = learner_id);

CREATE POLICY "Users can update their sessions"
  ON public.recurring_sessions FOR UPDATE
  USING (auth.uid() = learner_id);

-- Update indexes
DROP INDEX IF EXISTS idx_recurring_sessions_student;
CREATE INDEX IF NOT EXISTS idx_recurring_sessions_learner ON public.recurring_sessions(learner_id);

-- Verify changes
SELECT 'session_requests columns updated!' AS status;
SELECT column_name, data_type 
FROM information_schema.columns 
WHERE table_name = 'session_requests' 
AND column_name IN ('learner_id', 'learner_type', 'learner_name', 'learner_avatar_url')
ORDER BY column_name;

