-- Migration Verification Script
-- Run this in Supabase SQL Editor to check migration status

-- 1. Check if session_feedback table exists
SELECT 
    CASE 
        WHEN EXISTS (
            SELECT 1 FROM information_schema.tables 
            WHERE table_schema = 'public' AND table_name = 'session_feedback'
        ) THEN '✅ session_feedback table exists'
        ELSE '❌ session_feedback table MISSING'
    END as table_status;

-- 2. Check all required columns in session_feedback
SELECT 
    column_name,
    data_type,
    CASE 
        WHEN column_name IN (
            'id', 'session_id', 'recurring_session_id',
            'student_rating', 'student_review', 'student_what_went_well',
            'student_what_could_improve', 'student_would_recommend',
            'student_feedback_submitted_at',
            'tutor_notes', 'tutor_progress_notes', 'tutor_homework_assigned',
            'tutor_next_focus_areas', 'tutor_student_engagement',
            'tutor_feedback_submitted_at',
            'tutor_response', 'tutor_response_submitted_at',
            'feedback_processed', 'tutor_rating_updated', 'review_displayed',
            'created_at', 'updated_at'
        ) THEN '✅'
        ELSE '⚠️'
    END as status
FROM information_schema.columns
WHERE table_schema = 'public' 
AND table_name = 'session_feedback'
ORDER BY ordinal_position;

-- 3. Check indexes
SELECT 
    indexname,
    CASE 
        WHEN indexname LIKE '%session_feedback%' THEN '✅'
        ELSE '⚠️'
    END as status
FROM pg_indexes
WHERE tablename = 'session_feedback';

-- 4. Check RLS policies
SELECT 
    policyname,
    CASE 
        WHEN policyname LIKE '%session_feedback%' THEN '✅'
        ELSE '⚠️'
    END as status
FROM pg_policies
WHERE tablename = 'session_feedback';

-- 5. Summary
SELECT 
    (SELECT COUNT(*) FROM information_schema.columns 
     WHERE table_name = 'session_feedback') as total_columns,
    (SELECT COUNT(*) FROM pg_indexes 
     WHERE tablename = 'session_feedback') as total_indexes,
    (SELECT COUNT(*) FROM pg_policies 
     WHERE tablename = 'session_feedback') as total_policies;
