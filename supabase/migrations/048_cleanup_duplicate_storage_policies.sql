-- Cleanup Duplicate Storage Policies
-- This script removes old duplicate policies and keeps only the correct ones

-- Step 1: Drop ALL old policies with random suffixes (flreew_0, etc.)
DROP POLICY IF EXISTS "Users can delete own documents flreew_0" ON storage.objects;
DROP POLICY IF EXISTS "Users can read own documents flreew_0" ON storage.objects;
DROP POLICY IF EXISTS "Users can upload own documents flreew_0" ON storage.objects;

-- Step 2: Drop the policies we created (in case they need to be recreated)
DROP POLICY IF EXISTS "Users can delete their own documents" ON storage.objects;
DROP POLICY IF EXISTS "Users can read their own documents" ON storage.objects;
DROP POLICY IF EXISTS "Users can upload to their own documents folder" ON storage.objects;

-- Step 3: Create clean INSERT policy (WITH CHECK is critical!)
CREATE POLICY "Users can upload to their own documents folder"
ON storage.objects
FOR INSERT
TO authenticated
WITH CHECK (
  bucket_id = 'documents' AND
  (storage.foldername(name))[1] = auth.uid()::text
);

-- Step 4: Create SELECT policy
CREATE POLICY "Users can read their own documents"
ON storage.objects
FOR SELECT
TO authenticated
USING (
  bucket_id = 'documents' AND
  (storage.foldername(name))[1] = auth.uid()::text
);

-- Step 5: Create DELETE policy
CREATE POLICY "Users can delete their own documents"
ON storage.objects
FOR DELETE
TO authenticated
USING (
  bucket_id = 'documents' AND
  (storage.foldername(name))[1] = auth.uid()::text
);

-- Step 6: Verify final policies
SELECT 
  policyname,
  cmd,
  CASE 
    WHEN with_check IS NOT NULL THEN 'WITH CHECK: ' || substring(with_check::text, 1, 100)
    ELSE 'NULL'
  END as with_check_preview,
  CASE 
    WHEN qual IS NOT NULL THEN 'USING: ' || substring(qual::text, 1, 100)
    ELSE 'NULL'
  END as using_preview
FROM pg_policies
WHERE tablename = 'objects' 
AND schemaname = 'storage'
AND policyname LIKE '%documents%'
ORDER BY cmd, policyname;


