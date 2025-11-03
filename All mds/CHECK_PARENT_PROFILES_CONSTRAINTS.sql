-- Check parent_profiles table constraints and indexes

-- 1. Check if there's a unique constraint on user_id
SELECT 
  tc.constraint_name,
  tc.constraint_type,
  kcu.column_name
FROM information_schema.table_constraints tc
JOIN information_schema.key_column_usage kcu 
  ON tc.constraint_name = kcu.constraint_name
WHERE tc.table_name = 'parent_profiles'
AND tc.table_schema = 'public'
AND tc.constraint_type IN ('PRIMARY KEY', 'UNIQUE')
ORDER BY tc.constraint_type, tc.constraint_name;

-- 2. Check unique indexes
SELECT 
  indexname,
  indexdef
FROM pg_indexes
WHERE tablename = 'parent_profiles'
AND schemaname = 'public'
AND indexdef LIKE '%UNIQUE%';

-- 3. Check current data
SELECT 
  id,
  user_id,
  child_name,
  city,
  created_at
FROM parent_profiles
ORDER BY created_at DESC
LIMIT 5;

-- 4. Check if upsert conflict target exists
SELECT 
  conname AS constraint_name,
  pg_get_constraintdef(oid) AS constraint_definition
FROM pg_constraint
WHERE conrelid = 'parent_profiles'::regclass
AND contype = 'u';

