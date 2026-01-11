# Storage Bucket RLS Policies Setup

## Problem
The `documents`, `profile-photos`, and `videos` storage buckets need RLS policies to allow users to upload, read, and delete their own files.

## Solution Options

### Option 1: Using Supabase Dashboard (Recommended - Easiest)

1. Go to your Supabase Dashboard
2. Navigate to **Storage** → **Policies**
3. For each bucket (`documents`, `profile-photos`, `videos`), create the following policies:

#### For `documents` bucket:

**Policy 1: Upload**
- Policy name: `Users can upload to their own documents folder`
- Allowed operation: `INSERT`
- Target roles: `authenticated`
- Policy definition:
```sql
bucket_id = 'documents' AND
(string_to_array(name, '/'))[1] = auth.uid()::text
```

**Policy 2: Read**  
- Policy name: `Users can read their own documents`
- Allowed operation: `SELECT`
- Target roles: `authenticated`
- Policy definition:
```sql
bucket_id = 'documents' AND
(string_to_array(name, '/'))[1] = auth.uid()::text
```

**Policy 3: Delete**
- Policy name: `Users can delete their own documents`
- Allowed operation: `DELETE`
- Target roles: `authenticated`
- Policy definition:
```sql
bucket_id = 'documents' AND
(string_to_array(name, '/'))[1] = auth.uid()::text
```

#### Repeat for `profile-photos` and `videos` buckets with the same structure, just change `bucket_id`.

### Option 2: Using SQL with Service Role (Advanced)

If you have access to the service role key, you can run the SQL migration directly:

```bash
# Using Supabase CLI with service role
supabase db push --db-url "postgresql://postgres:[SERVICE_ROLE_PASSWORD]@[PROJECT_REF].supabase.co:5432/postgres"
```

Or run the SQL file `046_storage_bucket_rls_policies.sql` in the Supabase SQL Editor while logged in as a project owner.

### Option 3: Manual SQL Execution

1. Go to Supabase Dashboard → SQL Editor
2. Copy and paste the contents of `046_storage_bucket_rls_policies.sql`
3. Run the query

## Verification

After setting up the policies, test by:
1. Logging in as a user
2. Trying to upload a file to SkulMate
3. The upload should succeed without RLS errors

## Troubleshooting

If you still get permission errors:
- Ensure you're using the service role key or are logged in as a project owner
- Check that the buckets exist: `documents`, `profile-photos`, `videos`
- Verify RLS is enabled on `storage.objects` (it should be by default)


