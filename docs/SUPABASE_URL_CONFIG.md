# 🔧 Supabase URL Configuration

## 📍 **Your Site URLs:**

Since your Next.js app uses locale prefixes, the URLs are:

**Main Site:**
- `http://localhost:3000/en` (with locale)
- `http://localhost:3000` (redirects to /en)

**Admin Dashboard:**
- `http://localhost:3000/admin/login` (no locale prefix)
- `http://localhost:3000/admin` (no locale prefix)

---

## ⚙️ **Supabase Settings:**

### **In Supabase Dashboard:**

1. Go to: https://app.supabase.com
2. Select your project
3. Go to **Authentication** → **URL Configuration**
4. Update:

**Site URL:**
```
http://localhost:3000
```

**Redirect URLs** (add all these):
```
http://localhost:3000/**
http://localhost:3000/admin/**
http://localhost:3000/auth/callback
http://localhost:3000/en/**
```

5. Click **Save**

---

## ✅ **Re-invite Admin User:**

1. Go to **Authentication** → **Users**
2. Delete the previous invited user
3. Click **"Invite User"**
4. Enter: `admin@prepskul.com` (or your email)
5. Check email - link will now be correct ✅

---

## 🎯 **For Production (Vercel):**

Update to:

**Site URL:**
```
https://admin.prepskul.com
```

**Redirect URLs:**
```
https://admin.prepskul.com/**
https://www.prepskul.com/**
https://prepskul.com/**
```

---

**After updating Supabase settings, re-invite the user and the email link will work!** ✅

