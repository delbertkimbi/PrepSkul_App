# 🚨 Pending Database Migrations

## ⚠️ **Migrations That Need to Be Applied**

Based on the current codebase and database schema, these migrations are **NOT YET APPLIED** to production:

### **Migration 007: Learner Profiles Setup** ⚠️
**File:** `supabase/migrations/007_complete_learner_profiles_setup.sql`

**What it does:**
- Adds all required columns for student surveys
- Sets up UUID auto-generation for `id` column
- Enables RLS policies for security
- Adds proper column comments

**Required for:**
- ✅ Student survey submission
- ✅ Learner profile creation
- ✅ Student onboarding flow

**Status:** ❌ **NOT APPLIED** - Needs to be run in Supabase SQL Editor

---

### **Migration 008: Tutor Profiles Complete** ⚠️
**File:** `supabase/migrations/008_ensure_tutor_profiles_complete.sql`

**What it does:**
- Adds all missing tutor profile columns
- Sets up approval status fields (`status`, `reviewed_by`, `reviewed_at`, `admin_review_notes`)
- Enables RLS policies for tutors and admins
- Adds proper indexes and constraints

**Required for:**
- ✅ Tutor onboarding flow
- ✅ Admin approval/rejection workflow
- ✅ Tutor profile display in discovery
- ✅ Status-based feature access

**Status:** ❌ **NOT APPLIED** - Needs to be run in Supabase SQL Editor

---

## 📋 **How to Apply These Migrations**

### **Step 1: Go to Supabase Dashboard**
1. Navigate to: https://app.supabase.com
2. Select your project: **PrepSkul**
3. Go to: **SQL Editor**

### **Step 2: Run Migration 007**
1. Open: `supabase/migrations/007_complete_learner_profiles_setup.sql`
2. Copy ALL content
3. Paste into Supabase SQL Editor
4. Click **Run** or press `Cmd/Ctrl + Enter`
5. Verify: Should see "learner_profiles setup complete!" message

### **Step 3: Run Migration 008**
1. Open: `supabase/migrations/008_ensure_tutor_profiles_complete.sql`
2. Copy ALL content
3. Paste into Supabase SQL Editor
4. Click **Run** or press `Cmd/Ctrl + Enter`
5. Verify: Should see "tutor_profiles setup complete!" message

---

## ✅ **After Applying Migrations**

### **Verification Queries**

**Check learner_profiles:**
```sql
SELECT 
  column_name, 
  data_type,
  is_nullable
FROM information_schema.columns 
WHERE table_name = 'learner_profiles' 
AND table_schema = 'public'
ORDER BY ordinal_position;
```

**Check tutor_profiles:**
```sql
SELECT 
  column_name, 
  data_type,
  is_nullable
FROM information_schema.columns 
WHERE table_name = 'tutor_profiles' 
AND table_schema = 'public'
AND column_name IN ('status', 'reviewed_by', 'reviewed_at', 'admin_review_notes')
ORDER BY ordinal_position;
```

---

## 🎯 **What These Migrations Fix**

### **Before Migration 007:**
- ❌ Student survey fails with "column not found" errors
- ❌ Learner profiles can't be created
- ❌ Student onboarding doesn't work

### **After Migration 007:**
- ✅ Student survey submits successfully
- ✅ All learner profile columns exist
- ✅ Student onboarding flow works end-to-end

### **Before Migration 008:**
- ❌ Tutor approval status not saved
- ❌ Admin review notes missing
- ❌ Tutor discovery may fail
- ❌ Status-based features don't work

### **After Migration 008:**
- ✅ Tutor approval/rejection workflow works
- ✅ Admin can add review notes
- ✅ Tutor status displayed correctly
- ✅ Status-based feature access works

---

## 📝 **Migration Notes**

- Both migrations use `IF NOT EXISTS` to be safe to run multiple times
- RLS policies are dropped and recreated to avoid conflicts
- All columns have proper comments for documentation
- Migrations are idempotent (safe to run again if needed)

---

## 🔍 **Current Migration Status**

| Migration | Status | File | Required For |
|-----------|--------|------|--------------|
| 001-006 | ✅ Applied | Various | Core functionality |
| **007** | ❌ **NOT APPLIED** | `007_complete_learner_profiles_setup.sql` | Student surveys |
| **008** | ❌ **NOT APPLIED** | `008_ensure_tutor_profiles_complete.sql` | Tutor approval workflow |

---

**Priority:** 🔴 **HIGH** - These migrations are needed for full app functionality!

**Next Step:** Apply migrations 007 and 008 in Supabase SQL Editor.

