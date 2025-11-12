-- ======================================================
-- MIGRATION 023: Consolidate Redundant Fields
-- Merges duplicate fields and standardizes data structure
-- ======================================================

-- ========================================
-- 1. CONSOLIDATE VIDEO FIELDS
-- ========================================
-- Standardize on: video_url (primary), video_link (deprecated but kept for compatibility)
-- Merge video_intro into video_url if video_url is empty

DO $$ 
BEGIN
  -- Update video_url from video_intro if video_url is empty
  UPDATE public.tutor_profiles
  SET video_url = video_intro
  WHERE (video_url IS NULL OR video_url = '')
    AND video_intro IS NOT NULL
    AND video_intro != '';
    
  -- Update video_url from video_link if video_url is still empty
  UPDATE public.tutor_profiles
  SET video_url = video_link
  WHERE (video_url IS NULL OR video_url = '')
    AND video_link IS NOT NULL
    AND video_link != '';
    
  -- Sync video_link to video_url for backward compatibility
  UPDATE public.tutor_profiles
  SET video_link = video_url
  WHERE video_url IS NOT NULL
    AND video_url != ''
    AND (video_link IS NULL OR video_link = '');
END $$;

-- ========================================
-- 2. CONSOLIDATE SUBJECTS/SPECIALIZATIONS
-- ========================================
-- Standardize on: subjects (primary), specializations (deprecated but kept)
-- Merge specializations into subjects if subjects is empty

DO $$ 
BEGIN
  -- Merge specializations into subjects if subjects is empty
  UPDATE public.tutor_profiles
  SET subjects = specializations
  WHERE (subjects IS NULL OR array_length(subjects, 1) IS NULL OR array_length(subjects, 1) = 0)
    AND specializations IS NOT NULL
    AND array_length(specializations, 1) IS NOT NULL
    AND array_length(specializations, 1) > 0;
    
  -- Sync specializations to subjects for backward compatibility
  UPDATE public.tutor_profiles
  SET specializations = subjects
  WHERE subjects IS NOT NULL
    AND array_length(subjects, 1) IS NOT NULL
    AND array_length(subjects, 1) > 0
    AND (specializations IS NULL OR array_length(specializations, 1) IS NULL OR array_length(specializations, 1) = 0);
END $$;

-- ========================================
-- 3. CONSOLIDATE PHONE FIELDS
-- ========================================
-- Standardize on: phone_number (primary), whatsapp_number (optional, separate)
-- Keep both but ensure phone_number is populated

DO $$ 
BEGIN
  -- Update phone_number from whatsapp_number if phone_number is empty
  UPDATE public.tutor_profiles
  SET phone_number = whatsapp_number
  WHERE (phone_number IS NULL OR phone_number = '')
    AND whatsapp_number IS NOT NULL
    AND whatsapp_number != '';
END $$;

-- ========================================
-- 4. CONSOLIDATE CERTIFICATIONS
-- ========================================
-- Standardize on: certificates_urls (JSONB array of URLs)
-- Merge certifications JSONB into certificates_urls if certificates_urls is empty

DO $$ 
BEGIN
  -- Extract URLs from certifications JSONB and merge into certificates_urls
  UPDATE public.tutor_profiles
  SET certificates_urls = COALESCE(
    certificates_urls,
    CASE 
      WHEN certifications IS NOT NULL 
        AND jsonb_typeof(certifications) = 'array'
      THEN certifications
      WHEN certifications IS NOT NULL 
        AND jsonb_typeof(certifications) = 'object'
        AND certifications ? 'urls'
      THEN certifications->'urls'
      ELSE '[]'::jsonb
    END
  )
  WHERE (certificates_urls IS NULL 
    OR certificates_urls = '[]'::jsonb
    OR jsonb_array_length(certificates_urls) = 0)
    AND certifications IS NOT NULL;
END $$;

-- ========================================
-- 5. CONSOLIDATE BIO/MOTIVATION/PERSONAL_STATEMENT
-- ========================================
-- Standardize on: personal_statement (primary for teaching style)
-- bio (for short bio/about section)
-- Merge motivation into bio if bio is empty

DO $$ 
BEGIN
  -- Merge motivation into bio if bio is empty
  UPDATE public.tutor_profiles
  SET bio = motivation
  WHERE (bio IS NULL OR bio = '')
    AND motivation IS NOT NULL
    AND motivation != '';
    
  -- If personal_statement is empty but bio exists, use bio
  UPDATE public.tutor_profiles
  SET personal_statement = bio
  WHERE (personal_statement IS NULL OR personal_statement = '')
    AND bio IS NOT NULL
    AND bio != '';
END $$;

-- ========================================
-- 6. CONSOLIDATE AVAILABILITY FIELDS
-- ========================================
-- Standardize on: tutoring_availability (primary for recurring sessions)
-- test_session_availability (for trial sessions)
-- Merge availability and availability_schedule into tutoring_availability

DO $$ 
BEGIN
  -- Merge availability into tutoring_availability if tutoring_availability is empty
  UPDATE public.tutor_profiles
  SET tutoring_availability = availability
  WHERE (tutoring_availability IS NULL OR tutoring_availability = '{}'::jsonb)
    AND availability IS NOT NULL
    AND availability != '{}'::jsonb;
    
  -- Merge availability_schedule into tutoring_availability if tutoring_availability is still empty
  UPDATE public.tutor_profiles
  SET tutoring_availability = availability_schedule
  WHERE (tutoring_availability IS NULL OR tutoring_availability = '{}'::jsonb)
    AND availability_schedule IS NOT NULL
    AND availability_schedule != '{}'::jsonb;
    
  -- Sync availability to tutoring_availability for backward compatibility
  UPDATE public.tutor_profiles
  SET availability = tutoring_availability
  WHERE tutoring_availability IS NOT NULL
    AND tutoring_availability != '{}'::jsonb
    AND (availability IS NULL OR availability = '{}'::jsonb);
END $$;

-- ========================================
-- 7. CONSOLIDATE EDUCATION DATA
-- ========================================
-- Standardize on: education (JSONB object with structure)
-- Merge highest_education, institution, field_of_study into education JSONB

DO $$ 
BEGIN
  -- Build education JSONB from individual fields if education is empty
  UPDATE public.tutor_profiles
  SET education = jsonb_build_object(
    'highest_education', highest_education,
    'institution', institution,
    'field_of_study', field_of_study
  )
  WHERE (education IS NULL OR education = '{}'::jsonb)
    AND (highest_education IS NOT NULL OR institution IS NOT NULL OR field_of_study IS NOT NULL);
    
  -- If education exists but individual fields are empty, extract them
  UPDATE public.tutor_profiles
  SET 
    highest_education = COALESCE(highest_education, education->>'highest_education'),
    institution = COALESCE(institution, education->>'institution'),
    field_of_study = COALESCE(field_of_study, education->>'field_of_study')
  WHERE education IS NOT NULL
    AND education != '{}'::jsonb
    AND (highest_education IS NULL OR institution IS NULL OR field_of_study IS NULL);
END $$;

-- ========================================
-- 8. ADD COMMENTS FOR DOCUMENTATION
-- ========================================

COMMENT ON COLUMN public.tutor_profiles.video_url IS 'Primary video URL field. video_link and video_intro are deprecated but kept for backward compatibility.';
COMMENT ON COLUMN public.tutor_profiles.subjects IS 'Primary subjects array. specializations is deprecated but kept for backward compatibility.';
COMMENT ON COLUMN public.tutor_profiles.certificates_urls IS 'Primary certificates array (JSONB). certifications is deprecated but kept for backward compatibility.';
COMMENT ON COLUMN public.tutor_profiles.personal_statement IS 'Primary teaching style/bio field. bio is for short about section, motivation is deprecated.';
COMMENT ON COLUMN public.tutor_profiles.tutoring_availability IS 'Primary availability schedule for recurring sessions. availability and availability_schedule are deprecated but kept for backward compatibility.';
COMMENT ON COLUMN public.tutor_profiles.education IS 'Primary education data (JSONB with highest_education, institution, field_of_study). Individual fields are kept for backward compatibility.';

-- ========================================
-- 9. CREATE INDEXES FOR PERFORMANCE
-- ========================================

CREATE INDEX IF NOT EXISTS idx_tutor_profiles_video_url 
ON public.tutor_profiles(video_url) 
WHERE video_url IS NOT NULL AND video_url != '';

CREATE INDEX IF NOT EXISTS idx_tutor_profiles_subjects 
ON public.tutor_profiles USING gin(subjects) 
WHERE subjects IS NOT NULL AND array_length(subjects, 1) > 0;

-- ========================================
-- 10. SUMMARY
-- ========================================

DO $$ 
BEGIN
  RAISE NOTICE '✅ Migration 023 complete: Consolidated redundant fields';
  RAISE NOTICE '   - Video: video_url (primary), video_link/video_intro (deprecated)';
  RAISE NOTICE '   - Subjects: subjects (primary), specializations (deprecated)';
  RAISE NOTICE '   - Certifications: certificates_urls (primary), certifications (deprecated)';
  RAISE NOTICE '   - Bio: personal_statement (primary), bio (short), motivation (deprecated)';
  RAISE NOTICE '   - Availability: tutoring_availability (primary), availability/availability_schedule (deprecated)';
  RAISE NOTICE '   - Education: education JSONB (primary), individual fields (backward compatibility)';
END $$;


