-- Migration: Optimize Message Queries
-- Purpose: Add composite index for efficient message queries by conversation and creation time
-- Date: 2025-01-XX

-- Composite index for messages table
-- This index optimizes queries that filter by conversation_id and order by created_at
-- Used by: ChatService.getMessages() for pagination and real-time updates
CREATE INDEX IF NOT EXISTS idx_messages_conversation_created 
ON public.messages(conversation_id, created_at DESC);

-- Verify index was created
DO $$
BEGIN
  IF EXISTS (
    SELECT 1 FROM pg_indexes 
    WHERE indexname = 'idx_messages_conversation_created'
  ) THEN
    RAISE NOTICE 'Index idx_messages_conversation_created created successfully';
  ELSE
    RAISE WARNING 'Index idx_messages_conversation_created was not created';
  END IF;
END $$;
