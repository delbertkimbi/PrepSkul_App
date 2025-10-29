-- ===================================
-- CREATE PARENT_PROFILES TABLE
-- ===================================
-- This table stores parent survey data

-- Drop table if exists (for clean setup)
-- DROP TABLE IF EXISTS parent_profiles CASCADE;

-- Create parent_profiles table
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
  child_confidence_level TEXT,
  
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
CREATE INDEX IF NOT EXISTS idx_parent_profiles_user_id ON parent_profiles(user_id);

-- Enable Row Level Security
ALTER TABLE parent_profiles ENABLE ROW LEVEL SECURITY;

-- RLS Policies
-- Users can read their own profile
CREATE POLICY "Users can read own parent profile"
  ON parent_profiles FOR SELECT
  USING (auth.uid() = user_id);

-- Users can insert their own profile
CREATE POLICY "Users can insert own parent profile"
  ON parent_profiles FOR INSERT
  WITH CHECK (auth.uid() = user_id);

-- Users can update their own profile
CREATE POLICY "Users can update own parent profile"
  ON parent_profiles FOR UPDATE
  USING (auth.uid() = user_id);

-- Users can delete their own profile
CREATE POLICY "Users can delete own parent profile"
  ON parent_profiles FOR DELETE
  USING (auth.uid() = user_id);

-- Admins can read all profiles
CREATE POLICY "Admins can read all parent profiles"
  ON parent_profiles FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM profiles
      WHERE profiles.id = auth.uid()
      AND profiles.is_admin = true
    )
  );

-- Create updated_at trigger
CREATE OR REPLACE FUNCTION update_parent_profiles_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER parent_profiles_updated_at
  BEFORE UPDATE ON parent_profiles
  FOR EACH ROW
  EXECUTE FUNCTION update_parent_profiles_updated_at();

-- Grant permissions
GRANT ALL ON parent_profiles TO authenticated;
GRANT ALL ON parent_profiles TO service_role;

-- Success message
DO $$
BEGIN
  RAISE NOTICE 'parent_profiles table created successfully!';
END $$;

