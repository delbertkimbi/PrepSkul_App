# 🚨 Required Database Migrations

## Apply These SQL Scripts in Supabase Dashboard

### ✅ **Step 1: Create Tutor Requests Table**

**File:** `supabase/migrations/004_tutor_requests.sql`

**Go to:** Supabase Dashboard → SQL Editor → Copy/paste entire file

This creates:
- `tutor_requests` table for custom tutor requests
- RLS policies for users and admins
- Proper indexes for performance

**Verify:**
```sql
SELECT COUNT(*) FROM public.tutor_requests;
-- Should return 0 (no error)
```

---

### ✅ **Step 2: Fix Parent Profiles Schema**

**File:** `supabase/migrations/005_fix_parent_profiles.sql`

**Go to:** Supabase Dashboard → SQL Editor → Copy/paste entire file

This adds missing columns:
- `child_confidence_level` (TEXT)
- `challenges` (TEXT[])

**Verify:**
```sql
SELECT column_name, data_type 
FROM information_schema.columns 
WHERE table_name = 'parent_profiles' 
AND column_name IN ('child_confidence_level', 'challenges');
-- Should show both columns
```

---

## 📊 Current Migration Status

| Migration | File | Status | Required For |
|-----------|------|--------|--------------|
| 003 | `003_booking_system.sql` | ✅ Applied | Booking system |
| 004 | `004_tutor_requests.sql` | ❌ **Missing** | Custom tutor requests |
| 005 | `005_fix_parent_profiles.sql` | ❌ **Missing** | Parent survey submission |

---

## 🔧 Quick Apply (All at Once)

If you prefer, you can run both migrations in one go:

```sql
-- Run 004_tutor_requests.sql content here
-- Then run 005_fix_parent_profiles.sql content here
```

---

## ✅ After Applying

1. **Restart the Flutter app** (full restart, not hot reload)
2. **Test parent survey** - Should submit without errors
3. **Test custom tutor request** - Should save to database
4. **Check My Requests screen** - Should load without errors

---

## 🎯 What These Fix

### Before Migrations:
- ❌ Parent survey fails with `child_confidence_level` error
- ❌ Custom tutor request fails with `tutor_requests` table not found error
- ❌ My Requests screen shows database errors

### After Migrations:
- ✅ Parent survey submits successfully
- ✅ Custom tutor requests save to database
- ✅ My Requests screen loads all request types
- ✅ WhatsApp notification works for custom requests
- ✅ No more PostgrestException errors

---

## 💡 Budget Changes (Already Applied)

Both surveys now use **monthly budget** instead of per-session:

- **Old Range:** 2,500 - 15,000 XAF per session
- **New Range:** 20,000 - 55,000 XAF per month

This better reflects Cameroon's payment culture where tutoring is typically paid monthly.

---

**Need Help?** Check Supabase documentation or contact support if migrations fail.

