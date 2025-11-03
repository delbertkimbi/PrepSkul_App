# How to Enable Email Verification in Supabase

## 🎯 Simple Answer

**Go to Supabase Dashboard → Authentication → Email Auth**

**Toggle:** `Enable email confirmations` **ON** ✅

**That's it!** Your app will now send confirmation emails.

---

## 📝 Step-by-Step

### **Step 1: Access Supabase Dashboard**
1. Go to https://app.supabase.com
2. Select your project: **PrepSkul**

### **Step 2: Navigate to Email Settings**
1. Click **Authentication** in left sidebar
2. Click **Providers** tab
3. Click **Email** provider

### **Step 3: Enable Email Confirmation**
1. Scroll down to **"Enable email confirmations"**
2. **Toggle it ON** ✅
3. Click **Save**

---

## ⚙️ **What This Does**

### **Before (Development Mode):**
```
User signs up → Instantly logged in → Goes to survey
No email sent
```

### **After (Production Mode):**
```
User signs up → Confirmation screen → Email sent
User clicks link → Auto-detected → Goes to survey
```

---

## 🔧 **Additional Settings**

### **Confirmation Email Template:**
- **Default:** Supabase's basic template
- **Custom:** Use branded templates from `SUPABASE_EMAIL_CUSTOMIZATION.md`

### **Link Expiry:**
- **Default:** 24 hours
- Can adjust in settings

### **Redirect After Confirmation:**
Configured in **Authentication → URL Configuration**:
```
Site URL: https://app.prepskul.com
Redirect URLs: https://app.prepskul.com/**
```

---

## 🧪 **Testing**

### **To Test Email Confirmation:**

1. **Enable** email confirmations in Supabase
2. **Sign up** with a real email
3. **Check inbox** for confirmation email
4. **Click link** in email
5. **Should redirect** to app and auto-login

### **Development Tip:**

**Turn OFF** email confirmations for testing:
- Faster workflow
- No email delays
- Instant signup

**Turn ON** for production:
- Professional experience
- Email verification
- Secure authentication

---

## ✅ **Summary**

| Setting | For Development | For Production |
|---------|----------------|----------------|
| **Email Confirmations** | ❌ OFF | ✅ ON |
| **Why?** | Faster testing | Professional |
| **Your App** | Handles both! | Handles both! |

**Just toggle it in Supabase dashboard!** That's all you need to do. 🎉

---

## 🚨 **Important Notes**

1. **Redirect URLs** must be configured first (see `SUPABASE_URLS_TO_ADD.md`)
2. **Email templates** can be customized (see `SUPABASE_EMAIL_CUSTOMIZATION.md`)
3. **Your app code** already handles both modes automatically
4. **Deep links** must be set up for mobile apps

**Everything else is already built!** ✅

