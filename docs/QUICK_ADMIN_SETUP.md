# ⚡ Quick Admin Setup - 5 Minutes

## 🎯 Setup Admin Login: prepskul@gmail.com / DE12$kimb

---

## 📋 Step-by-Step Instructions

### **Step 1: Run SQL Script (2 minutes)**

1. Go to: https://app.supabase.com → Your PrepSkul project
2. Click: **SQL Editor** (left sidebar)
3. Open file: `All mds/SETUP_ADMIN_USER.sql`
4. Copy ALL the SQL code
5. Paste into SQL Editor
6. Click **Run** (or press F5)
7. Check output - should show user status

---

### **Step 2: Create/Update User in Supabase (2 minutes)**

#### **If User Doesn't Exist:**

1. Go to: **Authentication** → **Users**
2. Click: **"Add User"** (green button)
3. Enter:
   - Email: `prepskul@gmail.com`
   - Password: `DE12$kimb`
   - ✅ **Check "Auto Confirm User"** (CRITICAL!)
4. Click: **"Create User"**

#### **If User Already Exists:**

1. Go to: **Authentication** → **Users**
2. Search for: `prepskul@gmail.com`
3. Click on the user
4. Click: **"Reset Password"** or **"Update User"**
5. Set password to: `DE12$kimb`
6. Make sure **"Email Confirmed"** is checked
7. Save

---

### **Step 3: Verify (1 minute)**

Run this in SQL Editor:

```sql
SELECT 
  p.email,
  p.is_admin,
  p.user_type,
  CASE WHEN u.id IS NOT NULL THEN '✅' ELSE '❌' END as user_exists
FROM profiles p
LEFT JOIN auth.users u ON p.id = u.id
WHERE p.email = 'prepskul@gmail.com';
```

**Should show:**
- `is_admin` = `true` ✅
- `user_type` = `'admin'` ✅
- `user_exists` = `'✅'` ✅

---

### **Step 4: Test Login**

1. Go to: `http://localhost:3000/admin/login` (or your admin URL)
2. Enter:
   - Email: `prepskul@gmail.com`
   - Password: `DE12$kimb`
3. Click: **"Sign In"**
4. Should redirect to admin dashboard ✅

---

## 🐛 Quick Fixes

### Can't Login?
- ✅ Check password is exactly: `DE12$kimb`
- ✅ Verify user is "Email Confirmed" in Supabase
- ✅ Run SQL script again

### "Access Denied"?
- ✅ Run this SQL:
  ```sql
  UPDATE profiles SET is_admin = TRUE WHERE email = 'prepskul@gmail.com';
  ```

### User Not Found?
- ✅ Create user in Supabase Dashboard (Step 2)
- ✅ Make sure "Auto Confirm User" is checked

---

## ✅ Done!

You should now be able to login with:
- **Email:** `prepskul@gmail.com`
- **Password:** `DE12$kimb`

---

**Need more help?** See: `docs/ADMIN_LOGIN_SETUP_NOW.md`

