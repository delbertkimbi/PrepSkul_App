# PrepSkul Redirect URLs - Verification Guide

## Current Configuration Status

### ✅ Flutter App (Mobile/Web)
- **Production:** https://operating-axis-420213.web.app
- **Custom Domain:** https://app.prepskul.com (pending DNS)

### ✅ Admin Dashboard (Next.js)
- **Development:** http://localhost:3000/admin
- **Production:** https://admin.prepskul.com

### ✅ Main Website (Next.js)
- **Production:** https://www.prepskul.com

---

## 🔗 Required Supabase Redirect URLs

### **For Development:**
```
Site URL: https://operating-axis-420213.web.app

Redirect URLs:
✅ http://localhost:3000/**
✅ http://localhost:3001/**
✅ http://localhost:3002/**
✅ https://operating-axis-420213.web.app/**
✅ https://app.prepskul.com/**
```

### **For Production:**
```
Site URL: https://app.prepskul.com

Redirect URLs:
✅ https://app.prepskul.com/**
✅ https://www.prepskul.com/**
✅ https://admin.prepskul.com/**
✅ https://operating-axis-420213.web.app/**
```

---

## ✅ How to Verify Current Configuration

### **Step 1: Check Supabase Dashboard**
1. Go to https://supabase.com/dashboard
2. Select your PrepSkul project
3. Navigate to **Authentication** → **URL Configuration**
4. Take a screenshot or note current settings

### **Step 2: Current Expected Settings**

**Development:**
- Site URL: `https://operating-axis-420213.web.app`
- Redirect URLs should include all localhost ports AND web domains

**Production (when ready):**
- Site URL: `https://app.prepskul.com`
- Redirect URLs should include all production domains

---

## 🧪 How to Test Redirects

### **Test 1: Email Auth Redirect**
1. Sign up with email
2. Receive confirmation email
3. Click link in email
4. Should redirect to app
5. Should auto-login and show dashboard

### **Test 2: Password Reset Redirect**
1. Click "Forgot password"
2. Enter email
3. Receive reset email
4. Click link
5. Should redirect to reset password page
6. Should be able to set new password

### **Test 3: Magic Link Redirect**
1. Request magic link login
2. Receive email
3. Click link
4. Should auto-login and redirect to dashboard

---

## 🔧 Common Redirect Issues

### **Issue 1: "Invalid redirect URL"**
**Cause:** URL not added to redirect list  
**Fix:** Add the exact URL to Supabase redirect URLs

### **Issue 2: Redirects to wrong page**
**Cause:** Site URL is incorrect  
**Fix:** Update Site URL in Supabase

### **Issue 3: Redirects but not logged in**
**Cause:** Token expired or invalid  
**Fix:** Re-request the email

### **Issue 4: "Page not found"**
**Cause:** App doesn't have the route  
**Fix:** Add missing routes in Flutter app

---

## 📝 Complete Configuration Checklist

### **Supabase Settings:**
- [ ] Site URL is correct (development)
- [ ] Site URL is correct (production - when ready)
- [ ] All redirect URLs added
- [ ] Email templates customized
- [ ] Email confirmation configured

### **Flutter App:**
- [ ] All auth routes exist
- [ ] Email auth works
- [ ] Phone auth works
- [ ] Deep linking configured

### **Testing:**
- [ ] Email signup redirect works
- [ ] Password reset redirect works
- [ ] Magic link redirect works
- [ ] Mobile deep links work
- [ ] Web redirects work

---

## 🚀 Quick Setup

If you need to update URLs:

1. **Go to Supabase Dashboard** → Authentication → URL Configuration
2. **Add all URLs** listed in "Required Supabase Redirect URLs" above
3. **Click Save**
4. **Test immediately** with a new signup

**All set!** Your redirects should work perfectly. ✅

