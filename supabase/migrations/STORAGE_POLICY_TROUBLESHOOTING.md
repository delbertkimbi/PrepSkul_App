# Storage RLS Policy Troubleshooting Guide

## Issue: Upload still fails with RLS error after creating policies

### Step 1: Verify INSERT Policy Has WITH CHECK

**Critical:** For INSERT operations, the policy MUST use `WITH CHECK`, not `USING`.

1. Go to Supabase Dashboard → Storage → Policies
2. Find the **INSERT** policy for the `documents` bucket
3. Click Edit on the INSERT policy
4. Verify it shows **"WITH CHECK expression"** (not "USING expression")
5. The policy definition should be:
   ```sql
   bucket_id = 'documents' AND
   (storage.foldername(name))[1] = auth.uid()::text
   ```

### Step 2: Verify Policy Names Match

Make sure the INSERT policy is named correctly and is for INSERT operation:
- Policy name: `Users can upload to their own documents folder` (or similar)
- Command: **INSERT** (not SELECT or DELETE)
- Target roles: **authenticated**

### Step 3: Test auth.uid() Returns Correct Value

Run this query in SQL Editor to verify authentication:
```sql
SELECT auth.uid()::text as current_user_id;
```

This should return your user ID: `ec8eb6d3-c4b3-4906-873f-9abb97cc5ef8`

### Step 4: Test Policy Directly

Test if the policy condition evaluates correctly:
```sql
-- This should return true if you're authenticated
SELECT 
  'documents' = 'documents' AND
  (storage.foldername('ec8eb6d3-c4b3-4906-873f-9abb97cc5ef8/skulmate_notes.png'))[1] = auth.uid()::text
AS policy_test;
```

### Step 5: Alternative Policy Syntax

If `storage.foldername()` doesn't work, try this alternative using `LIKE`:

**For INSERT (WITH CHECK):**
```sql
bucket_id = 'documents' AND
name LIKE (auth.uid()::text || '/%')
```

**For SELECT (USING):**
```sql
bucket_id = 'documents' AND
name LIKE (auth.uid()::text || '/%')
```

**For DELETE (USING):**
```sql
bucket_id = 'documents' AND
name LIKE (auth.uid()::text || '/%')
```

### Step 6: Verify All Three Policies Exist

Make sure you have **all three** policies for the `documents` bucket:
1. ✅ INSERT policy (WITH CHECK)
2. ✅ SELECT policy (USING)
3. ✅ DELETE policy (USING)

### Step 7: Check Bucket Configuration

1. Go to Storage → Buckets
2. Click on `documents` bucket
3. Verify:
   - Bucket exists
   - RLS is enabled (should be by default)
   - Bucket is not public (for documents bucket)

### Common Issues:

1. **INSERT policy missing WITH CHECK**: INSERT policies need `WITH CHECK`, not `USING`
2. **Wrong bucket name**: Make sure it's exactly `'documents'` (lowercase, no spaces)
3. **Policy not saved**: Click "Review" then "Save" after editing
4. **User not authenticated**: Verify `auth.uid()` returns a value in SQL Editor


