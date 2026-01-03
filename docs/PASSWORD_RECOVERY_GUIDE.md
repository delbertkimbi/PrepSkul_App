# 🔑 Password Recovery Guide - Admin & Tutor Accounts

## 📋 Overview

This guide explains how to recover/reset passwords for:
1. **Admin Dashboard** login
2. **Tutor Account** login

**Important:** Passwords are encrypted in Supabase and **cannot be retrieved**. You can only **reset** them.

---

## 🔐 Part 1: Admin Dashboard Password Recovery

### **Where Admin Credentials Are Stored:**

1. **Authentication Data:** `auth.users` table (Supabase managed)
   - Contains: email, encrypted password, user ID
   - Location: Supabase Dashboard → Authentication → Users

2. **Admin Permissions:** `profiles` table
   - Column: `is_admin` (BOOLEAN)
   - Location: Supabase Dashboard → Table Editor → `profiles`

### **How to Reset Admin Password:**

#### **Option 1: Reset via Supabase Dashboard (Recommended)**

1. **Go to Supabase Dashboard:**
   - Visit: https://app.supabase.com
   - Select your **PrepSkul** project
   - Navigate to: **Authentication** → **Users**

2. **Find Your Admin User:**
   - Search for your admin email (e.g., `prepskul@gmail.com`)
   - Click on the user row

3. **Reset Password:**
   - Click **"Reset Password"** button (or **"Send Password Reset Email"**)
   - This will send a password reset email to the admin email
   - Check your email inbox (and spam folder)
   - Click the reset link in the email
   - Set a new password

4. **Verify Admin Status:**
   - Go to: **Table Editor** → **profiles**
   - Find your email
   - Verify `is_admin = true`

#### **Option 2: Reset via SQL (If you have database access)**

If you need to reset the password directly in the database:

```sql
-- First, find your admin user ID
SELECT id, email FROM auth.users WHERE email = 'your-admin-email@example.com';

-- Note: You cannot directly set a password in auth.users
-- You must use Supabase's password reset feature or update via API
```

**Note:** You cannot directly set passwords via SQL because they're encrypted. Use Option 1 instead.

#### **Option 3: Create New Admin User (If you can't access the old one)**

1. **Create New User in Supabase:**
   - Go to: **Authentication** → **Users** → **Add User**
   - Email: Your new admin email
   - Password: Choose a strong password
   - ✅ **Check "Auto Confirm User"**
   - Click **"Create User"**

2. **Make User Admin:**
   - Go to: **SQL Editor** in Supabase
   - Run this SQL (replace with your email):

```sql
-- Add is_admin column if it doesn't exist
ALTER TABLE profiles 
ADD COLUMN IF NOT EXISTS is_admin BOOLEAN DEFAULT FALSE;

-- Make your user admin
UPDATE profiles 
SET is_admin = TRUE 
WHERE email = 'your-new-admin-email@example.com';

-- Verify it worked
SELECT id, email, is_admin FROM profiles WHERE email = 'your-new-admin-email@example.com';
```

---

## 👨‍🏫 Part 2: Tutor Account Password Recovery

### **Where Tutor Credentials Are Stored:**

1. **Authentication Data:** `auth.users` table
   - Contains: email/phone, encrypted password, user ID
   - Location: Supabase Dashboard → Authentication → Users

2. **Tutor Profile Data:** `profiles` table
   - Contains: email, full_name, phone_number, user_type ('tutor')
   - Location: Supabase Dashboard → Table Editor → `profiles`

3. **Tutor Details:** `tutor_profiles` table
   - Contains: bio, education, experience, subjects, hourly_rate, etc.
   - Location: Supabase Dashboard → Table Editor → `tutor_profiles`
   - **Note:** This table has `user_id` column that links to `profiles.id`

### **Table Structure:**

```
auth.users (Supabase managed)
  ├── id (UUID) - Primary key
  ├── email (TEXT)
  ├── phone (TEXT, nullable)
  └── encrypted_password (TEXT) - Cannot be read directly

profiles (Your custom table)
  ├── id (UUID) - References auth.users.id
  ├── email (TEXT)
  ├── full_name (TEXT)
  ├── phone_number (TEXT)
  ├── user_type (TEXT) - 'tutor', 'learner', or 'parent'
  └── is_admin (BOOLEAN)

tutor_profiles (Tutor-specific data)
  ├── id (UUID) - References profiles.id
  ├── user_id (UUID) - Also references profiles.id
  ├── bio (TEXT)
  ├── education (TEXT)
  ├── experience (TEXT)
  ├── subjects (TEXT[])
  ├── hourly_rate (NUMERIC)
  └── ... (other tutor fields)
```

### **How to Find Your Tutor Account:**

#### **Step 1: Find Your Tutor Email/Phone**

Go to Supabase Dashboard → **Table Editor** → **profiles**

Run this query to see all tutors:

```sql
SELECT id, email, phone_number, full_name, user_type 
FROM profiles 
WHERE user_type = 'tutor'
ORDER BY created_at DESC;
```

Or search by your email:

```sql
SELECT id, email, phone_number, full_name, user_type 
FROM profiles 
WHERE email = 'your-email@example.com';
```

#### **Step 2: Check Tutor Profile Details**

```sql
SELECT tp.*, p.email, p.full_name, p.phone_number
FROM tutor_profiles tp
JOIN profiles p ON tp.user_id = p.id
WHERE p.email = 'your-email@example.com';
```

### **How to Reset Tutor Password:**

#### **Option 1: Reset via Supabase Dashboard (Recommended)**

1. **Go to Supabase Dashboard:**
   - Navigate to: **Authentication** → **Users**

2. **Find Your Tutor Account:**
   - Search by email or phone number
   - Click on the user row

3. **Reset Password:**
   - Click **"Reset Password"** or **"Send Password Reset Email"**
   - Check your email inbox
   - Click the reset link
   - Set a new password

#### **Option 2: Use Password Reset Feature in App**

1. Open the PrepSkul mobile app
2. Go to **Login** screen
3. Click **"Forgot Password"**
4. Enter your email or phone number
5. Follow the reset instructions

#### **Option 3: Check if Account Exists**

If you're not sure which email/phone you used:

```sql
-- Check all users in auth.users
SELECT id, email, phone, created_at 
FROM auth.users 
ORDER BY created_at DESC;

-- Match with profiles table
SELECT 
  u.id,
  u.email,
  u.phone,
  p.full_name,
  p.user_type,
  p.is_admin
FROM auth.users u
LEFT JOIN profiles p ON u.id = p.id
ORDER BY u.created_at DESC;
```

---

## 🔍 Quick Reference: Table Names

| Purpose | Table Name | Location in Supabase |
|---------|-----------|---------------------|
| **All user passwords** | `auth.users` | Authentication → Users |
| **User profiles** | `profiles` | Table Editor → profiles |
| **Tutor details** | `tutor_profiles` | Table Editor → tutor_profiles |
| **Admin flag** | `profiles.is_admin` | Table Editor → profiles (column) |

---

## ⚠️ Important Notes

1. **Passwords Cannot Be Retrieved:**
   - Passwords are encrypted using bcrypt
   - You can only **reset** them, not view them

2. **Admin Access:**
   - Admin status is stored in `profiles.is_admin`
   - Must be `TRUE` to access admin dashboard
   - Check with: `SELECT email, is_admin FROM profiles WHERE email = 'your-email'`

3. **Tutor Account:**
   - Tutor data is split across 3 tables:
     - `auth.users` - Authentication (password)
     - `profiles` - Basic profile (email, name, phone)
     - `tutor_profiles` - Tutor-specific data (bio, subjects, etc.)

4. **Password Reset Email:**
   - Make sure email is configured in Supabase
   - Check spam folder if email doesn't arrive
   - Email may take 1-5 minutes to arrive

---

## 🚀 Quick SQL Queries

### **Find Admin Users:**
```sql
SELECT p.id, p.email, p.full_name, p.is_admin
FROM profiles p
WHERE p.is_admin = TRUE;
```

### **Find All Tutors:**
```sql
SELECT 
  p.id,
  p.email,
  p.phone_number,
  p.full_name,
  tp.bio,
  tp.subjects
FROM profiles p
JOIN tutor_profiles tp ON tp.user_id = p.id
WHERE p.user_type = 'tutor';
```

### **Find Specific Tutor by Email:**
```sql
SELECT 
  p.id,
  p.email,
  p.phone_number,
  p.full_name,
  tp.*
FROM profiles p
LEFT JOIN tutor_profiles tp ON tp.user_id = p.id
WHERE p.email = 'your-email@example.com';
```

### **Check if User Exists in auth.users:**
```sql
SELECT id, email, phone, created_at
FROM auth.users
WHERE email = 'your-email@example.com'
   OR phone = '+237XXXXXXXXX';
```

---

## ✅ Summary

1. **Admin Password:** Reset via Supabase Dashboard → Authentication → Users → Reset Password
2. **Tutor Password:** Same as above, or use app's "Forgot Password" feature
3. **Table Names:**
   - `auth.users` - All passwords (encrypted)
   - `profiles` - User profiles (including admin flag)
   - `tutor_profiles` - Tutor-specific data

**Remember:** You cannot view passwords, only reset them! 🔒

