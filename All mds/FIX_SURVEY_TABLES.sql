-- ===================================
-- FIX SURVEY TABLES
-- Run this in Supabase SQL Editor
-- ===================================

-- ===================================
-- 1. CREATE LEARNER_PROFILES TABLE
-- ===================================

CREATE TABLE IF NOT EXISTS learner_profiles (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  
  -- Personal Information
  student_name TEXT,
  date_of_birth DATE,
  gender TEXT,
  
  -- Location
  city TEXT,
  quarter TEXT,
  
  -- Learning Path
  learning_path TEXT,
  education_level TEXT,
  class TEXT,
  stream TEXT,
  subjects TEXT[],
  skill_category TEXT,
  skills TEXT[],
  exam_type TEXT,
  specific_exam TEXT,
  exam_subjects TEXT[],
  
  -- Budget
  min_budget INTEGER,
  max_budget INTEGER,
  
  -- Preferences
  tutor_gender_preference TEXT,
  tutor_qualification TEXT,
  preferred_location TEXT,
  preferred_schedule TEXT,
  learning_style TEXT,
  confidence_level TEXT,
  
  -- Goals & Challenges
  learning_goals TEXT[],
  challenges TEXT[],
  
  -- Timestamps
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  
  UNIQUE(user_id)
);

CREATE INDEX IF NOT EXISTS idx_learner_profiles_user_id ON learner_profiles(user_id);

-- ===================================
-- 2. CREATE PARENT_PROFILES TABLE
-- ===================================

CREATE TABLE IF NOT EXISTS parent_profiles (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  
  -- Child Information
  child_name TEXT,
  child_date_of_birth DATE,
  child_gender TEXT,
  relationship_to_child TEXT,
  
  -- Location
  city TEXT,
  quarter TEXT,
  
  -- Learning Path
  learning_path TEXT,
  education_level TEXT,
  class TEXT,
  stream TEXT,
  subjects TEXT[],
  skill_category TEXT,
  skills TEXT[],
  exam_type TEXT,
  specific_exam TEXT,
  exam_subjects TEXT[],
  
  -- Budget
  min_budget INTEGER,
  max_budget INTEGER,
  
  -- Preferences
  tutor_gender_preference TEXT,
  tutor_qualification TEXT,
  preferred_location TEXT,
  preferred_schedule TEXT,
  child_confidence_level TEXT,
  
  -- Goals & Challenges
  learning_goals TEXT[],
  challenges TEXT[],
  
  -- Timestamps
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  
  UNIQUE(user_id)
);

CREATE INDEX IF NOT EXISTS idx_parent_profiles_user_id ON parent_profiles(user_id);

-- ===================================
-- 3. ENABLE ROW LEVEL SECURITY
-- ===================================

ALTER TABLE learner_profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE parent_profiles ENABLE ROW LEVEL SECURITY;

-- ===================================
-- 4. CREATE RLS POLICIES - LEARNER_PROFILES
-- ===================================

-- Drop existing policies if any
DROP POLICY IF EXISTS "Users can read own learner profile" ON learner_profiles;
DROP POLICY IF EXISTS "Users can insert own learner profile" ON learner_profiles;
DROP POLICY IF EXISTS "Users can update own learner profile" ON learner_profiles;
DROP POLICY IF EXISTS "Users can delete own learner profile" ON learner_profiles;
DROP POLICY IF EXISTS "Admins can read all learner profiles" ON learner_profiles;

-- Create new policies
CREATE POLICY "Users can read own learner profile"
  ON learner_profiles FOR SELECT
  USING (auth.uid() = user_id);

CREATE POLICY "Users can insert own learner profile"
  ON learner_profiles FOR INSERT
  WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update own learner profile"
  ON learner_profiles FOR UPDATE
  USING (auth.uid() = user_id);

CREATE POLICY "Users can delete own learner profile"
  ON learner_profiles FOR DELETE
  USING (auth.uid() = user_id);

CREATE POLICY "Admins can read all learner profiles"
  ON learner_profiles FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM profiles
      WHERE profiles.id = auth.uid()
      AND profiles.is_admin = true
    )
  );

-- ===================================
-- 5. CREATE RLS POLICIES - PARENT_PROFILES
-- ===================================

-- Drop existing policies if any
DROP POLICY IF EXISTS "Users can read own parent profile" ON parent_profiles;
DROP POLICY IF EXISTS "Users can insert own parent profile" ON parent_profiles;
DROP POLICY IF EXISTS "Users can update own parent profile" ON parent_profiles;
DROP POLICY IF EXISTS "Users can delete own parent profile" ON parent_profiles;
DROP POLICY IF EXISTS "Admins can read all parent profiles" ON parent_profiles;

-- Create new policies
CREATE POLICY "Users can read own parent profile"
  ON parent_profiles FOR SELECT
  USING (auth.uid() = user_id);

CREATE POLICY "Users can insert own parent profile"
  ON parent_profiles FOR INSERT
  WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update own parent profile"
  ON parent_profiles FOR UPDATE
  USING (auth.uid() = user_id);

CREATE POLICY "Users can delete own parent profile"
  ON parent_profiles FOR DELETE
  USING (auth.uid() = user_id);

CREATE POLICY "Admins can read all parent profiles"
  ON parent_profiles FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM profiles
      WHERE profiles.id = auth.uid()
      AND profiles.is_admin = true
    )
  );

-- ===================================
-- 6. CREATE UPDATE TRIGGERS
-- ===================================

-- Learner profiles trigger
CREATE OR REPLACE FUNCTION update_learner_profiles_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS learner_profiles_updated_at ON learner_profiles;
CREATE TRIGGER learner_profiles_updated_at
  BEFORE UPDATE ON learner_profiles
  FOR EACH ROW
  EXECUTE FUNCTION update_learner_profiles_updated_at();

-- Parent profiles trigger
CREATE OR REPLACE FUNCTION update_parent_profiles_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS parent_profiles_updated_at ON parent_profiles;
CREATE TRIGGER parent_profiles_updated_at
  BEFORE UPDATE ON parent_profiles
  FOR EACH ROW
  EXECUTE FUNCTION update_parent_profiles_updated_at();

-- ===================================
-- 7. GRANT PERMISSIONS
-- ===================================

GRANT ALL ON learner_profiles TO authenticated;
GRANT ALL ON learner_profiles TO service_role;
GRANT ALL ON parent_profiles TO authenticated;
GRANT ALL ON parent_profiles TO service_role;

-- ===================================
-- DONE!
-- ===================================

SELECT 'Survey tables created successfully! ✅' AS status;

