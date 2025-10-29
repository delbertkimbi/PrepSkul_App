# 🗄️ SUPABASE STORAGE SETUP GUIDE

## 📋 **Step 1: Create Storage Buckets in Supabase Dashboard**

### **Go to your Supabase Project:**
1. Open: https://supabase.com/dashboard
2. Select your PrepSkul project
3. Click **Storage** in the left sidebar
4. Click **"New bucket"** button

---

### **Bucket 1: profile-photos** 📸

**Settings:**
- **Name:** `profile-photos`
- **Public bucket:** ✅ **YES** (checked)
- **File size limit:** 2 MB
- **Allowed MIME types:** `image/jpeg, image/png, image/jpg, image/webp`

**Click "Create bucket"**

---

### **Bucket 2: documents** 📄

**Settings:**
- **Name:** `documents`
- **Public bucket:** ❌ **NO** (unchecked)
- **File size limit:** 5 MB
- **Allowed MIME types:** `application/pdf, image/jpeg, image/png, image/jpg`

**Click "Create bucket"**

---

### **Bucket 3: videos** 🎥

**Settings:**
- **Name:** `videos`
- **Public bucket:** ✅ **YES** (checked)
- **File size limit:** 50 MB
- **Allowed MIME types:** `video/mp4, video/quicktime, video/webm`

**Click "Create bucket"**

---

## 🔐 **Step 2: Configure RLS Policies**

For each bucket, click on the bucket name, then click **"Policies"** tab.

### **For `profile-photos` bucket:**

#### **Policy 1: Users can upload their own photos**
```sql
CREATE POLICY "Users can upload own profile photos"
ON storage.objects FOR INSERT
TO authenticated
WITH CHECK (
  bucket_id = 'profile-photos' 
  AND (storage.foldername(name))[1] = auth.uid()::text
);
```

#### **Policy 2: Users can update their own photos**
```sql
CREATE POLICY "Users can update own profile photos"
ON storage.objects FOR UPDATE
TO authenticated
USING (
  bucket_id = 'profile-photos' 
  AND (storage.foldername(name))[1] = auth.uid()::text
);
```

#### **Policy 3: Users can delete their own photos**
```sql
CREATE POLICY "Users can delete own profile photos"
ON storage.objects FOR DELETE
TO authenticated
USING (
  bucket_id = 'profile-photos' 
  AND (storage.foldername(name))[1] = auth.uid()::text
);
```

#### **Policy 4: Everyone can view profile photos**
```sql
CREATE POLICY "Anyone can view profile photos"
ON storage.objects FOR SELECT
TO public
USING (bucket_id = 'profile-photos');
```

---

### **For `documents` bucket:**

#### **Policy 1: Users can upload their own documents**
```sql
CREATE POLICY "Users can upload own documents"
ON storage.objects FOR INSERT
TO authenticated
WITH CHECK (
  bucket_id = 'documents' 
  AND (storage.foldername(name))[1] = auth.uid()::text
);
```

#### **Policy 2: Users can read their own documents**
```sql
CREATE POLICY "Users can read own documents"
ON storage.objects FOR SELECT
TO authenticated
USING (
  bucket_id = 'documents' 
  AND (storage.foldername(name))[1] = auth.uid()::text
);
```

#### **Policy 3: Users can delete their own documents**
```sql
CREATE POLICY "Users can delete own documents"
ON storage.objects FOR DELETE
TO authenticated
USING (
  bucket_id = 'documents' 
  AND (storage.foldername(name))[1] = auth.uid()::text
);
```

---

### **For `videos` bucket:**

#### **Policy 1: Users can upload their own videos**
```sql
CREATE POLICY "Users can upload own videos"
ON storage.objects FOR INSERT
TO authenticated
WITH CHECK (
  bucket_id = 'videos' 
  AND (storage.foldername(name))[1] = auth.uid()::text
);
```

#### **Policy 2: Users can update their own videos**
```sql
CREATE POLICY "Users can update own videos"
ON storage.objects FOR UPDATE
TO authenticated
USING (
  bucket_id = 'videos' 
  AND (storage.foldername(name))[1] = auth.uid()::text
);
```

#### **Policy 3: Users can delete their own videos**
```sql
CREATE POLICY "Users can delete own videos"
ON storage.objects FOR DELETE
TO authenticated
USING (
  bucket_id = 'videos' 
  AND (storage.foldername(name))[1] = auth.uid()::text
);
```

#### **Policy 4: Everyone can view videos**
```sql
CREATE POLICY "Anyone can view videos"
ON storage.objects FOR SELECT
TO public
USING (bucket_id = 'videos');
```

---

## 📁 **Storage Structure:**

```
profile-photos/
├── {user_id}/
│   ├── avatar.jpg          (profile picture)
│   └── cover.jpg           (cover photo)

documents/
├── {user_id}/
│   ├── id_front.pdf        (ID card front)
│   ├── id_back.pdf         (ID card back)
│   ├── degree.pdf          (degree certificate)
│   ├── training_cert.pdf   (training certificate)
│   └── other_docs/         (additional documents)

videos/
└── {user_id}/
    └── intro.mp4           (introduction video)
```

---

## ✅ **Verification Checklist:**

After setup, verify:
- [ ] All 3 buckets created
- [ ] `profile-photos` is public
- [ ] `documents` is private
- [ ] `videos` is public
- [ ] All RLS policies applied (4 for profile-photos, 3 for documents, 4 for videos)
- [ ] Test upload from Supabase dashboard

---

## 🧪 **Test the Setup:**

### **From Supabase Dashboard:**
1. Click on `profile-photos` bucket
2. Click "Upload file"
3. Create a test folder with a UUID (e.g., `test-user-id`)
4. Upload a test image
5. Verify you can see it
6. Try to view the public URL
7. Delete the test file

---

## 📦 **Required Flutter Packages:**

Add these to `pubspec.yaml`:

```yaml
dependencies:
  image_picker: ^1.0.7
  file_picker: ^6.1.1
  path: ^1.8.3
  mime: ^1.0.4
```

Then run:
```bash
flutter pub get
```

---

## 🎯 **Next Steps:**

After completing the Supabase setup:
1. ✅ Create `StorageService` class
2. ✅ Add image upload methods
3. ✅ Add document upload methods
4. ✅ Add video upload methods
5. ✅ Integrate with tutor onboarding

---

**Once you've created the buckets in Supabase, type "buckets done" and I'll create the StorageService!** 🚀



## 📋 **Step 1: Create Storage Buckets in Supabase Dashboard**

### **Go to your Supabase Project:**
1. Open: https://supabase.com/dashboard
2. Select your PrepSkul project
3. Click **Storage** in the left sidebar
4. Click **"New bucket"** button

---

### **Bucket 1: profile-photos** 📸

**Settings:**
- **Name:** `profile-photos`
- **Public bucket:** ✅ **YES** (checked)
- **File size limit:** 2 MB
- **Allowed MIME types:** `image/jpeg, image/png, image/jpg, image/webp`

**Click "Create bucket"**

---

### **Bucket 2: documents** 📄

**Settings:**
- **Name:** `documents`
- **Public bucket:** ❌ **NO** (unchecked)
- **File size limit:** 5 MB
- **Allowed MIME types:** `application/pdf, image/jpeg, image/png, image/jpg`

**Click "Create bucket"**

---

### **Bucket 3: videos** 🎥

**Settings:**
- **Name:** `videos`
- **Public bucket:** ✅ **YES** (checked)
- **File size limit:** 50 MB
- **Allowed MIME types:** `video/mp4, video/quicktime, video/webm`

**Click "Create bucket"**

---

## 🔐 **Step 2: Configure RLS Policies**

For each bucket, click on the bucket name, then click **"Policies"** tab.

### **For `profile-photos` bucket:**

#### **Policy 1: Users can upload their own photos**
```sql
CREATE POLICY "Users can upload own profile photos"
ON storage.objects FOR INSERT
TO authenticated
WITH CHECK (
  bucket_id = 'profile-photos' 
  AND (storage.foldername(name))[1] = auth.uid()::text
);
```

#### **Policy 2: Users can update their own photos**
```sql
CREATE POLICY "Users can update own profile photos"
ON storage.objects FOR UPDATE
TO authenticated
USING (
  bucket_id = 'profile-photos' 
  AND (storage.foldername(name))[1] = auth.uid()::text
);
```

#### **Policy 3: Users can delete their own photos**
```sql
CREATE POLICY "Users can delete own profile photos"
ON storage.objects FOR DELETE
TO authenticated
USING (
  bucket_id = 'profile-photos' 
  AND (storage.foldername(name))[1] = auth.uid()::text
);
```

#### **Policy 4: Everyone can view profile photos**
```sql
CREATE POLICY "Anyone can view profile photos"
ON storage.objects FOR SELECT
TO public
USING (bucket_id = 'profile-photos');
```

---

### **For `documents` bucket:**

#### **Policy 1: Users can upload their own documents**
```sql
CREATE POLICY "Users can upload own documents"
ON storage.objects FOR INSERT
TO authenticated
WITH CHECK (
  bucket_id = 'documents' 
  AND (storage.foldername(name))[1] = auth.uid()::text
);
```

#### **Policy 2: Users can read their own documents**
```sql
CREATE POLICY "Users can read own documents"
ON storage.objects FOR SELECT
TO authenticated
USING (
  bucket_id = 'documents' 
  AND (storage.foldername(name))[1] = auth.uid()::text
);
```

#### **Policy 3: Users can delete their own documents**
```sql
CREATE POLICY "Users can delete own documents"
ON storage.objects FOR DELETE
TO authenticated
USING (
  bucket_id = 'documents' 
  AND (storage.foldername(name))[1] = auth.uid()::text
);
```

---

### **For `videos` bucket:**

#### **Policy 1: Users can upload their own videos**
```sql
CREATE POLICY "Users can upload own videos"
ON storage.objects FOR INSERT
TO authenticated
WITH CHECK (
  bucket_id = 'videos' 
  AND (storage.foldername(name))[1] = auth.uid()::text
);
```

#### **Policy 2: Users can update their own videos**
```sql
CREATE POLICY "Users can update own videos"
ON storage.objects FOR UPDATE
TO authenticated
USING (
  bucket_id = 'videos' 
  AND (storage.foldername(name))[1] = auth.uid()::text
);
```

#### **Policy 3: Users can delete their own videos**
```sql
CREATE POLICY "Users can delete own videos"
ON storage.objects FOR DELETE
TO authenticated
USING (
  bucket_id = 'videos' 
  AND (storage.foldername(name))[1] = auth.uid()::text
);
```

#### **Policy 4: Everyone can view videos**
```sql
CREATE POLICY "Anyone can view videos"
ON storage.objects FOR SELECT
TO public
USING (bucket_id = 'videos');
```

---

## 📁 **Storage Structure:**

```
profile-photos/
├── {user_id}/
│   ├── avatar.jpg          (profile picture)
│   └── cover.jpg           (cover photo)

documents/
├── {user_id}/
│   ├── id_front.pdf        (ID card front)
│   ├── id_back.pdf         (ID card back)
│   ├── degree.pdf          (degree certificate)
│   ├── training_cert.pdf   (training certificate)
│   └── other_docs/         (additional documents)

videos/
└── {user_id}/
    └── intro.mp4           (introduction video)
```

---

## ✅ **Verification Checklist:**

After setup, verify:
- [ ] All 3 buckets created
- [ ] `profile-photos` is public
- [ ] `documents` is private
- [ ] `videos` is public
- [ ] All RLS policies applied (4 for profile-photos, 3 for documents, 4 for videos)
- [ ] Test upload from Supabase dashboard

---

## 🧪 **Test the Setup:**

### **From Supabase Dashboard:**
1. Click on `profile-photos` bucket
2. Click "Upload file"
3. Create a test folder with a UUID (e.g., `test-user-id`)
4. Upload a test image
5. Verify you can see it
6. Try to view the public URL
7. Delete the test file

---

## 📦 **Required Flutter Packages:**

Add these to `pubspec.yaml`:

```yaml
dependencies:
  image_picker: ^1.0.7
  file_picker: ^6.1.1
  path: ^1.8.3
  mime: ^1.0.4
```

Then run:
```bash
flutter pub get
```

---

## 🎯 **Next Steps:**

After completing the Supabase setup:
1. ✅ Create `StorageService` class
2. ✅ Add image upload methods
3. ✅ Add document upload methods
4. ✅ Add video upload methods
5. ✅ Integrate with tutor onboarding

---

**Once you've created the buckets in Supabase, type "buckets done" and I'll create the StorageService!** 🚀

