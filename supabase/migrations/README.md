# PrepSkul Database Migrations

## ✅ Applied Migrations (Production)

These migrations have been applied directly to the production Supabase database:

1. **001_initial_schema.sql** - Initial database setup (if exists)
2. **002_booking_system.sql** - Booking system tables
3. **003_booking_system.sql** - Booking system updates
4. **004_tutor_requests.sql** - ✅ Tutor request table & RLS (APPLIED)
5. **005_fix_parent_profiles.sql** - Parent profiles missing columns (PARTIAL)
6. **006_complete_parent_profiles_setup.sql** - ✅ **COMPLETE** (ALL FIXES)
7. **007_complete_learner_profiles_setup.sql** - ⚠️ **NEEDS TO BE APPLIED**
8. **008_ensure_tutor_profiles_complete.sql** - ⚠️ **NEEDS TO BE APPLIED**

## 📋 Migration Status by Feature

### Parent Onboarding (✅ WORKING)
- [x] All columns added to `parent_profiles`
- [x] RLS policies configured
- [x] ID auto-generation enabled
- [x] Array formatting fixed in code
- **Status**: ✅ **FULLY FUNCTIONAL**

### Student Onboarding (⚠️ NEEDS TESTING)
- [ ] Apply migration 007
- [ ] Test student survey submission
- **Status**: ⚠️ **MIGRATION NEEDED**

### Tutor Onboarding (⚠️ NEEDS TESTING)
- [ ] Apply migration 008
- [ ] Test tutor profile creation
- [ ] Test admin approval workflow
- **Status**: ⚠️ **MIGRATION NEEDED**

## 🚀 Next Steps

### 1. Apply Remaining Migrations

Run these in Supabase SQL Editor in order:

```sql
-- MIGRATION 007: Student Profiles
-- Copy from: 007_complete_learner_profiles_setup.sql

-- MIGRATION 008: Tutor Profiles  
-- Copy from: 008_ensure_tutor_profiles_complete.sql
```

### 2. Test All Flows

After applying migrations:

- [ ] Test Student Survey (create new student account)
- [ ] Test Tutor Onboarding (create new tutor account)
- [ ] Test Tutor Discovery (browse tutors as student)
- [ ] Test Booking Flow (book a session)
- [ ] Test Trial Session Booking
- [ ] Test Custom Tutor Requests

### 3. Verify Database Consistency

Check that all tables have:
- ✅ Proper RLS policies
- ✅ UUID auto-generation for `id` columns
- ✅ All required columns
- ✅ Proper foreign key relationships

## 🔍 Known Issues & Fixes

### Issue 1: "Could not find column in schema cache"
**Cause**: Missing columns in table  
**Fix**: Run migration to add columns  
**Status**: Fixed for `parent_profiles`

### Issue 2: "Malformed array literal"
**Cause**: Sending string instead of array for TEXT[] columns  
**Fix**: Wrap single values in array brackets `[value]`  
**Status**: Fixed in code (`preferred_schedule`)

### Issue 3: "Row-level security policy violation"
**Cause**: Missing RLS policies  
**Fix**: Create policies allowing users to manage own data  
**Status**: Fixed for `parent_profiles`

### Issue 4: "Null value in column 'id' violates not-null constraint"
**Cause**: `id` column doesn't auto-generate UUIDs  
**Fix**: `ALTER COLUMN id SET DEFAULT gen_random_uuid()`  
**Status**: Fixed for `parent_profiles`

## 📝 Notes

- All migrations use `IF NOT EXISTS` / `IF EXISTS` to be idempotent
- RLS policies are dropped and recreated to avoid conflicts
- Column comments added for documentation
- Each migration includes verification query at the end

## 🎯 Current Priority

**PRIORITY 1**: Apply migrations 007 & 008 to ensure all user flows work  
**PRIORITY 2**: Test all onboarding flows end-to-end  
**PRIORITY 3**: Test booking & discovery features

---

Last Updated: October 30, 2025

