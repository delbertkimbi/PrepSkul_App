-- ===================================
-- CREATE LEARNER_PROFILES TABLE
-- ===================================
-- This table stores student survey data

-- Drop table if exists (for clean setup)
-- DROP TABLE IF EXISTS learner_profiles CASCADE;

-- Create learner_profiles table
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
  learning_path TEXT, -- 'Academic', 'Skills', 'Exam Preparation'
  education_level TEXT,
  class TEXT,
  stream TEXT,
  subjects TEXT[], -- Array of subjects
  skill_category TEXT,
  skills TEXT[], -- Array of skills
  exam_type TEXT,
  specific_exam TEXT,
  exam_subjects TEXT[], -- Array of exam subjects
  
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
  learning_goals TEXT[], -- Array of goals
  challenges TEXT[], -- Array of challenges
  
  -- Timestamps
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  
  -- Ensure one profile per user
  UNIQUE(user_id)
);

-- Create index for faster lookups
CREATE INDEX IF NOT EXISTS idx_learner_profiles_user_id ON learner_profiles(user_id);

-- Enable Row Level Security
ALTER TABLE learner_profiles ENABLE ROW LEVEL SECURITY;

-- RLS Policies
-- Users can read their own profile
CREATE POLICY "Users can read own learner profile"
  ON learner_profiles FOR SELECT
  USING (auth.uid() = user_id);

-- Users can insert their own profile
CREATE POLICY "Users can insert own learner profile"
  ON learner_profiles FOR INSERT
  WITH CHECK (auth.uid() = user_id);

-- Users can update their own profile
CREATE POLICY "Users can update own learner profile"
  ON learner_profiles FOR UPDATE
  USING (auth.uid() = user_id);

-- Users can delete their own profile
CREATE POLICY "Users can delete own learner profile"
  ON learner_profiles FOR DELETE
  USING (auth.uid() = user_id);

-- Admins can read all profiles
CREATE POLICY "Admins can read all learner profiles"
  ON learner_profiles FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM profiles
      WHERE profiles.id = auth.uid()
      AND profiles.is_admin = true
    )
  );

-- Create updated_at trigger
CREATE OR REPLACE FUNCTION update_learner_profiles_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER learner_profiles_updated_at
  BEFORE UPDATE ON learner_profiles
  FOR EACH ROW
  EXECUTE FUNCTION update_learner_profiles_updated_at();

-- Grant permissions
GRANT ALL ON learner_profiles TO authenticated;
GRANT ALL ON learner_profiles TO service_role;

-- Success message
DO $$
BEGIN
  RAISE NOTICE 'learner_profiles table created successfully!';
END $$;

