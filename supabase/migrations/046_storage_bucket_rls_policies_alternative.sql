-- Alternative Storage Bucket RLS Policies
-- This version uses a simpler path matching approach that may work better
-- with Supabase's storage system

-- Drop existing policies if they exist
DROP POLICY IF EXISTS "Users can upload to their own documents folder" ON storage.objects;
DROP POLICY IF EXISTS "Users can read their own documents" ON storage.objects;
DROP POLICY IF EXISTS "Users can delete their own documents" ON storage.objects;

-- Documents bucket - INSERT policy (WITH CHECK for new rows)
CREATE POLICY "Users can upload to their own documents folder"
ON storage.objects
FOR INSERT
TO authenticated
WITH CHECK (
  bucket_id = 'documents' AND
  (storage.foldername(name))[1] = auth.uid()::text
);

-- Documents bucket - SELECT policy (USING for existing rows)
CREATE POLICY "Users can read their own documents"
ON storage.objects
FOR SELECT
TO authenticated
USING (
  bucket_id = 'documents' AND
  (storage.foldername(name))[1] = auth.uid()::text
);

-- Documents bucket - DELETE policy (USING for existing rows)
CREATE POLICY "Users can delete their own documents"
ON storage.objects
FOR DELETE
TO authenticated
USING (
  bucket_id = 'documents' AND
  (storage.foldername(name))[1] = auth.uid()::text
);

-- Test query to verify the policy works
-- Run this to check if auth.uid() returns the expected value:
-- SELECT auth.uid()::text;

-- Alternative simpler version (if storage.foldername doesn't work):
-- WITH CHECK (bucket_id = 'documents' AND name LIKE (auth.uid()::text || '/%'))


