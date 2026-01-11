-- Diagnostic and Fix Script for Storage RLS Policies
-- This script will:
-- 1. Show all existing policies
-- 2. Drop conflicting policies
-- 3. Create correct policies

-- Step 1: List all existing policies on storage.objects
SELECT 
  schemaname,
  tablename,
  policyname,
  permissive,
  roles,
  cmd,
  qual,
  with_check
FROM pg_policies
WHERE tablename = 'objects' AND schemaname = 'storage'
ORDER BY policyname;

-- Step 2: Drop ALL existing policies for documents bucket (clean slate)
DO $$
DECLARE
  r RECORD;
BEGIN
  FOR r IN (
    SELECT policyname 
    FROM pg_policies 
    WHERE tablename = 'objects' 
    AND schemaname = 'storage'
    AND (
      policyname LIKE '%documents%' OR
      policyname LIKE '%profile-photos%' OR
      policyname LIKE '%videos%'
    )
  ) LOOP
    EXECUTE 'DROP POLICY IF EXISTS ' || quote_ident(r.policyname) || ' ON storage.objects';
  END LOOP;
END $$;

-- Step 3: Create INSERT policy for documents (WITH CHECK is critical!)
CREATE POLICY "Users can upload to their own documents folder"
ON storage.objects
FOR INSERT
TO authenticated
WITH CHECK (
  bucket_id = 'documents' AND
  (storage.foldername(name))[1] = auth.uid()::text
);

-- Step 4: Create SELECT policy for documents
CREATE POLICY "Users can read their own documents"
ON storage.objects
FOR SELECT
TO authenticated
USING (
  bucket_id = 'documents' AND
  (storage.foldername(name))[1] = auth.uid()::text
);

-- Step 5: Create DELETE policy for documents
CREATE POLICY "Users can delete their own documents"
ON storage.objects
FOR DELETE
TO authenticated
USING (
  bucket_id = 'documents' AND
  (storage.foldername(name))[1] = auth.uid()::text
);

-- Step 6: Verify policies were created
SELECT 
  policyname,
  cmd,
  CASE 
    WHEN with_check IS NOT NULL THEN 'WITH CHECK: ' || with_check
    WHEN qual IS NOT NULL THEN 'USING: ' || qual
    ELSE 'No expression'
  END as policy_expression
FROM pg_policies
WHERE tablename = 'objects' 
AND schemaname = 'storage'
AND policyname LIKE '%documents%'
ORDER BY cmd, policyname;


