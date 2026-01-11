-- Test and Fix Storage Policy
-- This script tests the policy condition and provides an alternative if needed

-- Step 1: Test if auth.uid() works
SELECT auth.uid()::text as current_user_id;

-- Step 2: Test if storage.foldername works
SELECT 
  storage.foldername('ec8eb6d3-c4b3-4906-873f-9abb97cc5ef8/skulmate_notes.png') as folder_array,
  (storage.foldername('ec8eb6d3-c4b3-4906-873f-9abb97cc5ef8/skulmate_notes.png'))[1] as first_folder;

-- Step 3: Test the full policy condition
SELECT 
  'documents' = 'documents' AND
  (storage.foldername('ec8eb6d3-c4b3-4906-873f-9abb97cc5ef8/skulmate_notes.png'))[1] = auth.uid()::text
AS policy_test_result;

-- Step 4: Drop and recreate with alternative syntax (using LIKE instead)
DROP POLICY IF EXISTS "Users can upload to their own documents folder" ON storage.objects;

-- Try alternative using LIKE (simpler, more reliable)
CREATE POLICY "Users can upload to their own documents folder"
ON storage.objects
FOR INSERT
TO authenticated
WITH CHECK (
  bucket_id = 'documents' AND
  name LIKE (auth.uid()::text || '/%')
);

-- Step 5: Also update SELECT and DELETE to use LIKE for consistency
DROP POLICY IF EXISTS "Users can read their own documents" ON storage.objects;
DROP POLICY IF EXISTS "Users can delete their own documents" ON storage.objects;

CREATE POLICY "Users can read their own documents"
ON storage.objects
FOR SELECT
TO authenticated
USING (
  bucket_id = 'documents' AND
  name LIKE (auth.uid()::text || '/%')
);

CREATE POLICY "Users can delete their own documents"
ON storage.objects
FOR DELETE
TO authenticated
USING (
  bucket_id = 'documents' AND
  name LIKE (auth.uid()::text || '/%')
);

-- Step 6: Verify policies
SELECT 
  policyname,
  cmd,
  CASE 
    WHEN with_check IS NOT NULL THEN substring(with_check::text, 1, 150)
    ELSE 'NULL'
  END as with_check_preview,
  CASE 
    WHEN qual IS NOT NULL THEN substring(qual::text, 1, 150)
    ELSE 'NULL'
  END as using_preview
FROM pg_policies
WHERE tablename = 'objects' 
AND schemaname = 'storage'
AND policyname LIKE '%documents%'
ORDER BY cmd, policyname;


