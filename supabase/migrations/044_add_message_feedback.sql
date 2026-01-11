-- ======================================================
-- MIGRATION 044: Add Message Feedback Table
-- Allows users to report false positives in message filtering
-- ======================================================

-- Create message feedback table
CREATE TABLE IF NOT EXISTS public.message_feedback (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  flagged_message_id UUID REFERENCES public.flagged_messages(id) ON DELETE CASCADE,
  message_id UUID REFERENCES public.messages(id) ON DELETE CASCADE,
  user_id UUID REFERENCES public.profiles(id) ON DELETE CASCADE NOT NULL,
  feedback_type VARCHAR(20) NOT NULL CHECK (feedback_type IN ('false_positive', 'correct_flag', 'other')),
  feedback_text TEXT,
  context_snippet TEXT, -- Relevant context around the flagged content
  reviewed BOOLEAN DEFAULT FALSE,
  reviewed_by UUID REFERENCES public.profiles(id),
  reviewed_at TIMESTAMPTZ,
  review_action VARCHAR(50), -- 'whitelist_pattern', 'adjust_threshold', 'no_action'
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Indexes for message feedback
CREATE INDEX IF NOT EXISTS idx_message_feedback_flagged_message ON public.message_feedback(flagged_message_id);
CREATE INDEX IF NOT EXISTS idx_message_feedback_message ON public.message_feedback(message_id);
CREATE INDEX IF NOT EXISTS idx_message_feedback_user ON public.message_feedback(user_id);
CREATE INDEX IF NOT EXISTS idx_message_feedback_type ON public.message_feedback(feedback_type);
CREATE INDEX IF NOT EXISTS idx_message_feedback_reviewed ON public.message_feedback(reviewed);
CREATE INDEX IF NOT EXISTS idx_message_feedback_created ON public.message_feedback(created_at DESC);

-- Row Level Security
ALTER TABLE public.message_feedback ENABLE ROW LEVEL SECURITY;

-- RLS Policies

-- Users can view their own feedback
CREATE POLICY "Users can view their own feedback"
  ON public.message_feedback FOR SELECT
  USING (user_id = auth.uid());

-- Users can insert their own feedback
CREATE POLICY "Users can insert their own feedback"
  ON public.message_feedback FOR INSERT
  WITH CHECK (user_id = auth.uid());

-- Admins can view all feedback
CREATE POLICY "Admins can view all feedback"
  ON public.message_feedback FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM public.profiles
      WHERE id = auth.uid() AND is_admin = true
    )
  );

-- Admins can update feedback (for review)
CREATE POLICY "Admins can update feedback"
  ON public.message_feedback FOR UPDATE
  USING (
    EXISTS (
      SELECT 1 FROM public.profiles
      WHERE id = auth.uid() AND is_admin = true
    )
  );

-- System can insert feedback (via service role)
CREATE POLICY "System can insert feedback"
  ON public.message_feedback FOR INSERT
  WITH CHECK (true);

-- Comments
COMMENT ON TABLE public.message_feedback IS 'User feedback on message filtering results (false positives, correct flags, etc.)';
COMMENT ON COLUMN public.message_feedback.feedback_type IS 'Type of feedback: false_positive, correct_flag, or other';
COMMENT ON COLUMN public.message_feedback.context_snippet IS 'Relevant context around the flagged content for review';
COMMENT ON COLUMN public.message_feedback.review_action IS 'Action taken after admin review: whitelist_pattern, adjust_threshold, or no_action';


