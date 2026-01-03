# 🔧 Admin Login Setup - Quick Fix

## 🎯 Goal
Set up admin login with:
- **Email:** `prepskul@gmail.com`
- **Password:** `DE12$kimb`

---

## ✅ Step 1: Run SQL Script

1. **Go to Supabase Dashboard:**
   - Visit: https://app.supabase.com
   - Select your **PrepSkul** project
   - Click **SQL Editor** in the left sidebar

2. **Run the SQL Script:**
   - Open the file: `All mds/SETUP_ADMIN_USER.sql`
   - Copy the entire contents
   - Paste into Supabase SQL Editor
   - Click **Run** (or press F5)

3. **Check the Output:**
   - You should see a result showing the user status
   - If it says "User NOT in auth.users ❌", proceed to Step 2
   - If it shows "User exists in auth.users ✅", proceed to Step 3

---

## ✅ Step 2: Create User in Supabase (If Not Exists)

1. **Go to:** **Authentication** → **Users**

2. **Click:** **"Add User"** (green button, top right)

3. **Fill in:**
   - **Email:** `prepskul@gmail.com`
   - **Password:** `DE12$kimb`
   - ✅ **IMPORTANT:** Check **"Auto Confirm User"** (this is critical!)
   - ✅ **IMPORTANT:** Check **"Send invitation email"** (uncheck this - we don't need it)

4. **Click:** **"Create User"**

---

## ✅ Step 3: Update Password (If User Already Exists)

If the user already exists but you need to change the password:

1. **Go to:** **Authentication** → **Users**

2. **Find the user:**
   - Search for: `prepskul@gmail.com`
   - Click on the user row

3. **Update Password:**
   - Click **"Reset Password"** button
   - OR click **"Update User"** and set the password field to: `DE12$kimb`
   - Click **"Save"**

4. **Verify Auto-Confirmation:**
   - Make sure **"Email Confirmed"** is checked
   - If not, click **"Confirm Email"** or check **"Auto Confirm"** when creating

---

## ✅ Step 4: Verify Admin Permissions

Run this SQL query in Supabase SQL Editor to verify:

```sql
SELECT 
  p.id,
  p.email,
  p.full_name,
  p.is_admin,
  p.user_type,
  u.email_confirmed_at,
  CASE 
    WHEN u.id IS NOT NULL THEN '✅ User exists'
    ELSE '❌ User missing'
  END as auth_status
FROM profiles p
LEFT JOIN auth.users u ON p.id = u.id
WHERE p.email = 'prepskul@gmail.com';
```

**Expected Output:**
- `is_admin` should be `true` ✅
- `user_type` should be `'admin'` ✅
- `auth_status` should be `'✅ User exists'` ✅
- `email_confirmed_at` should have a timestamp ✅

---

## ✅ Step 5: Test Login

1. **Open Admin Dashboard:**
   - URL: `http://localhost:3000/admin/login` (if running locally)
   - OR: `https://admin.prepskul.com/admin/login` (if deployed)

2. **Enter Credentials:**
   - Email: `prepskul@gmail.com`
   - Password: `DE12$kimb`

3. **Click:** **"Sign In"**

4. **Expected Result:**
   - Should redirect to `/admin` dashboard
   - Should see admin navigation and stats

---

## 🐛 Troubleshooting

### Issue: "Invalid login credentials"

**Solutions:**
1. ✅ Verify password is exactly: `DE12$kimb` (case-sensitive)
2. ✅ Check user exists: Go to Authentication → Users → Search for email
3. ✅ Verify user is auto-confirmed: Check "Email Confirmed" status
4. ✅ Try resetting password again in Supabase Dashboard

### Issue: "Access Denied" or "Not an admin"

**Solutions:**
1. ✅ Run the SQL script again (Step 1)
2. ✅ Verify `is_admin = TRUE` in profiles table:
   ```sql
   SELECT email, is_admin FROM profiles WHERE email = 'prepskul@gmail.com';
   ```
3. ✅ If `is_admin` is `false`, run:
   ```sql
   UPDATE profiles SET is_admin = TRUE WHERE email = 'prepskul@gmail.com';
   ```

### Issue: User not found in auth.users

**Solutions:**
1. ✅ Create user manually (Step 2)
2. ✅ Make sure to check "Auto Confirm User"
3. ✅ After creating, run the SQL script again

### Issue: "Email not confirmed"

**Solutions:**
1. ✅ Go to Authentication → Users
2. ✅ Find the user
3. ✅ Click "Confirm Email" button
4. ✅ OR delete and recreate with "Auto Confirm" checked

---

## 🔍 Quick Verification Queries

### Check if user exists:
```sql
SELECT id, email, email_confirmed_at 
FROM auth.users 
WHERE email = 'prepskul@gmail.com';
```

### Check admin permissions:
```sql
SELECT email, is_admin, user_type 
FROM profiles 
WHERE email = 'prepskul@gmail.com';
```

### Check everything:
```sql
SELECT 
  u.id as auth_id,
  u.email as auth_email,
  u.email_confirmed_at,
  p.id as profile_id,
  p.email as profile_email,
  p.is_admin,
  p.user_type
FROM auth.users u
FULL OUTER JOIN profiles p ON u.id = p.id
WHERE u.email = 'prepskul@gmail.com' OR p.email = 'prepskul@gmail.com';
```

---

## ✅ Final Checklist

Before testing login, verify:

- [ ] User exists in `auth.users` table
- [ ] User email is confirmed (`email_confirmed_at` is not null)
- [ ] Profile exists in `profiles` table
- [ ] `is_admin = TRUE` in profiles table
- [ ] `user_type = 'admin'` in profiles table
- [ ] Password is set to: `DE12$kimb`
- [ ] SQL script has been run successfully

---

## 🚀 You're Ready!

Once all checkboxes are ✅, try logging in at:
- **Local:** `http://localhost:3000/admin/login`
- **Production:** `https://admin.prepskul.com/admin/login`

**Credentials:**
- Email: `prepskul@gmail.com`
- Password: `DE12$kimb`

---

## 📝 Notes

- Passwords are encrypted and cannot be viewed
- You can only reset passwords, not retrieve them
- Always use "Auto Confirm User" when creating admin accounts
- The SQL script ensures admin permissions are set correctly

