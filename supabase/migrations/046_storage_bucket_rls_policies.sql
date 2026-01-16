-- Migration: Storage Bucket RLS Policies
-- Description: Adds RLS policies for storage buckets (documents, profile-photos, videos)
--              to allow users to upload, read, and delete their own files
--
-- Note: RLS is already enabled on storage.objects by default in Supabase
-- We only need to create the policies

-- Drop existing policies if they exist (to allow re-running migration)
DROP POLICY IF EXISTS "Users can upload to their own documents folder" ON storage.objects;
DROP POLICY IF EXISTS "Users can read their own documents" ON storage.objects;
DROP POLICY IF EXISTS "Users can delete their own documents" ON storage.objects;
DROP POLICY IF EXISTS "Users can upload to their own profile photos folder" ON storage.objects;
DROP POLICY IF EXISTS "Users can read their own profile photos" ON storage.objects;
DROP POLICY IF EXISTS "Users can delete their own profile photos" ON storage.objects;
DROP POLICY IF EXISTS "Users can upload to their own videos folder" ON storage.objects;
DROP POLICY IF EXISTS "Users can read their own videos" ON storage.objects;
DROP POLICY IF EXISTS "Users can delete their own videos" ON storage.objects;

-- Documents bucket policies
-- Allow users to upload files to their own folder in documents bucket
-- Path format: {userId}/{filename}
CREATE POLICY "Users can upload to their own documents folder"
ON storage.objects
FOR INSERT
TO authenticated
WITH CHECK (
  bucket_id = 'documents' AND
  (storage.foldername(name))[1] = auth.uid()::text
);

-- Allow users to read files from their own folder in documents bucket
CREATE POLICY "Users can read their own documents"
ON storage.objects
FOR SELECT
TO authenticated
USING (
  bucket_id = 'documents' AND
  (storage.foldername(name))[1] = auth.uid()::text
);

-- Allow users to delete files from their own folder in documents bucket
CREATE POLICY "Users can delete their own documents"
ON storage.objects
FOR DELETE
TO authenticated
USING (
  bucket_id = 'documents' AND
  (storage.foldername(name))[1] = auth.uid()::text
);

-- Profile photos bucket policies
-- Allow users to upload files to their own folder in profile-photos bucket
CREATE POLICY "Users can upload to their own profile photos folder"
ON storage.objects
FOR INSERT
TO authenticated
WITH CHECK (
  bucket_id = 'profile-photos' AND
  (storage.foldername(name))[1] = auth.uid()::text
);

-- Allow users to read files from their own folder in profile-photos bucket
CREATE POLICY "Users can read their own profile photos"
ON storage.objects
FOR SELECT
TO authenticated
USING (
  bucket_id = 'profile-photos' AND
  (storage.foldername(name))[1] = auth.uid()::text
);

-- Allow users to delete files from their own folder in profile-photos bucket
CREATE POLICY "Users can delete their own profile photos"
ON storage.objects
FOR DELETE
TO authenticated
USING (
  bucket_id = 'profile-photos' AND
  (storage.foldername(name))[1] = auth.uid()::text
);

-- Videos bucket policies
-- Allow users to upload files to their own folder in videos bucket
CREATE POLICY "Users can upload to their own videos folder"
ON storage.objects
FOR INSERT
TO authenticated
WITH CHECK (
  bucket_id = 'videos' AND
  (storage.foldername(name))[1] = auth.uid()::text
);

-- Allow users to read files from their own folder in videos bucket
CREATE POLICY "Users can read their own videos"
ON storage.objects
FOR SELECT
TO authenticated
USING (
  bucket_id = 'videos' AND
  (storage.foldername(name))[1] = auth.uid()::text
);

-- Allow users to delete files from their own folder in videos bucket
CREATE POLICY "Users can delete their own videos"
ON storage.objects
FOR DELETE
TO authenticated
USING (
  bucket_id = 'videos' AND
  (storage.foldername(name))[1] = auth.uid()::text
);

-- Note: These policies ensure that:
-- 1. Users can only upload/read/delete files in folders named with their user ID
-- 2. The folder structure must be: {userId}/{filename}
-- 3. This matches the storage path format used in StorageService: '$userId/$documentType$fileExtension'

--              to allow users to upload, read, and delete their own files
--
-- Note: RLS is already enabled on storage.objects by default in Supabase
-- We only need to create the policies

-- Drop existing policies if they exist (to allow re-running migration)
DROP POLICY IF EXISTS "Users can upload to their own documents folder" ON storage.objects;
DROP POLICY IF EXISTS "Users can read their own documents" ON storage.objects;
DROP POLICY IF EXISTS "Users can delete their own documents" ON storage.objects;
DROP POLICY IF EXISTS "Users can upload to their own profile photos folder" ON storage.objects;
DROP POLICY IF EXISTS "Users can read their own profile photos" ON storage.objects;
DROP POLICY IF EXISTS "Users can delete their own profile photos" ON storage.objects;
DROP POLICY IF EXISTS "Users can upload to their own videos folder" ON storage.objects;
DROP POLICY IF EXISTS "Users can read their own videos" ON storage.objects;
DROP POLICY IF EXISTS "Users can delete their own videos" ON storage.objects;

-- Documents bucket policies
-- Allow users to upload files to their own folder in documents bucket
-- Path format: {userId}/{filename}
CREATE POLICY "Users can upload to their own documents folder"
ON storage.objects
FOR INSERT
TO authenticated
WITH CHECK (
  bucket_id = 'documents' AND
  (storage.foldername(name))[1] = auth.uid()::text
);

-- Allow users to read files from their own folder in documents bucket
CREATE POLICY "Users can read their own documents"
ON storage.objects
FOR SELECT
TO authenticated
USING (
  bucket_id = 'documents' AND
  (storage.foldername(name))[1] = auth.uid()::text
);

-- Allow users to delete files from their own folder in documents bucket
CREATE POLICY "Users can delete their own documents"
ON storage.objects
FOR DELETE
TO authenticated
USING (
  bucket_id = 'documents' AND
  (storage.foldername(name))[1] = auth.uid()::text
);

-- Profile photos bucket policies
-- Allow users to upload files to their own folder in profile-photos bucket
CREATE POLICY "Users can upload to their own profile photos folder"
ON storage.objects
FOR INSERT
TO authenticated
WITH CHECK (
  bucket_id = 'profile-photos' AND
  (storage.foldername(name))[1] = auth.uid()::text
);

-- Allow users to read files from their own folder in profile-photos bucket
CREATE POLICY "Users can read their own profile photos"
ON storage.objects
FOR SELECT
TO authenticated
USING (
  bucket_id = 'profile-photos' AND
  (storage.foldername(name))[1] = auth.uid()::text
);

-- Allow users to delete files from their own folder in profile-photos bucket
CREATE POLICY "Users can delete their own profile photos"
ON storage.objects
FOR DELETE
TO authenticated
USING (
  bucket_id = 'profile-photos' AND
  (storage.foldername(name))[1] = auth.uid()::text
);

-- Videos bucket policies
-- Allow users to upload files to their own folder in videos bucket
CREATE POLICY "Users can upload to their own videos folder"
ON storage.objects
FOR INSERT
TO authenticated
WITH CHECK (
  bucket_id = 'videos' AND
  (storage.foldername(name))[1] = auth.uid()::text
);

-- Allow users to read files from their own folder in videos bucket
CREATE POLICY "Users can read their own videos"
ON storage.objects
FOR SELECT
TO authenticated
USING (
  bucket_id = 'videos' AND
  (storage.foldername(name))[1] = auth.uid()::text
);

-- Allow users to delete files from their own folder in videos bucket
CREATE POLICY "Users can delete their own videos"
ON storage.objects
FOR DELETE
TO authenticated
USING (
  bucket_id = 'videos' AND
  (storage.foldername(name))[1] = auth.uid()::text
);

-- Note: These policies ensure that:
-- 1. Users can only upload/read/delete files in folders named with their user ID
-- 2. The folder structure must be: {userId}/{filename}
-- 3. This matches the storage path format used in StorageService: '$userId/$documentType$fileExtension'
