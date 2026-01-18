-- ======================================================
-- MIGRATION 042: Add Archive Support for Conversations
-- Creates table for user-specific conversation archiving
-- ======================================================

-- ========================================
-- USER ARCHIVED CONVERSATIONS TABLE
-- ========================================

CREATE TABLE IF NOT EXISTS public.user_archived_conversations (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id UUID REFERENCES public.profiles(id) ON DELETE CASCADE NOT NULL,
  conversation_id UUID REFERENCES public.conversations(id) ON DELETE CASCADE NOT NULL,
  archived_at TIMESTAMPTZ DEFAULT NOW(),
  
  -- Ensure one user can only archive a conversation once
  CONSTRAINT unique_user_conversation_archive UNIQUE(user_id, conversation_id)
);

-- Indexes for user_archived_conversations
CREATE INDEX IF NOT EXISTS idx_user_archived_conversations_user ON public.user_archived_conversations(user_id);
CREATE INDEX IF NOT EXISTS idx_user_archived_conversations_conversation ON public.user_archived_conversations(conversation_id);
CREATE INDEX IF NOT EXISTS idx_user_archived_conversations_archived_at ON public.user_archived_conversations(archived_at DESC);

-- RLS Policies for user_archived_conversations
ALTER TABLE public.user_archived_conversations ENABLE ROW LEVEL SECURITY;

-- Users can only see their own archived conversations
CREATE POLICY "Users can view their own archived conversations"
  ON public.user_archived_conversations
  FOR SELECT
  USING (auth.uid() = user_id);

-- Users can archive their own conversations
CREATE POLICY "Users can archive their own conversations"
  ON public.user_archived_conversations
  FOR INSERT
  WITH CHECK (auth.uid() = user_id);

-- Users can unarchive their own conversations
CREATE POLICY "Users can unarchive their own conversations"
  ON public.user_archived_conversations
  FOR DELETE
  USING (auth.uid() = user_id);

