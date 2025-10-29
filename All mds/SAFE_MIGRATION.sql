-- ================================================
-- SAFE DATABASE MIGRATION
-- This adds missing columns WITHOUT deleting data
-- Safe to run on production with real users
-- ================================================

-- STEP 1: Add missing columns to tutor_profiles (if they don't exist)
DO $$ 
BEGIN
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns 
                   WHERE table_name='tutor_profiles' AND column_name='bio') THEN
        ALTER TABLE public.tutor_profiles ADD COLUMN bio TEXT;
    END IF;
    
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns 
                   WHERE table_name='tutor_profiles' AND column_name='education') THEN
        ALTER TABLE public.tutor_profiles ADD COLUMN education TEXT;
    END IF;
    
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns 
                   WHERE table_name='tutor_profiles' AND column_name='experience') THEN
        ALTER TABLE public.tutor_profiles ADD COLUMN experience TEXT;
    END IF;
    
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns 
                   WHERE table_name='tutor_profiles' AND column_name='subjects') THEN
        ALTER TABLE public.tutor_profiles ADD COLUMN subjects TEXT[];
    END IF;
    
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns 
                   WHERE table_name='tutor_profiles' AND column_name='hourly_rate') THEN
        ALTER TABLE public.tutor_profiles ADD COLUMN hourly_rate DECIMAL(10, 2);
    END IF;
    
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns 
                   WHERE table_name='tutor_profiles' AND column_name='availability') THEN
        ALTER TABLE public.tutor_profiles ADD COLUMN availability JSONB;
    END IF;
    
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns 
                   WHERE table_name='tutor_profiles' AND column_name='is_verified') THEN
        ALTER TABLE public.tutor_profiles ADD COLUMN is_verified BOOLEAN DEFAULT FALSE;
    END IF;
    
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns 
                   WHERE table_name='tutor_profiles' AND column_name='rating') THEN
        ALTER TABLE public.tutor_profiles ADD COLUMN rating DECIMAL(3, 2);
    END IF;
END $$;

-- STEP 2: Add missing columns to learner_profiles (if they don't exist)
DO $$ 
BEGIN
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns 
                   WHERE table_name='learner_profiles' AND column_name='grade_level') THEN
        ALTER TABLE public.learner_profiles ADD COLUMN grade_level TEXT;
    END IF;
    
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns 
                   WHERE table_name='learner_profiles' AND column_name='school') THEN
        ALTER TABLE public.learner_profiles ADD COLUMN school TEXT;
    END IF;
    
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns 
                   WHERE table_name='learner_profiles' AND column_name='subjects') THEN
        ALTER TABLE public.learner_profiles ADD COLUMN subjects TEXT[];
    END IF;
    
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns 
                   WHERE table_name='learner_profiles' AND column_name='learning_goals') THEN
        ALTER TABLE public.learner_profiles ADD COLUMN learning_goals TEXT;
    END IF;
    
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns 
                   WHERE table_name='learner_profiles' AND column_name='parent_id') THEN
        ALTER TABLE public.learner_profiles ADD COLUMN parent_id UUID REFERENCES public.profiles(id);
    END IF;
END $$;

-- STEP 3: Add missing columns to profiles (if they don't exist)
DO $$ 
BEGIN
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns 
                   WHERE table_name='profiles' AND column_name='phone_number') THEN
        ALTER TABLE public.profiles ADD COLUMN phone_number TEXT;
    END IF;
    
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns 
                   WHERE table_name='profiles' AND column_name='avatar_url') THEN
        ALTER TABLE public.profiles ADD COLUMN avatar_url TEXT;
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

-- STEP 4: Fix user_type constraint (safely)
DO $$ 
BEGIN
    -- Drop old constraint if it exists
    ALTER TABLE public.profiles DROP CONSTRAINT IF EXISTS profiles_user_type_check;
    
    -- Add new constraint with correct values
    ALTER TABLE public.profiles 
    ADD CONSTRAINT profiles_user_type_check 
    CHECK (user_type IN ('learner', 'tutor', 'parent'));
END $$;

-- STEP 5: Ensure lessons table has all required columns
DO $$ 
BEGIN
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns 
                   WHERE table_name='lessons' AND column_name='subject') THEN
        ALTER TABLE public.lessons ADD COLUMN subject TEXT NOT NULL DEFAULT 'General';
    END IF;
    
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns 
                   WHERE table_name='lessons' AND column_name='description') THEN
        ALTER TABLE public.lessons ADD COLUMN description TEXT;
    END IF;
    
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns 
                   WHERE table_name='lessons' AND column_name='start_time') THEN
        ALTER TABLE public.lessons ADD COLUMN start_time TIMESTAMP WITH TIME ZONE;
    END IF;
    
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns 
                   WHERE table_name='lessons' AND column_name='end_time') THEN
        ALTER TABLE public.lessons ADD COLUMN end_time TIMESTAMP WITH TIME ZONE;
    END IF;
    
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns 
                   WHERE table_name='lessons' AND column_name='status') THEN
        ALTER TABLE public.lessons ADD COLUMN status TEXT DEFAULT 'scheduled';
    END IF;
    
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns 
                   WHERE table_name='lessons' AND column_name='meeting_link') THEN
        ALTER TABLE public.lessons ADD COLUMN meeting_link TEXT;
    END IF;
END $$;

-- STEP 6: Ensure payments table has all required columns
DO $$ 
BEGIN
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns 
                   WHERE table_name='payments' AND column_name='amount') THEN
        ALTER TABLE public.payments ADD COLUMN amount DECIMAL(10, 2) NOT NULL DEFAULT 0;
    END IF;
    
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns 
                   WHERE table_name='payments' AND column_name='currency') THEN
        ALTER TABLE public.payments ADD COLUMN currency TEXT DEFAULT 'XAF';
    END IF;
    
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns 
                   WHERE table_name='payments' AND column_name='status') THEN
        ALTER TABLE public.payments ADD COLUMN status TEXT DEFAULT 'pending';
    END IF;
    
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns 
                   WHERE table_name='payments' AND column_name='payment_method') THEN
        ALTER TABLE public.payments ADD COLUMN payment_method TEXT;
    END IF;
    
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns 
                   WHERE table_name='payments' AND column_name='transaction_id') THEN
        ALTER TABLE public.payments ADD COLUMN transaction_id TEXT;
    END IF;
END $$;

-- ================================================
-- SUCCESS! Database schema updated safely
-- ================================================
-- All your existing users and data are preserved
-- New columns added for future features
-- ================================================

