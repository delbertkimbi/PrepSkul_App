# PrepSkul Database Setup & Testing Guide

## 🎯 Current Status

### ✅ What's Working
- **Parent Onboarding Survey**: Fully functional, tested, and working
- **Database Schema**: `parent_profiles` table complete with all columns
- **Security**: RLS policies properly configured
- **Code**: Array formatting fixed, proper data validation

### ⚠️ What Needs Setup
- **Student Onboarding**: Migration ready, needs to be applied
- **Tutor Onboarding**: Migration ready, needs to be applied
- **Booking System**: Already migrated (002, 003)
- **Tutor Requests**: Already migrated (004)

---

## 🚀 **Action Plan: Apply Remaining Migrations**

### **Step 1: Apply Student Profiles Migration**

1. Open **Supabase Dashboard** → **SQL Editor**
2. Open file: `supabase/migrations/007_complete_learner_profiles_setup.sql`
3. **Copy entire contents** and **Paste into SQL Editor**
4. Click **"Run"** or press `Cmd+Enter`
5. Verify success: Should show "learner_profiles setup complete!"

**What this does:**
- Adds all required columns to `learner_profiles` table
- Sets up RLS policies for student data security
- Enables UUID auto-generation
- Prepares for student survey submission

---

### **Step 2: Apply Tutor Profiles Migration**

1. Still in **Supabase SQL Editor**
2. Open file: `supabase/migrations/008_ensure_tutor_profiles_complete.sql`
3. **Copy entire contents** and **Paste into SQL Editor**
4. Click **"Run"** or press `Cmd+Enter`
5. Verify success: Should show "tutor_profiles setup complete!"

**What this does:**
- Ensures all tutor profile columns exist
- Sets up comprehensive RLS policies:
  - Anyone can view approved tutors ✅
  - Tutors can manage their own profiles ✅
  - Admins can review/approve tutors ✅
- Enables tutor discovery and approval workflow

---

## ✅ **Testing Checklist**

After applying migrations, test each flow:

### 1. **Student Onboarding Flow**
- [ ] Create new account as "Student"
- [ ] Complete onboarding survey
- [ ] Verify data saves to `learner_profiles` table
- [ ] Check profile appears in student dashboard
- [ ] Verify "Find Tutors" works

**Expected Result**: Survey submits successfully, navigates to student dashboard

---

### 2. **Tutor Onboarding Flow**
- [ ] Create new account as "Tutor"
- [ ] Complete tutor profile setup
- [ ] Upload certifications/documents
- [ ] Verify data saves to `tutor_profiles` table
- [ ] Check status is "pending"
- [ ] Verify tutor dashboard shows approval status

**Expected Result**: Profile created, shows "Pending Approval" state

---

### 3. **Admin Approval Flow** (if admin dashboard is accessible)
- [ ] Log in as admin
- [ ] View pending tutors list
- [ ] Review tutor profile
- [ ] Approve/reject tutor
- [ ] Verify tutor receives notification
- [ ] Check tutor status updates

**Expected Result**: Approved tutors appear in tutor discovery

---

### 4. **Tutor Discovery Flow**
- [ ] Log in as student/parent
- [ ] Go to "Find Tutors"
- [ ] Browse approved tutors
- [ ] Filter by subject, location, price
- [ ] View tutor details
- [ ] Check rating, bio, availability display

**Expected Result**: Only approved tutors visible, all data displays correctly

---

### 5. **Booking Flow**
- [ ] Select a tutor
- [ ] Click "Book Session"
- [ ] Choose frequency, days, time
- [ ] Select location (online/onsite)
- [ ] Review booking summary
- [ ] Submit booking request
- [ ] Verify request appears in "My Requests"
- [ ] Check tutor sees request in their dashboard

**Expected Result**: Booking request created, both parties notified

---

### 6. **Trial Session Booking**
- [ ] Select a tutor
- [ ] Click "Book Trial Session"
- [ ] Choose date, time, subject
- [ ] Add learning goals/notes
- [ ] Submit trial request
- [ ] Verify request appears in "My Requests" with "Trial" badge

**Expected Result**: Trial session request created successfully

---

### 7. **Custom Tutor Request**
- [ ] Go to "Find Tutors"
- [ ] Apply filters with no results
- [ ] Click "Request a Tutor" button
- [ ] Fill out custom request form
- [ ] Submit request
- [ ] Verify request appears in "My Requests" with "Custom" badge
- [ ] Check WhatsApp notification sent (optional)

**Expected Result**: Custom request saved, admin notified

---

## 🔍 **Troubleshooting Common Issues**

### Issue: "Could not find column in schema cache"
**Solution**: The migration wasn't applied. Run the appropriate migration (007 or 008).

### Issue: "Row-level security policy violation"
**Solution**: RLS policies missing. Re-run the migration to create policies.

### Issue: "Null value in column 'id' violates not-null constraint"
**Solution**: UUID auto-generation not set. Re-run migration to add `DEFAULT gen_random_uuid()`.

### Issue: "Malformed array literal"
**Solution**: Code is sending string instead of array. Check that TEXT[] columns receive `[value]` not `"value"`.

---

## 📊 **Database Health Check**

Run these queries in Supabase SQL Editor to verify setup:

### Check parent_profiles
```sql
SELECT column_name, data_type, is_nullable, column_default
FROM information_schema.columns 
WHERE table_name = 'parent_profiles' AND table_schema = 'public'
ORDER BY column_name;
```

### Check learner_profiles
```sql
SELECT column_name, data_type, is_nullable, column_default
FROM information_schema.columns 
WHERE table_name = 'learner_profiles' AND table_schema = 'public'
ORDER BY column_name;
```

### Check tutor_profiles
```sql
SELECT column_name, data_type, is_nullable, column_default
FROM information_schema.columns 
WHERE table_name = 'tutor_profiles' AND table_schema = 'public'
ORDER BY column_name;
```

### Check RLS Policies
```sql
SELECT schemaname, tablename, policyname, cmd AS operation
FROM pg_policies 
WHERE tablename IN ('parent_profiles', 'learner_profiles', 'tutor_profiles')
ORDER BY tablename, policyname;
```

**Expected**: Each table should have 3 policies (SELECT, INSERT, UPDATE)

---

## 🎯 **Migration Tracking**

| Migration | File | Status | Applied Date |
|-----------|------|--------|--------------|
| 004 | tutor_requests.sql | ✅ Applied | Oct 30, 2025 |
| 006 | complete_parent_profiles_setup.sql | ✅ Applied | Oct 30, 2025 |
| 007 | complete_learner_profiles_setup.sql | ⏳ **Pending** | - |
| 008 | ensure_tutor_profiles_complete.sql | ⏳ **Pending** | - |

---

## 📝 **Next Steps After Migration**

1. **Apply migrations 007 & 008** (15 minutes)
2. **Test student onboarding** (10 minutes)
3. **Test tutor onboarding** (10 minutes)
4. **Test tutor discovery** (5 minutes)
5. **Test booking flows** (15 minutes)
6. **Fix any issues** (variable)

**Total estimated time**: ~1 hour for complete backend-frontend correlation

---

## 🚨 **Important Notes**

- All migrations are **idempotent** (safe to run multiple times)
- Migrations use `IF NOT EXISTS` / `IF EXISTS` to prevent conflicts
- RLS policies are dropped and recreated to ensure correctness
- Always test in **development environment** first if possible
- Keep `supabase/migrations/README.md` updated with status

---

**Questions or Issues?**  
Check `supabase/migrations/README.md` for detailed migration status and known issues.

---

Last Updated: October 30, 2025

