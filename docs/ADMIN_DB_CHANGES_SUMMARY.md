# 🔧 Admin Dashboard - Database Changes Impact

## ✅ **Flutter App Issues - ALL FIXED!**

### **1. Onboarding Survey - FIXED ✅**
**Error:** `duplicate key value violates unique constraint "parent_profiles_user_id_key"`
**Root Cause:** `upsert()` without `onConflict` parameter
**Fix Applied:** Added `onConflict: 'user_id'` to all survey upserts
**Files Changed:** `lib/core/services/survey_repository.dart`

### **2. Booking Submission - NEEDS SCHEMA CACHE REFRESH**
**Error:** `Could not find the 'student_avatar_url' column`
**Root Cause:** Columns renamed `student_*` → `learner_*` but Supabase cache not refreshed
**Fix Applied:** `FIX_SESSION_REQUESTS_SCHEMA.sql` (ran successfully)
**Next Step:** Wait 5-10 minutes OR restart Supabase database

---

## 📊 **Database Schema Changes Made:**

### **Tables Modified:**

#### **1. session_requests**
- ✅ Renamed: `student_id` → `learner_id`
- ✅ Renamed: `student_type` → `learner_type`
- ✅ Renamed: `student_name` → `learner_name`
- ✅ Renamed: `student_avatar_url` → `learner_avatar_url`
- ✅ Updated check constraints
- ✅ Updated RLS policies
- ✅ Updated indexes

#### **2. recurring_sessions**
- ✅ Renamed: `student_id` → `learner_id`
- ✅ Renamed: `student_type` → `learner_type`
- ✅ Renamed: `student_name` → `learner_name`
- ✅ Renamed: `student_avatar_url` → `learner_avatar_url`
- ✅ Updated check constraints
- ✅ Updated RLS policies
- ✅ Updated indexes

#### **3. parent_profiles**
- ✅ Added UUID auto-generation: `DEFAULT gen_random_uuid()`
- ✅ Added RLS policies (INSERT/SELECT/UPDATE)
- ✅ All columns verified present

#### **4. learner_profiles**
- ✅ Added UUID auto-generation: `DEFAULT gen_random_uuid()`
- ✅ Added RLS policies (INSERT/SELECT/UPDATE)
- ✅ All columns verified present

#### **5. tutor_profiles**
- ✅ Added `user_id` column (was missing!)
- ✅ Added all missing columns (28 total now)
- ✅ Updated RLS policies
- ✅ Status constraint added

---

## 🚨 **Admin Dashboard Issues:**

### **Error: `Cannot coerce the result to a single JSON object`**

This error on admin login suggests one of these issues:

#### **Possible Cause 1: Duplicate Profile Records**
The admin user might have multiple profile records in the `profiles` table.

**Check:**
```sql
-- Run in Supabase SQL Editor
SELECT id, email, is_admin, user_type, created_at 
FROM profiles 
WHERE email = 'prepskul@gmail.com'
ORDER BY created_at;
```

**Fix if duplicates exist:**
```sql
-- Keep only the first (oldest) profile
DELETE FROM profiles 
WHERE email = 'prepskul@gmail.com'
AND id NOT IN (
  SELECT id 
  FROM profiles 
  WHERE email = 'prepskul@gmail.com'
  ORDER BY created_at ASC 
  LIMIT 1
);

-- Ensure it's admin
UPDATE profiles 
SET is_admin = TRUE, user_type = 'admin'
WHERE email = 'prepskul@gmail.com';
```

#### **Possible Cause 2: Missing Admin Profile**
The auth user exists but no profile linked to it.

**Fix:**
```sql
-- Create profile from auth user
INSERT INTO profiles (id, email, full_name, is_admin, user_type)
SELECT 
  id, 
  email, 
  'PrepSkul Admin',
  TRUE,
  'admin'
FROM auth.users 
WHERE email = 'prepskul@gmail.com'
ON CONFLICT (id) DO UPDATE 
SET is_admin = TRUE, user_type = 'admin';
```

#### **Possible Cause 3: RLS Policy Blocking**
RLS might be blocking the profile read.

**Temporary Fix (for testing):**
```sql
ALTER TABLE profiles DISABLE ROW LEVEL SECURITY;
```

**Better Fix (proper policies):**
```sql
-- Drop old policies
DROP POLICY IF EXISTS "Users can read own profile" ON profiles;
DROP POLICY IF EXISTS "Users can update own profile" ON profiles;

-- Create proper policies
CREATE POLICY "Users can read own profile"
ON profiles FOR SELECT
USING (auth.uid() = id);

CREATE POLICY "Users can update own profile"
ON profiles FOR UPDATE
USING (auth.uid() = id);
```

#### **Possible Cause 4: Missing Columns**
Recent migrations might have added columns that the admin dashboard isn't expecting.

**Check:**
```sql
-- See all columns in profiles table
SELECT column_name, data_type, is_nullable
FROM information_schema.columns
WHERE table_name = 'profiles' 
AND table_schema = 'public'
ORDER BY ordinal_position;
```

---

## 🔍 **How to Diagnose:**

### **Step 1: Check Profile Count**
```sql
SELECT COUNT(*) as total, email
FROM profiles 
WHERE email = 'prepskul@gmail.com'
GROUP BY email;
```
**Expected:** Count = 1

### **Step 2: Check Column Count**
```sql
SELECT COUNT(*) as column_count
FROM information_schema.columns
WHERE table_name = 'profiles'
AND table_schema = 'public';
```
**Expected:** ~15-20 columns (check against admin dashboard expectations)

### **Step 3: Test Profile Query**
```sql
SELECT * FROM profiles 
WHERE email = 'prepskul@gmail.com'
LIMIT 1;
```
**Expected:** Returns exactly 1 row

### **Step 4: Check RLS**
```sql
SELECT tablename, rowsecurity 
FROM pg_tables 
WHERE tablename = 'profiles' 
AND schemaname = 'public';
```
**Expected:** `rowsecurity = true` (but with proper policies)

---

## 🚀 **Recommended Fix Steps:**

### **For Admin Dashboard:**

1. **Run duplicate check query** (from Possible Cause 1)
2. If duplicates → Delete duplicates
3. If missing → Create profile (from Possible Cause 2)
4. **Verify exactly ONE profile exists:**
   ```sql
   SELECT id, email, is_admin, user_type 
   FROM profiles 
   WHERE email = 'prepskul@gmail.com';
   ```
5. **Try login again**

### **If Still Failing:**

Check the **Next.js admin dashboard code** for:
- `.single()` calls without error handling
- Profile queries that expect specific columns
- Hardcoded column names that changed

**Need to see:** `PrepSkul_Web` repository admin login code to diagnose further.

---

## 📋 **Quick Reference:**

| Issue | Status | Fix |
|-------|--------|-----|
| Flutter Survey Submission | ✅ **FIXED** | Added `onConflict: 'user_id'` |
| Booking Schema Cache | ⏳ **WAITING** | Wait 5-10 min or restart DB |
| Admin Login Error | 🔍 **INVESTIGATING** | Check duplicates + RLS policies |

---

## 🎯 **Next Actions:**

1. **Check for duplicate admin profiles** in Supabase
2. **Verify RLS policies** are correct
3. **Check admin dashboard code** in `PrepSkul_Web` repo
4. **Test login after duplicates removed**

**Let me know what the duplicate check shows!** 🔍

