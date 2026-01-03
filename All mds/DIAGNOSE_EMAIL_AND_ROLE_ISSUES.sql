-- ============================================
-- DIAGNOSE EMAIL AND ROLE ISSUES
-- Run this to identify problems with email assignment and role confusion
-- ============================================

-- STEP 1: Check for duplicate emails in profiles
SELECT 
  'Duplicate Emails in Profiles' as check_type,
  email,
  COUNT(*) as duplicate_count,
  STRING_AGG(id::TEXT, ', ') as user_ids,
  STRING_AGG(full_name, ', ') as names,
  STRING_AGG(user_type, ', ') as user_types
FROM profiles
WHERE email IS NOT NULL AND email != ''
GROUP BY email
HAVING COUNT(*) > 1
ORDER BY duplicate_count DESC;

-- STEP 2: Check for brianleke9@gmail.com specifically
SELECT 
  'brianleke9@gmail.com Users' as check_type,
  p.id,
  p.email,
  p.full_name,
  p.user_type,
  p.created_at,
  u.email as auth_email,
  u.created_at as auth_created_at
FROM profiles p
LEFT JOIN auth.users u ON u.id = p.id
WHERE p.email = 'brianleke9@gmail.com' OR u.email = 'brianleke9@gmail.com'
ORDER BY p.created_at DESC;

-- STEP 3: Check for users with NULL or empty emails
SELECT 
  'Users with Missing Emails' as check_type,
  COUNT(*) as count,
  STRING_AGG(user_type, ', ') as user_types
FROM profiles
WHERE email IS NULL OR email = '';

-- STEP 4: Check trial_sessions for role confusion
SELECT 
  'Trial Sessions Role Analysis' as check_type,
  ts.id,
  ts.requester_id,
  ts.learner_id,
  ts.parent_id,
  rp.user_type as requester_type,
  rp.full_name as requester_name,
  rp.email as requester_email,
  lp.user_type as learner_type,
  lp.full_name as learner_name,
  lp.email as learner_email,
  pp.user_type as parent_type,
  pp.full_name as parent_name,
  pp.email as parent_email
FROM trial_sessions ts
LEFT JOIN profiles rp ON rp.id = ts.requester_id
LEFT JOIN profiles lp ON lp.id = ts.learner_id
LEFT JOIN profiles pp ON pp.id = ts.parent_id
ORDER BY ts.created_at DESC
LIMIT 20;

-- STEP 5: Check for incorrect user_type assignments
SELECT 
  'Incorrect User Type Assignments' as check_type,
  p.id,
  p.email,
  p.full_name,
  p.user_type,
  CASE 
    WHEN EXISTS (SELECT 1 FROM trial_sessions WHERE parent_id = p.id) THEN 'Should be parent'
    WHEN EXISTS (SELECT 1 FROM trial_sessions WHERE requester_id = p.id AND parent_id = p.id) THEN 'Should be parent'
    WHEN EXISTS (SELECT 1 FROM trial_sessions WHERE learner_id = p.id AND parent_id IS NULL) THEN 'Should be learner'
    ELSE 'OK'
  END as expected_role
FROM profiles p
WHERE p.user_type = 'learner'
  AND EXISTS (SELECT 1 FROM trial_sessions WHERE parent_id = p.id OR (requester_id = p.id AND parent_id = p.id))
ORDER BY p.created_at DESC;

-- STEP 6: Check profiles with missing avatar_url but should have one
SELECT 
  'Profiles Missing Avatar URLs' as check_type,
  p.id,
  p.email,
  p.full_name,
  p.user_type,
  p.avatar_url,
  CASE 
    WHEN p.avatar_url IS NULL OR p.avatar_url = '' THEN 'Missing'
    ELSE 'Has Avatar'
  END as avatar_status
FROM profiles p
WHERE (p.avatar_url IS NULL OR p.avatar_url = '')
  AND EXISTS (
    SELECT 1 FROM trial_sessions ts 
    WHERE ts.requester_id = p.id OR ts.learner_id = p.id OR ts.parent_id = p.id
  )
ORDER BY p.created_at DESC
LIMIT 20;

-- STEP 7: Summary of all issues
SELECT 
  'SUMMARY' as check_type,
  (SELECT COUNT(*) FROM profiles WHERE email = 'brianleke9@gmail.com') as brianleke_count,
  (SELECT COUNT(*) FROM profiles WHERE email IS NULL OR email = '') as missing_email_count,
  (SELECT COUNT(*) FROM profiles p WHERE p.user_type = 'learner' AND EXISTS (SELECT 1 FROM trial_sessions WHERE parent_id = p.id)) as incorrect_learner_as_parent,
  (SELECT COUNT(*) FROM profiles WHERE (avatar_url IS NULL OR avatar_url = '') AND EXISTS (SELECT 1 FROM trial_sessions ts WHERE ts.requester_id = profiles.id OR ts.learner_id = profiles.id OR ts.parent_id = profiles.id)) as missing_avatars;

