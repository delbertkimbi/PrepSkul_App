-- ============================================
-- CREATE session_payments AND tutor_earnings TABLES
-- Run this in Supabase SQL Editor if you see errors about missing tables
-- This script creates tables in the correct order with proper dependencies
-- ============================================

-- ========================================
-- STEP 1: CREATE session_payments TABLE FIRST
-- ========================================
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.tables 
    WHERE table_schema = 'public' 
    AND table_name = 'session_payments'
  ) THEN
    -- Check if recurring_sessions exists (for FK reference)
    IF EXISTS (
      SELECT 1 FROM information_schema.tables 
      WHERE table_schema = 'public' 
      AND table_name = 'recurring_sessions'
    ) THEN
      -- Create with recurring_sessions FK
      CREATE TABLE public.session_payments (
        id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
        session_id UUID, -- References individual_sessions(id) - nullable for now
        recurring_session_id UUID REFERENCES public.recurring_sessions(id) ON DELETE SET NULL,
        
        -- Payment Details
        session_fee DECIMAL(10, 2) NOT NULL CHECK (session_fee >= 0),
        platform_fee DECIMAL(10, 2) NOT NULL CHECK (platform_fee >= 0), -- 15% of session_fee
        tutor_earnings DECIMAL(10, 2) NOT NULL CHECK (tutor_earnings >= 0), -- 85% of session_fee
        
        -- Payment Status
        payment_status TEXT NOT NULL DEFAULT 'unpaid' CHECK (payment_status IN ('unpaid', 'pending', 'paid', 'failed', 'refunded')),
        payment_id UUID, -- References payments(id) - nullable if payments table doesn't exist
        fapshi_trans_id TEXT, -- Fapshi transaction ID
        
        -- Payment Timestamps
        payment_initiated_at TIMESTAMPTZ,
        payment_confirmed_at TIMESTAMPTZ,
        payment_failed_at TIMESTAMPTZ,
        refunded_at TIMESTAMPTZ,
        refund_reason TEXT,
        
        -- Wallet Status
        earnings_added_to_wallet BOOLEAN DEFAULT FALSE,
        wallet_updated_at TIMESTAMPTZ,
        
        -- Timestamps
        created_at TIMESTAMPTZ DEFAULT NOW(),
        updated_at TIMESTAMPTZ DEFAULT NOW()
      );
    ELSE
      -- Create without recurring_sessions FK (if table doesn't exist)
      CREATE TABLE public.session_payments (
        id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
        session_id UUID,
        recurring_session_id UUID, -- No FK if recurring_sessions doesn't exist
        
        -- Payment Details
        session_fee DECIMAL(10, 2) NOT NULL CHECK (session_fee >= 0),
        platform_fee DECIMAL(10, 2) NOT NULL CHECK (platform_fee >= 0),
        tutor_earnings DECIMAL(10, 2) NOT NULL CHECK (tutor_earnings >= 0),
        
        -- Payment Status
        payment_status TEXT NOT NULL DEFAULT 'unpaid' CHECK (payment_status IN ('unpaid', 'pending', 'paid', 'failed', 'refunded')),
        payment_id UUID,
        fapshi_trans_id TEXT,
        
        -- Payment Timestamps
        payment_initiated_at TIMESTAMPTZ,
        payment_confirmed_at TIMESTAMPTZ,
        payment_failed_at TIMESTAMPTZ,
        refunded_at TIMESTAMPTZ,
        refund_reason TEXT,
        
        -- Wallet Status
        earnings_added_to_wallet BOOLEAN DEFAULT FALSE,
        wallet_updated_at TIMESTAMPTZ,
        
        -- Timestamps
        created_at TIMESTAMPTZ DEFAULT NOW(),
        updated_at TIMESTAMPTZ DEFAULT NOW()
      );
    END IF;

    -- Create indexes for session_payments
    CREATE INDEX IF NOT EXISTS idx_session_payments_session ON public.session_payments(session_id);
    CREATE INDEX IF NOT EXISTS idx_session_payments_recurring ON public.session_payments(recurring_session_id);
    CREATE INDEX IF NOT EXISTS idx_session_payments_status ON public.session_payments(payment_status);
    CREATE INDEX IF NOT EXISTS idx_session_payments_fapshi ON public.session_payments(fapshi_trans_id);

    -- Enable RLS
    ALTER TABLE public.session_payments ENABLE ROW LEVEL SECURITY;

    RAISE NOTICE '✅ session_payments table created successfully';
  ELSE
    RAISE NOTICE 'ℹ️ session_payments table already exists';
  END IF;
END $$;

-- ========================================
-- STEP 2: ADD FK TO payments TABLE (IF IT EXISTS)
-- ========================================
DO $$
BEGIN
  -- If payments table exists, add FK constraint
  IF EXISTS (
    SELECT 1 FROM information_schema.tables 
    WHERE table_schema = 'public' 
    AND table_name = 'payments'
  ) THEN
    -- Add FK constraint if it doesn't exist
    IF NOT EXISTS (
      SELECT 1 FROM information_schema.table_constraints 
      WHERE constraint_name = 'session_payments_payment_id_fkey'
      AND table_schema = 'public'
    ) THEN
      ALTER TABLE public.session_payments
      ADD CONSTRAINT session_payments_payment_id_fkey
      FOREIGN KEY (payment_id) REFERENCES public.payments(id) ON DELETE SET NULL;
      
      RAISE NOTICE '✅ Added FK constraint to payments table';
    END IF;
  ELSE
    RAISE NOTICE 'ℹ️ payments table does not exist - payment_id will remain without FK';
  END IF;
END $$;

-- ========================================
-- STEP 3: CREATE tutor_earnings TABLE
-- ========================================
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.tables 
    WHERE table_schema = 'public' 
    AND table_name = 'tutor_earnings'
  ) THEN
    -- Check if recurring_sessions exists
    IF EXISTS (
      SELECT 1 FROM information_schema.tables 
      WHERE table_schema = 'public' 
      AND table_name = 'recurring_sessions'
    ) THEN
      -- Create with recurring_sessions FK
      CREATE TABLE public.tutor_earnings (
        id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
        tutor_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
        session_id UUID, -- References individual_sessions(id) - nullable for now
        recurring_session_id UUID REFERENCES public.recurring_sessions(id) ON DELETE SET NULL,
        
        -- Earnings Details
        session_fee DECIMAL(10, 2) NOT NULL CHECK (session_fee >= 0),
        platform_fee DECIMAL(10, 2) NOT NULL CHECK (platform_fee >= 0), -- 15%
        tutor_earnings DECIMAL(10, 2) NOT NULL CHECK (tutor_earnings >= 0), -- 85%
        
        -- Status
        earnings_status TEXT NOT NULL DEFAULT 'pending' CHECK (earnings_status IN ('pending', 'active', 'paid_out', 'cancelled')),
        
        -- Payment Link (references session_payments which we just created)
        session_payment_id UUID REFERENCES public.session_payments(id) ON DELETE SET NULL,
        
        -- Wallet Updates
        added_to_pending_balance BOOLEAN DEFAULT FALSE,
        added_to_active_balance BOOLEAN DEFAULT FALSE,
        pending_balance_added_at TIMESTAMPTZ,
        active_balance_added_at TIMESTAMPTZ,
        
        -- Payout
        payout_request_id UUID, -- References payout_requests table (if exists)
        paid_out_at TIMESTAMPTZ,
        
        -- Timestamps
        created_at TIMESTAMPTZ DEFAULT NOW(),
        updated_at TIMESTAMPTZ DEFAULT NOW()
      );
    ELSE
      -- Create without recurring_sessions FK
      CREATE TABLE public.tutor_earnings (
        id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
        tutor_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
        session_id UUID,
        recurring_session_id UUID, -- No FK if recurring_sessions doesn't exist
        
        -- Earnings Details
        session_fee DECIMAL(10, 2) NOT NULL CHECK (session_fee >= 0),
        platform_fee DECIMAL(10, 2) NOT NULL CHECK (platform_fee >= 0),
        tutor_earnings DECIMAL(10, 2) NOT NULL CHECK (tutor_earnings >= 0),
        
        -- Status
        earnings_status TEXT NOT NULL DEFAULT 'pending' CHECK (earnings_status IN ('pending', 'active', 'paid_out', 'cancelled')),
        
        -- Payment Link
        session_payment_id UUID REFERENCES public.session_payments(id) ON DELETE SET NULL,
        
        -- Wallet Updates
        added_to_pending_balance BOOLEAN DEFAULT FALSE,
        added_to_active_balance BOOLEAN DEFAULT FALSE,
        pending_balance_added_at TIMESTAMPTZ,
        active_balance_added_at TIMESTAMPTZ,
        
        -- Payout
        payout_request_id UUID,
        paid_out_at TIMESTAMPTZ,
        
        -- Timestamps
        created_at TIMESTAMPTZ DEFAULT NOW(),
        updated_at TIMESTAMPTZ DEFAULT NOW()
      );
    END IF;

    -- Create indexes
    CREATE INDEX IF NOT EXISTS idx_tutor_earnings_tutor ON public.tutor_earnings(tutor_id);
    CREATE INDEX IF NOT EXISTS idx_tutor_earnings_session ON public.tutor_earnings(session_id);
    CREATE INDEX IF NOT EXISTS idx_tutor_earnings_recurring ON public.tutor_earnings(recurring_session_id);
    CREATE INDEX IF NOT EXISTS idx_tutor_earnings_status ON public.tutor_earnings(earnings_status);
    CREATE INDEX IF NOT EXISTS idx_tutor_earnings_created ON public.tutor_earnings(created_at DESC);

    -- Enable RLS
    ALTER TABLE public.tutor_earnings ENABLE ROW LEVEL SECURITY;

    -- Create RLS policies
    DROP POLICY IF EXISTS "Tutors can view their earnings" ON public.tutor_earnings;
    CREATE POLICY "Tutors can view their earnings" ON public.tutor_earnings
      FOR SELECT
      USING (auth.uid() = tutor_id);

    RAISE NOTICE '✅ tutor_earnings table created successfully';
  ELSE
    RAISE NOTICE 'ℹ️ tutor_earnings table already exists';
  END IF;
END $$;

-- ========================================
-- STEP 4: VERIFY TABLES EXIST
-- ========================================
SELECT 
  'session_payments' as table_name,
  CASE 
    WHEN EXISTS (
      SELECT 1 FROM information_schema.tables 
      WHERE table_schema = 'public' 
      AND table_name = 'session_payments'
    ) THEN '✅ EXISTS'
    ELSE '❌ MISSING'
  END as status
UNION ALL
SELECT 
  'tutor_earnings' as table_name,
  CASE 
    WHEN EXISTS (
      SELECT 1 FROM information_schema.tables 
      WHERE table_schema = 'public' 
      AND table_name = 'tutor_earnings'
    ) THEN '✅ EXISTS'
    ELSE '❌ MISSING'
  END as status;

-- ============================================
-- DONE! Both tables should now exist
-- ============================================

