-- ================================================
-- CREATE ALL MISSING TABLES FOR PREPSKUL
-- Including Fapshi payment integration support
-- ================================================

-- STEP 1: Fix user_type constraint
ALTER TABLE public.profiles DROP CONSTRAINT IF EXISTS profiles_user_type_check;
ALTER TABLE public.profiles 
ADD CONSTRAINT profiles_user_type_check 
CHECK (user_type IN ('learner', 'tutor', 'parent'));

-- STEP 2: Add required columns to profiles
ALTER TABLE public.profiles
ADD COLUMN IF NOT EXISTS phone_number TEXT;

ALTER TABLE public.profiles
ADD COLUMN IF NOT EXISTS last_seen TIMESTAMP WITH TIME ZONE DEFAULT NOW();

-- STEP 3: Create lessons table (for tutoring sessions)
CREATE TABLE IF NOT EXISTS public.lessons (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  tutor_id UUID REFERENCES public.profiles(id) ON DELETE CASCADE,
  learner_id UUID REFERENCES public.profiles(id) ON DELETE CASCADE,
  subject TEXT NOT NULL,
  description TEXT,
  start_time TIMESTAMP WITH TIME ZONE NOT NULL,
  end_time TIMESTAMP WITH TIME ZONE NOT NULL,
  status TEXT DEFAULT 'scheduled' CHECK (status IN ('scheduled', 'in_progress', 'completed', 'cancelled')),
  meeting_link TEXT,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- STEP 4: Create payments table (Fapshi integration ready)
CREATE TABLE IF NOT EXISTS public.payments (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  lesson_id UUID REFERENCES public.lessons(id) ON DELETE SET NULL,
  payer_id UUID REFERENCES public.profiles(id) ON DELETE CASCADE,
  
  -- Payment amount details
  amount DECIMAL(10, 2) NOT NULL,
  currency TEXT DEFAULT 'XAF' CHECK (currency IN ('XAF', 'USD', 'EUR')),
  
  -- Payment status
  status TEXT DEFAULT 'pending' CHECK (status IN ('pending', 'completed', 'failed', 'expired', 'refunded')),
  
  -- Payment method (Fapshi supports MTN, Orange Money, etc.)
  payment_method TEXT CHECK (payment_method IN ('MTN Mobile Money', 'Orange Money', 'Express Union', 'Card', 'Other')),
  
  -- Fapshi integration fields
  fapshi_transaction_id TEXT UNIQUE, -- Fapshi's transaction reference
  fapshi_payment_link TEXT, -- Generated payment link from Fapshi
  fapshi_status TEXT, -- Raw status from Fapshi API
  fapshi_response JSONB, -- Full response from Fapshi for debugging
  
  -- Internal transaction tracking
  transaction_id TEXT UNIQUE, -- Our internal transaction ID
  transaction_reference TEXT, -- Reference shown to user (e.g., "PAY-2025-001234")
  
  -- Additional metadata
  description TEXT,
  metadata JSONB, -- Store any additional payment metadata
  
  -- Timestamps
  paid_at TIMESTAMP WITH TIME ZONE,
  expires_at TIMESTAMP WITH TIME ZONE,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- STEP 5: Create payment_webhooks table (for Fapshi webhook callbacks)
CREATE TABLE IF NOT EXISTS public.payment_webhooks (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  payment_id UUID REFERENCES public.payments(id) ON DELETE CASCADE,
  
  -- Webhook data
  event_type TEXT NOT NULL, -- e.g., 'payment.successful', 'payment.failed'
  payload JSONB NOT NULL, -- Full webhook payload from Fapshi
  
  -- Processing status
  processed BOOLEAN DEFAULT false,
  processed_at TIMESTAMP WITH TIME ZONE,
  error_message TEXT,
  
  -- Timestamps
  received_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- STEP 6: Create bookings table (lesson booking requests)
CREATE TABLE IF NOT EXISTS public.bookings (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  learner_id UUID REFERENCES public.profiles(id) ON DELETE CASCADE,
  tutor_id UUID REFERENCES public.profiles(id) ON DELETE CASCADE,
  
  -- Booking details
  subject TEXT NOT NULL,
  preferred_date DATE,
  preferred_time TIME,
  duration_minutes INTEGER DEFAULT 60,
  message TEXT, -- Message from learner to tutor
  
  -- Status
  status TEXT DEFAULT 'pending' CHECK (status IN ('pending', 'accepted', 'rejected', 'expired')),
  
  -- If accepted, linked to a lesson
  lesson_id UUID REFERENCES public.lessons(id) ON DELETE SET NULL,
  
  -- Timestamps
  expires_at TIMESTAMP WITH TIME ZONE DEFAULT (NOW() + INTERVAL '48 hours'),
  responded_at TIMESTAMP WITH TIME ZONE,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- STEP 7: Create tutor_availability table
CREATE TABLE IF NOT EXISTS public.tutor_availability (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  tutor_id UUID REFERENCES public.profiles(id) ON DELETE CASCADE,
  
  -- Day of week (0 = Sunday, 6 = Saturday)
  day_of_week INTEGER CHECK (day_of_week BETWEEN 0 AND 6),
  
  -- Time slots
  start_time TIME NOT NULL,
  end_time TIME NOT NULL,
  
  -- Active status
  is_active BOOLEAN DEFAULT true,
  
  -- Timestamps
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  
  UNIQUE(tutor_id, day_of_week, start_time, end_time)
);

-- STEP 8: Create reviews table (student reviews for tutors)
CREATE TABLE IF NOT EXISTS public.reviews (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  tutor_id UUID REFERENCES public.profiles(id) ON DELETE CASCADE,
  learner_id UUID REFERENCES public.profiles(id) ON DELETE CASCADE,
  lesson_id UUID REFERENCES public.lessons(id) ON DELETE CASCADE,
  
  -- Review content
  rating INTEGER NOT NULL CHECK (rating BETWEEN 1 AND 5),
  comment TEXT,
  
  -- Status (allow admin moderation)
  status TEXT DEFAULT 'published' CHECK (status IN ('published', 'hidden', 'flagged')),
  
  -- Timestamps
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  
  UNIQUE(lesson_id, learner_id) -- One review per lesson per learner
);

-- STEP 9: Enable Row Level Security
ALTER TABLE public.lessons ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.payments ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.payment_webhooks ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.bookings ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.tutor_availability ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.reviews ENABLE ROW LEVEL SECURITY;

-- STEP 10: Create update trigger function (if not exists)
CREATE OR REPLACE FUNCTION update_modified_column()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- STEP 11: Add update triggers to all tables
DROP TRIGGER IF EXISTS update_lessons_modtime ON public.lessons;
CREATE TRIGGER update_lessons_modtime
BEFORE UPDATE ON public.lessons
FOR EACH ROW EXECUTE FUNCTION update_modified_column();

DROP TRIGGER IF EXISTS update_payments_modtime ON public.payments;
CREATE TRIGGER update_payments_modtime
BEFORE UPDATE ON public.payments
FOR EACH ROW EXECUTE FUNCTION update_modified_column();

DROP TRIGGER IF EXISTS update_bookings_modtime ON public.bookings;
CREATE TRIGGER update_bookings_modtime
BEFORE UPDATE ON public.bookings
FOR EACH ROW EXECUTE FUNCTION update_modified_column();

DROP TRIGGER IF EXISTS update_tutor_availability_modtime ON public.tutor_availability;
CREATE TRIGGER update_tutor_availability_modtime
BEFORE UPDATE ON public.tutor_availability
FOR EACH ROW EXECUTE FUNCTION update_modified_column();

DROP TRIGGER IF EXISTS update_reviews_modtime ON public.reviews;
CREATE TRIGGER update_reviews_modtime
BEFORE UPDATE ON public.reviews
FOR EACH ROW EXECUTE FUNCTION update_modified_column();

-- STEP 12: Create indexes for performance
CREATE INDEX IF NOT EXISTS idx_lessons_tutor_id ON public.lessons(tutor_id);
CREATE INDEX IF NOT EXISTS idx_lessons_learner_id ON public.lessons(learner_id);
CREATE INDEX IF NOT EXISTS idx_lessons_status ON public.lessons(status);
CREATE INDEX IF NOT EXISTS idx_lessons_start_time ON public.lessons(start_time);

CREATE INDEX IF NOT EXISTS idx_payments_lesson_id ON public.payments(lesson_id);
CREATE INDEX IF NOT EXISTS idx_payments_payer_id ON public.payments(payer_id);
CREATE INDEX IF NOT EXISTS idx_payments_status ON public.payments(status);
CREATE INDEX IF NOT EXISTS idx_payments_fapshi_transaction_id ON public.payments(fapshi_transaction_id);

CREATE INDEX IF NOT EXISTS idx_bookings_learner_id ON public.bookings(learner_id);
CREATE INDEX IF NOT EXISTS idx_bookings_tutor_id ON public.bookings(tutor_id);
CREATE INDEX IF NOT EXISTS idx_bookings_status ON public.bookings(status);

CREATE INDEX IF NOT EXISTS idx_tutor_availability_tutor_id ON public.tutor_availability(tutor_id);
CREATE INDEX IF NOT EXISTS idx_reviews_tutor_id ON public.reviews(tutor_id);

-- ================================================
-- SUCCESS! All tables created
-- ================================================
-- Tables created:
-- ✅ lessons (tutoring sessions)
-- ✅ payments (with Fapshi integration support)
-- ✅ payment_webhooks (Fapshi callbacks)
-- ✅ bookings (lesson requests)
-- ✅ tutor_availability (schedule management)
-- ✅ reviews (student feedback)
--
-- Fapshi integration ready:
-- - payment_method supports MTN Mobile Money, Orange Money, etc.
-- - fapshi_transaction_id for tracking
-- - fapshi_payment_link for checkout
-- - payment_webhooks table for callbacks
-- ================================================

