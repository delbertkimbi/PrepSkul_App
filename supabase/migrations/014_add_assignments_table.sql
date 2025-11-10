-- ======================================================
-- MIGRATION 014: Add Assignments Table
-- Stores assignments extracted from Fathom action items
-- ======================================================

CREATE TABLE IF NOT EXISTS public.assignments (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  session_id UUID NOT NULL, -- References trial_sessions.id or recurring_sessions.id
  session_type TEXT NOT NULL CHECK (session_type IN ('trial', 'recurring')),
  student_id UUID REFERENCES public.profiles(id) ON DELETE CASCADE NOT NULL,
  tutor_id UUID REFERENCES public.profiles(id) ON DELETE CASCADE NOT NULL,
  title TEXT NOT NULL,
  description TEXT,
  due_date DATE,
  status TEXT DEFAULT 'pending' CHECK (status IN ('pending', 'in_progress', 'completed', 'overdue')),
  fathom_timestamp TEXT, -- Recording timestamp where assignment was mentioned
  fathom_playback_url TEXT, -- Link to specific moment in Fathom recording
  completed_at TIMESTAMPTZ,
  completion_notes TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Indexes for performance
CREATE INDEX IF NOT EXISTS idx_assignments_student ON public.assignments(student_id);
CREATE INDEX IF NOT EXISTS idx_assignments_tutor ON public.assignments(tutor_id);
CREATE INDEX IF NOT EXISTS idx_assignments_session ON public.assignments(session_id, session_type);
CREATE INDEX IF NOT EXISTS idx_assignments_status ON public.assignments(status);
CREATE INDEX IF NOT EXISTS idx_assignments_due_date ON public.assignments(due_date);

-- Row Level Security
ALTER TABLE public.assignments ENABLE ROW LEVEL SECURITY;

-- RLS Policies

-- Students can view their own assignments
CREATE POLICY "Students can view own assignments"
  ON public.assignments FOR SELECT
  USING (auth.uid() = student_id);

-- Tutors can view assignments they created
CREATE POLICY "Tutors can view assigned tasks"
  ON public.assignments FOR SELECT
  USING (auth.uid() = tutor_id);

-- Students can update their assignments (mark as in_progress, completed)
CREATE POLICY "Students can update own assignments"
  ON public.assignments FOR UPDATE
  USING (auth.uid() = student_id)
  WITH CHECK (auth.uid() = student_id);

-- System can insert assignments (from Fathom webhook)
CREATE POLICY "System can insert assignments"
  ON public.assignments FOR INSERT
  WITH CHECK (true);

-- Admins can view all assignments
CREATE POLICY "Admins can view all assignments"
  ON public.assignments FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM public.profiles
      WHERE id = auth.uid() AND is_admin = true
    )
  );

-- Function to update updated_at timestamp
CREATE OR REPLACE FUNCTION update_assignments_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Trigger for updated_at
DROP TRIGGER IF EXISTS update_assignments_updated_at ON public.assignments;
CREATE TRIGGER update_assignments_updated_at
  BEFORE UPDATE ON public.assignments
  FOR EACH ROW
  EXECUTE FUNCTION update_assignments_updated_at();

