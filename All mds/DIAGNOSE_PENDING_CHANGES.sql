-- Diagnostic script to check pending_changes for a specific tutor
-- Replace 'USER_ID_HERE' with the actual user_id of the tutor (Leke Brian)

-- 1. Check tutor profile with pending_changes
SELECT 
  id,
  user_id,
  status,
  has_pending_update,
  pending_changes,
  jsonb_typeof(pending_changes) as pending_changes_type,
  CASE 
    WHEN pending_changes IS NULL THEN 'NULL'
    WHEN jsonb_typeof(pending_changes) = 'object' THEN 'OBJECT'
    WHEN jsonb_typeof(pending_changes) = 'string' THEN 'STRING'
    ELSE 'OTHER'
  END as pending_changes_format,
  CASE 
    WHEN pending_changes IS NULL THEN 0
    WHEN jsonb_typeof(pending_changes) = 'object' THEN jsonb_object_keys(pending_changes)::text
    ELSE 0
  END as pending_changes_keys,
  jsonb_array_length(jsonb_object_keys(pending_changes)) as pending_changes_count
FROM tutor_profiles
WHERE user_id = 'USER_ID_HERE'  -- Replace with actual user_id
   OR id = 'USER_ID_HERE';  -- Or use tutor_profiles.id

-- 2. Check all tutors with pending updates
SELECT 
  tp.id,
  tp.user_id,
  p.full_name,
  tp.status,
  tp.has_pending_update,
  CASE 
    WHEN tp.pending_changes IS NULL THEN 'NULL'
    WHEN jsonb_typeof(tp.pending_changes) = 'object' THEN 'OBJECT'
    WHEN jsonb_typeof(tp.pending_changes) = 'string' THEN 'STRING'
    ELSE 'OTHER'
  END as pending_changes_format,
  CASE 
    WHEN tp.pending_changes IS NULL THEN 0
    WHEN jsonb_typeof(tp.pending_changes) = 'object' THEN 
      (SELECT count(*) FROM jsonb_object_keys(tp.pending_changes))
    ELSE 0
  END as pending_changes_count,
  tp.pending_changes
FROM tutor_profiles tp
LEFT JOIN profiles p ON tp.user_id = p.id
WHERE tp.has_pending_update = TRUE
ORDER BY tp.updated_at DESC;

-- 3. Fix any tutors with has_pending_update = TRUE but NULL or empty pending_changes
UPDATE tutor_profiles
SET has_pending_update = FALSE
WHERE has_pending_update = TRUE
  AND (pending_changes IS NULL 
       OR (jsonb_typeof(pending_changes) = 'object' 
           AND jsonb_object_keys(pending_changes) IS NULL));

-- 4. Show the actual pending_changes content for debugging
SELECT 
  id,
  user_id,
  has_pending_update,
  pending_changes::text as pending_changes_text,
  jsonb_pretty(pending_changes) as pending_changes_pretty
FROM tutor_profiles
WHERE has_pending_update = TRUE
  AND pending_changes IS NOT NULL;

