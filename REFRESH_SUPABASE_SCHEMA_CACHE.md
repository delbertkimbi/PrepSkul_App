# 🔄 Refresh Supabase Schema Cache

## ✅ **The Fix Applied Successfully!**

The database columns were renamed from `student_*` to `learner_*`, but Supabase's schema cache is still using the old names.

---

## 🚀 **How to Refresh Schema Cache**

### **Option 1: Restart Supabase (Recommended)**

In your **Supabase Dashboard**:

1. Go to **Settings** → **Database**
2. Click **"Restart Database"** button
3. Wait 30 seconds for restart
4. ✅ Schema cache will be automatically refreshed

### **Option 2: Force Schema Reload (SQL)**

Run this in **SQL Editor**:

```sql
-- Notify Supabase to reload schema cache
NOTIFY pgrst, 'reload schema';

-- Alternative: Reload config
NOTIFY pgrst, 'reload config';
```

### **Option 3: Wait (Automatic - 5-10 minutes)**

Supabase automatically refreshes schema cache every 5-10 minutes.
Just wait and try again!

---

## 🧪 **Test After Refresh**

1. Wait for schema cache refresh (30 seconds - 10 minutes depending on method)
2. In your app, press `R` (hot restart)
3. Try booking again
4. ✅ Should work perfectly!

---

## 📊 **Verify Schema Was Renamed**

Run this to confirm columns were renamed:

```sql
SELECT column_name, data_type 
FROM information_schema.columns 
WHERE table_name = 'session_requests' 
AND column_name LIKE 'learner%'
ORDER BY column_name;
```

**Expected Output:**
- `learner_avatar_url` (text)
- `learner_id` (uuid)
- `learner_name` (text)
- `learner_type` (text)

---

## ⚡ **Quick Fix (No Restart Needed)**

If you don't want to restart, just **wait 5-10 minutes** and try again!

Supabase PostgREST (the API layer) automatically reloads schema cache periodically.

---

## 🎯 **Summary**

1. ✅ Database schema updated (student_* → learner_*)
2. ✅ App code already uses learner_* fields
3. ⏳ Waiting for Supabase schema cache refresh
4. 🚀 Then booking will work!

**The fix is complete - just needs cache refresh!** 🎉

