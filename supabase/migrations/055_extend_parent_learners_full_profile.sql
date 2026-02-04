-- ======================================================
-- MIGRATION 055: Extend parent_learners with full child profile data
-- Stores complete child information for tutor matching, algorithms, and analytics
-- ======================================================

-- Add all child profile fields to parent_learners table
ALTER TABLE public.parent_learners
  -- Basic child info
  ADD COLUMN IF NOT EXISTS date_of_birth DATE,
  ADD COLUMN IF NOT EXISTS gender TEXT,
  ADD COLUMN IF NOT EXISTS relationship_to_child TEXT,
  
  -- Learning path and academic details
  ADD COLUMN IF NOT EXISTS learning_path TEXT, -- 'Academic Tutoring', 'Skill Development', 'Exam Preparation'
  ADD COLUMN IF NOT EXISTS stream TEXT,
  ADD COLUMN IF NOT EXISTS subjects TEXT[], -- Array of subjects
  ADD COLUMN IF NOT EXISTS university_courses TEXT,
  
  -- Skill development
  ADD COLUMN IF NOT EXISTS skill_category TEXT,
  ADD COLUMN IF NOT EXISTS skills TEXT[], -- Array of skills
  
  -- Exam preparation
  ADD COLUMN IF NOT EXISTS exam_type TEXT,
  ADD COLUMN IF NOT EXISTS specific_exam TEXT,
  ADD COLUMN IF NOT EXISTS exam_subjects TEXT[], -- Array of exam subjects
  
  -- Learning preferences and goals
  ADD COLUMN IF NOT EXISTS confidence_level TEXT,
  ADD COLUMN IF NOT EXISTS learning_goals TEXT[], -- Array of goals
  ADD COLUMN IF NOT EXISTS challenges TEXT[], -- Array of challenges
  
  -- Tutor preferences (per child)
  ADD COLUMN IF NOT EXISTS tutor_gender_preference TEXT,
  ADD COLUMN IF NOT EXISTS tutor_qualification_preference TEXT,
  ADD COLUMN IF NOT EXISTS preferred_location TEXT,
  ADD COLUMN IF NOT EXISTS preferred_schedule TEXT[]; -- Array of schedule preferences

-- Add comments for documentation
COMMENT ON COLUMN public.parent_learners.date_of_birth IS 'Child date of birth for age calculation and age-appropriate tutor matching';
COMMENT ON COLUMN public.parent_learners.gender IS 'Child gender';
COMMENT ON COLUMN public.parent_learners.relationship_to_child IS 'Parent relationship (Parent, Guardian, Family Member, Other)';
COMMENT ON COLUMN public.parent_learners.learning_path IS 'Learning path: Academic Tutoring, Skill Development, or Exam Preparation';
COMMENT ON COLUMN public.parent_learners.subjects IS 'Array of subjects child needs help with (for Academic Tutoring)';
COMMENT ON COLUMN public.parent_learners.skills IS 'Array of skills child wants to learn (for Skill Development)';
COMMENT ON COLUMN public.parent_learners.exam_subjects IS 'Array of exam subjects (for Exam Preparation)';
COMMENT ON COLUMN public.parent_learners.learning_goals IS 'Array of learning goals for personalized tutor matching';
COMMENT ON COLUMN public.parent_learners.challenges IS 'Array of challenges child faces for tutor advice and matching';
COMMENT ON COLUMN public.parent_learners.tutor_gender_preference IS 'Preferred tutor gender for this child';
COMMENT ON COLUMN public.parent_learners.preferred_schedule IS 'Array of preferred schedule times for this child';

-- Create index on learning_path for faster tutor matching queries
CREATE INDEX IF NOT EXISTS idx_parent_learners_learning_path ON public.parent_learners(learning_path);

-- Create index on education_level for level-based matching
CREATE INDEX IF NOT EXISTS idx_parent_learners_education_level ON public.parent_learners(education_level);
