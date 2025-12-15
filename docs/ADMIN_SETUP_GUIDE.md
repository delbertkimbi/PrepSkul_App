# Admin Dashboard Setup Guide

## 🎯 IMPORTANT: There is NO separate "admin" table!

Admin permissions are stored as a **column** in the existing `profiles` table.

---

## ✅ Step-by-Step Setup

### **1. Create Admin User in Supabase**

Go to **Supabase Dashboard** → **Authentication** → **Users**

1. Click **"Add User"** (green button, top right)
2. Choose **"Create new user"** (NOT invite via email)
3. Fill in:
   - **Email:** `prepskul@gmail.com` (or your email)
   - **Password:** Choose a strong password (e.g., `Admin123!@#`)
   - ✅ **IMPORTANT:** Check **"Auto Confirm User"**
4. Click **"Create User"**

---

### **2. Add `is_admin` Column to Profiles Table**

Go to **SQL Editor** in Supabase and run:

```sql
-- Add admin permission column to existing profiles table
ALTER TABLE profiles 
ADD COLUMN IF NOT EXISTS is_admin BOOLEAN DEFAULT FALSE;
```

---

### **3. Make Your User Admin**

Still in **SQL Editor**, run (change email to yours):

```sql
-- Make your email admin
UPDATE profiles 
SET is_admin = TRUE 
WHERE email = 'prepskul@gmail.com';
```

**Verify it worked:**
```sql
-- Check if admin was set
SELECT id, email, is_admin FROM profiles WHERE is_admin = TRUE;
```

You should see your email with `is_admin = true`!

---

### **4. Add Review Columns to Tutor Profiles**

For the admin to approve/reject tutors, run:

```sql
-- Add review columns to tutor_profiles table
ALTER TABLE tutor_profiles 
ADD COLUMN IF NOT EXISTS status TEXT DEFAULT 'pending';

ALTER TABLE tutor_profiles
ADD COLUMN IF NOT EXISTS reviewed_by UUID;

ALTER TABLE tutor_profiles
ADD COLUMN IF NOT EXISTS reviewed_at TIMESTAMPTZ;

ALTER TABLE tutor_profiles
ADD COLUMN IF NOT EXISTS admin_review_notes TEXT;
```

---

## 🚀 Test the Admin Dashboard

1. **Go to:** `http://localhost:3000/admin/login`
2. **Enter:**
   - Email: `prepskul@gmail.com`
   - Password: (what you set)
3. **Click "Sign In"**
4. **You should see the admin dashboard!** 🎉

---

## 📊 Admin Features

### **Dashboard** (`/admin`)
- Total users count
- Pending tutors count
- Active sessions
- Revenue stats

### **Pending Tutors** (`/admin/tutors/pending`)
- View all pending tutor applications
- See full name, email, phone
- **Approve** button (changes status to 'approved')
- **Reject** button (changes status to 'rejected')

### **Users** (`/admin/users`)
- Manage all users (coming soon)

### **Analytics** (`/admin/analytics`)
- Platform analytics (coming soon)

---

## 🔍 Troubleshooting

### "Invalid login credentials"
- Make sure you **auto-confirmed** the user
- Check email is correct
- Check password is correct

### "Access Denied"
- Run the `UPDATE profiles SET is_admin = TRUE` SQL
- Verify with `SELECT * FROM profiles WHERE email = 'your-email'`

### "No pending tutors showing"
- You need tutors who have completed onboarding in the Flutter app
- Their `status` should be 'pending'

---

## 🎨 UI Features Added

✅ Show/hide password toggle (eye icon)  
✅ Clean, modern gradient design  
✅ Error messages  
✅ Loading states  
✅ Responsive layout  

---

## 📝 Summary

- **No admin table** - just a column (`is_admin`) in `profiles`
- **4 SQL commands** to run (total)
- **Email login** (not phone) to save OTP tokens
- **Simple, clean UI** for admins
- **Ready for production** after Supabase URL update

---

**You're all set!** 🚀

