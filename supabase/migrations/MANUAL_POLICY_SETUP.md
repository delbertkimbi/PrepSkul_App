# Manual Storage Policy Setup (If SQL Doesn't Work)

If running SQL migrations isn't working, set up the policies manually through the Supabase Dashboard.

## Step-by-Step Instructions

### 1. Go to Storage Policies

1. Open Supabase Dashboard
2. Click **Storage** in left sidebar
3. Click on **`documents`** bucket
4. Click **Policies** tab

### 2. Delete ALL Existing Policies for Documents Bucket

1. For each policy shown, click the **three dots (⋮)** → **Delete**
2. Confirm deletion
3. Make sure NO policies remain for the `documents` bucket

### 3. Create INSERT Policy (Most Important!)

1. Click **"New policy"** button
2. Choose **"For full customization"**
3. Fill in:
   - **Policy name**: `Users can upload to their own documents folder`
   - **Allowed operation**: Select **INSERT**
   - **Target roles**: Type `authenticated` and press Enter
   - **WITH CHECK expression** (this is critical - must be WITH CHECK, not USING):
     ```sql
     bucket_id = 'documents' AND
     (storage.foldername(name))[1] = auth.uid()::text
     ```
4. Click **Review** → **Save policy**

### 4. Create SELECT Policy

1. Click **"New policy"** button again
2. Choose **"For full customization"**
3. Fill in:
   - **Policy name**: `Users can read their own documents`
   - **Allowed operation**: Select **SELECT**
   - **Target roles**: `authenticated`
   - **USING expression**:
     ```sql
     bucket_id = 'documents' AND
     (storage.foldername(name))[1] = auth.uid()::text
     ```
4. Click **Review** → **Save policy**

### 5. Create DELETE Policy

1. Click **"New policy"** button again
2. Choose **"For full customization"**
3. Fill in:
   - **Policy name**: `Users can delete their own documents`
   - **Allowed operation**: Select **DELETE**
   - **Target roles**: `authenticated`
   - **USING expression**:
     ```sql
     bucket_id = 'documents' AND
     (storage.foldername(name))[1] = auth.uid()::text
     ```
4. Click **Review** → **Save policy**

## Alternative: Simpler Policy (If storage.foldername doesn't work)

If the above doesn't work, try this simpler version using `LIKE`:

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

## Verify It Works

After creating the policies:
1. Try uploading a file in the app
2. If it still fails, check the policy list to ensure all 3 policies exist
3. Verify the INSERT policy shows "WITH CHECK" not "USING"

## Common Mistakes

❌ **Wrong**: INSERT policy with USING expression  
✅ **Correct**: INSERT policy with WITH CHECK expression

❌ **Wrong**: Policy for wrong bucket  
✅ **Correct**: Policy for `documents` bucket

❌ **Wrong**: Policy for `public` role  
✅ **Correct**: Policy for `authenticated` role


