# 🚀 Deployment Checklist for app.prepskul.com

**Date:** January 25, 2025

---

## ✅ **Bugs Fixed**

1. ✅ **Import Error Fixed:**
   - Added `import '../../../core/services/unblock_request_service.dart';` to `tutor_admin_feedback_screen.dart`
   - Error resolved: `The getter 'UnblockRequestService' isn't defined`

2. ✅ **Profile Completion Fixed:**
   - Added `'bio'` field to match completion service
   - Fixed `'previous_roles'` to save organization text
   - Added `'availability'` field for completion check

---

## 📋 **Environment Setup Verification**

### **Step 1: Verify .env File Exists**

```bash
cd /Users/user/Desktop/PrepSkul/prepskul_app
ls -la .env  # Should exist
```

### **Step 2: Verify Key Variables**

Check that these are set in `.env`:

```bash
# Environment
ENVIRONMENT=development  # or 'production'

# Fapshi (Sandbox for testing)
FAPSHI_ENVIRONMENT=sandbox
FAPSHI_SANDBOX_API_USER=4a148e87-e185-437d-a641-b465e2bd8d17
FAPSHI_SANDBOX_API_KEY=FAK_TEST_0293bda0f3ef142be85b

# Fathom
FATHOM_CLIENT_ID_DEV=R93SgO5R3BkFnV5HkvVmKQJWLrxAzAaKSntj8UNY1-4
FATHOM_CLIENT_SECRET_DEV=UknZ9sfoSNy2otV59k4_z600ERuXmHjd7edlrMrPRXY
FATHOM_REDIRECT_URI_DEV=https://app.prepskul.com/auth/fathom/callback

# Google Calendar
GOOGLE_CALENDAR_CLIENT_ID=your-google-calendar-client-id-here
GOOGLE_CALENDAR_CLIENT_SECRET=your-google-calendar-client-secret-here
GOOGLE_OAUTH_REDIRECT_URI_DEV=https://app.prepskul.com/auth/google/callback

# Supabase
SUPABASE_URL_DEV=https://cpzaxdfxbamdsshdgjyg.supabase.co
SUPABASE_ANON_KEY_DEV=eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...
```

### **Step 3: Verify Next.js .env.local**

```bash
cd /Users/user/Desktop/PrepSkul/PrepSkul_Web
ls -la .env.local  # Should exist
```

If missing:
```bash
cp ../prepskul_app/env.template .env.local
# Then fill in all values
```

---

## 🔐 **OAuth Redirect URLs**

### **Must Match in Provider Dashboards:**

#### **1. Fathom Dashboard:**
- URL: https://app.fathom.video/
- Go to: Settings → OAuth Apps
- **Redirect URI must be:** `https://app.prepskul.com/auth/fathom/callback`

#### **2. Google Cloud Console:**
- URL: https://console.cloud.google.com/
- Go to: APIs & Services → Credentials
- Find OAuth 2.0 Client ID
- **Authorized redirect URIs must include:** `https://app.prepskul.com/auth/google/callback`

---

## ✅ **What Works in Sandbox Mode**

### **✅ Can Test on app.prepskul.com (Sandbox):**

1. **Fapshi Payments:**
   - ✅ Sandbox credentials work on any domain
   - ✅ Test payments process (no real money)
   - ✅ Webhooks work
   - **Status:** ✅ Ready

2. **Fathom AI:**
   - ✅ OAuth flow works
   - ✅ Auto-join meetings
   - ✅ Webhooks for recordings
   - **Status:** ✅ Ready (if redirect URI matches)

3. **Google Calendar:**
   - ✅ OAuth flow works
   - ✅ Create calendar events
   - ✅ Generate Meet links
   - **Status:** ✅ Ready (if redirect URI matches)

4. **Supabase:**
   - ✅ Works on any domain
   - ✅ No domain restrictions
   - **Status:** ✅ Ready

5. **Email (Resend):**
   - ⚠️ Works but uses test domain (`onboarding@resend.dev`)
   - ⚠️ For production, need verified domain
   - **Status:** ⚠️ Works for testing

---

## 🧪 **Testing Strategy**

### **Recommended: Test in Sandbox First**

1. **Set Environment:**
   ```bash
   ENVIRONMENT=development
   FAPSHI_ENVIRONMENT=sandbox
   ```

2. **Test Features:**
   - ✅ Trial session booking
   - ✅ Payment initiation (sandbox)
   - ✅ Google Meet link generation
   - ✅ Fathom OAuth flow
   - ✅ Webhooks

3. **Verify:**
   - ✅ No real money transactions
   - ✅ All OAuth redirects work
   - ✅ Webhooks receive events

### **Then Switch to Live (When Ready)**

1. **Set Environment:**
   ```bash
   ENVIRONMENT=production
   FAPSHI_ENVIRONMENT=live
   ```

2. **Use Live Credentials:**
   - `FAPSHI_COLLECTION_API_KEY_LIVE`
   - `FAPSHI_DISBURSE_API_KEY_LIVE`
   - `FATHOM_CLIENT_ID_PROD`
   - `FATHOM_CLIENT_SECRET_PROD`

---

## 📝 **Pre-Deployment Checklist**

Before pushing to app.prepskul.com:

- [x] ✅ Bugs fixed (import error, profile completion)
- [ ] ⚠️ `.env` file exists and filled
- [ ] ⚠️ `.env.local` exists in `PrepSkul_Web/` and filled
- [ ] ⚠️ Fathom redirect URI matches dashboard
- [ ] ⚠️ Google OAuth redirect URI matches console
- [ ] ⚠️ `FAPSHI_ENVIRONMENT=sandbox` for testing
- [ ] ⚠️ `.env` and `.env.local` in `.gitignore`
- [ ] ⚠️ Test locally first

---

## 🚀 **Deployment Steps**

### **1. Flutter App (app.prepskul.com)**

```bash
cd /Users/user/Desktop/PrepSkul/prepskul_app

# Verify .env exists
ls -la .env

# Build for web
flutter build web

# Deploy (your deployment method)
# Note: .env is NOT included in build, set env vars in hosting platform
```

**Important:** For Flutter web, environment variables need to be:
- Set in hosting platform (Vercel, Firebase, etc.)
- OR loaded at runtime from a config endpoint
- OR embedded at build time (not recommended for secrets)

### **2. Next.js App (www.prepskul.com)**

```bash
cd /Users/user/Desktop/PrepSkul/PrepSkul_Web

# Verify .env.local exists
ls -la .env.local

# Build
npm run build  # or pnpm build

# Deploy to Vercel
# Vercel automatically uses .env.local or environment variables set in dashboard
```

**Important:** For Vercel:
- Set environment variables in Vercel Dashboard
- OR commit `.env.local` (NOT recommended for production secrets)
- Best: Set in Vercel Dashboard → Settings → Environment Variables

---

## ⚠️ **Important Notes**

### **Sandbox vs Live:**

1. **Sandbox Mode:**
   - ✅ Works on app.prepskul.com
   - ✅ No real money
   - ✅ Safe for testing
   - ✅ Use `FAPSHI_ENVIRONMENT=sandbox`

2. **Live Mode:**
   - ⚠️ Real money transactions
   - ⚠️ Use only when ready
   - ⚠️ Use `FAPSHI_ENVIRONMENT=live`
   - ⚠️ Use live credentials

### **OAuth Redirects:**

- **Must match exactly** what's configured in provider dashboards
- Fathom: `https://app.prepskul.com/auth/fathom/callback`
- Google: `https://app.prepskul.com/auth/google/callback`
- **Check both dashboards before deploying**

### **Environment Variables:**

- **Never commit** `.env` or `.env.local` to Git
- **Set in hosting platform** for production
- **Use different keys** for dev/prod

---

## ✅ **Summary**

### **✅ Ready to Deploy:**

- ✅ Bugs fixed
- ✅ Sandbox mode works on app.prepskul.com
- ✅ OAuth flows work (if redirect URIs match)
- ✅ Webhooks work on any domain

### **⚠️ Before Deploying:**

1. Verify `.env` has all credentials
2. Verify `.env.local` in Next.js app
3. Check OAuth redirect URIs match dashboards
4. Test locally first
5. Use sandbox mode for initial testing

### **🚀 Next Steps:**

1. ✅ Fix bugs (done)
2. ⚠️ Verify environment variables
3. ⚠️ Check OAuth redirect URIs
4. ⚠️ Test locally
5. ⚠️ Deploy to app.prepskul.com
6. ⚠️ Test in sandbox mode
7. ⚠️ Switch to live when ready

---

**Last Updated:** January 25, 2025  
**Status:** ✅ Bugs Fixed, Ready for Environment Verification

