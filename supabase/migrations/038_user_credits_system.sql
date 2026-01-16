-- ======================================================
-- MIGRATION 038: User Credits System
-- Creates user_credits and credit_transactions tables
-- with proper RLS policies
-- ======================================================

-- Create user_credits table
CREATE TABLE IF NOT EXISTS public.user_credits (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  balance INTEGER NOT NULL DEFAULT 0 CHECK (balance >= 0),
  total_purchased INTEGER NOT NULL DEFAULT 0 CHECK (total_purchased >= 0),
  total_spent INTEGER NOT NULL DEFAULT 0 CHECK (total_spent >= 0),
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  UNIQUE(user_id)
);

-- Create credit_transactions table
CREATE TABLE IF NOT EXISTS public.credit_transactions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  type TEXT NOT NULL CHECK (type IN ('purchase', 'deduction', 'refund', 'adjustment')),
  amount INTEGER NOT NULL CHECK (amount > 0),
  balance_before INTEGER NOT NULL,
  balance_after INTEGER NOT NULL,
  reference_type TEXT, -- 'payment_request', 'session', 'admin_adjustment', etc.
  reference_id UUID, -- ID of the related entity
  description TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  CONSTRAINT valid_balance_transition CHECK (balance_after = balance_before + 
    CASE 
      WHEN type IN ('purchase', 'refund', 'adjustment') THEN amount
      WHEN type = 'deduction' THEN -amount
    END)
);

-- Create indexes
CREATE INDEX IF NOT EXISTS idx_user_credits_user_id ON public.user_credits(user_id);
CREATE INDEX IF NOT EXISTS idx_credit_transactions_user_id ON public.credit_transactions(user_id);
CREATE INDEX IF NOT EXISTS idx_credit_transactions_reference ON public.credit_transactions(reference_type, reference_id);
CREATE INDEX IF NOT EXISTS idx_credit_transactions_created_at ON public.credit_transactions(created_at DESC);

-- Enable RLS
ALTER TABLE public.user_credits ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.credit_transactions ENABLE ROW LEVEL SECURITY;

-- RLS Policies for user_credits
-- Users can view their own credits
CREATE POLICY "Users can view their own credits"
  ON public.user_credits
  FOR SELECT
  USING (auth.uid() = user_id);

-- Users can insert their own credits (for initialization)
CREATE POLICY "Users can insert their own credits"
  ON public.user_credits
  FOR INSERT
  WITH CHECK (auth.uid() = user_id);

-- Users can update their own credits
CREATE POLICY "Users can update their own credits"
  ON public.user_credits
  FOR UPDATE
  USING (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);

-- Service role can do everything (for backend operations)
CREATE POLICY "Service role can manage all credits"
  ON public.user_credits
  FOR ALL
  USING (auth.jwt()->>'role' = 'service_role')
  WITH CHECK (auth.jwt()->>'role' = 'service_role');

-- RLS Policies for credit_transactions
-- Users can view their own transactions
CREATE POLICY "Users can view their own credit transactions"
  ON public.credit_transactions
  FOR SELECT
  USING (auth.uid() = user_id);

-- Users can insert their own transactions (for purchases)
CREATE POLICY "Users can insert their own credit transactions"
  ON public.credit_transactions
  FOR INSERT
  WITH CHECK (auth.uid() = user_id);

-- Service role can do everything (for backend operations like deductions)
CREATE POLICY "Service role can manage all credit transactions"
  ON public.credit_transactions
  FOR ALL
  USING (auth.jwt()->>'role' = 'service_role')
  WITH CHECK (auth.jwt()->>'role' = 'service_role');

-- Add comments
COMMENT ON TABLE public.user_credits IS 'Stores user credit balances and totals';
COMMENT ON TABLE public.credit_transactions IS 'Audit log of all credit transactions';
COMMENT ON COLUMN public.user_credits.balance IS 'Current credit balance (1 credit = 100 XAF)';
COMMENT ON COLUMN public.user_credits.total_purchased IS 'Total credits ever purchased';
COMMENT ON COLUMN public.user_credits.total_spent IS 'Total credits ever spent';
COMMENT ON COLUMN public.credit_transactions.type IS 'Transaction type: purchase, deduction, refund, or adjustment';
COMMENT ON COLUMN public.credit_transactions.amount IS 'Credit amount (always positive)';
COMMENT ON COLUMN public.credit_transactions.reference_type IS 'Type of related entity (e.g., payment_request, session)';
COMMENT ON COLUMN public.credit_transactions.reference_id IS 'ID of the related entity';





