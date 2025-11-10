# Environment Testing Guide

**Date:** January 25, 2025

---

## 🎯 **Testing on app.prepskul.com**

### **What Works in Sandbox Mode:**

✅ **Fapshi Payments (Sandbox):**
- Sandbox credentials work on any domain (including app.prepskul.com)
- Test payments can be processed
- No real money is transferred
- **Status:** ✅ Ready to test on app.prepskul.com

✅ **Fathom AI:**
- OAuth credentials work on any domain
- Redirect URLs must match what's configured in Fathom dashboard
- Currently set to: `https://app.prepskul.com/auth/fathom/callback`
- **Status:** ✅ Ready to test on app.prepskul.com

✅ **Google Calendar:**
- OAuth credentials work on any domain
- Redirect URLs must match Google Cloud Console
- Currently set to: `https://app.prepskul.com/auth/google/callback`
- **Status:** ✅ Ready to test on app.prepskul.com

✅ **Supabase:**
- Works on any domain (no domain restrictions)
- Uses API keys for authentication
- **Status:** ✅ Ready to test on app.prepskul.com

⚠️ **Resend (Email):**
- API key works on any domain
- But emails sent from `onboarding@resend.dev` (test domain)
- For production, need verified domain
- **Status:** ⚠️ Works but uses test email domain

---

## 📋 **Environment Variables Checklist**

### **For Testing on app.prepskul.com:**

#### **✅ Required (Already in env.template):**

1. **Supabase:**
   - ✅ `SUPABASE_URL_DEV` / `SUPABASE_URL_PROD`
   - ✅ `SUPABASE_ANON_KEY_DEV` / `SUPABASE_ANON_KEY_PROD`
   - ✅ `SUPABASE_SERVICE_ROLE_KEY_DEV` / `SUPABASE_SERVICE_ROLE_KEY_PROD`

2. **Fapshi (Sandbox):**
   - ✅ `FAPSHI_ENVIRONMENT=sandbox`
   - ✅ `FAPSHI_SANDBOX_API_USER`
   - ✅ `FAPSHI_SANDBOX_API_KEY`

3. **Fathom:**
   - ✅ `FATHOM_CLIENT_ID_DEV` or `FATHOM_CLIENT_ID_PROD`
   - ✅ `FATHOM_CLIENT_SECRET_DEV` or `FATHOM_CLIENT_SECRET_PROD`
   - ✅ `FATHOM_WEBHOOK_SECRET_DEV` or `FATHOM_WEBHOOK_SECRET_PROD`
   - ✅ `FATHOM_REDIRECT_URI_DEV=https://app.prepskul.com/auth/fathom/callback`

4. **Google Calendar:**
   - ✅ `GOOGLE_CALENDAR_CLIENT_ID`
   - ✅ `GOOGLE_CALENDAR_CLIENT_SECRET`
   - ✅ `GOOGLE_OAUTH_REDIRECT_URI_DEV=https://app.prepskul.com/auth/google/callback`

5. **Resend (Optional):**
   - ⚠️ `RESEND_API_KEY` (if you have it)
   - ✅ `RESEND_FROM_EMAIL=onboarding@resend.dev` (test domain)

---

## 🚀 **Quick Setup for Testing**

### **Step 1: Create .env File**

```bash
cd /Users/user/Desktop/PrepSkul/prepskul_app
cp env.template .env
```

### **Step 2: Verify All Values**

Open `.env` and confirm:
- ✅ All Supabase keys are filled
- ✅ Fapshi sandbox credentials are filled
- ✅ Fathom OAuth credentials are filled
- ✅ Google Calendar credentials are filled
- ✅ Redirect URIs point to `https://app.prepskul.com`

### **Step 3: For Next.js (PrepSkul_Web)**

```bash
cd /Users/user/Desktop/PrepSkul/PrepSkul_Web
cp ../prepskul_app/env.template .env.local
```

**Important:** Next.js uses `.env.local` (not `.env`)

### **Step 4: Set Environment Mode**

In `.env`:
```bash
ENVIRONMENT=development  # or 'production' for production testing
FAPSHI_ENVIRONMENT=sandbox  # Use sandbox for testing
```

---

## 🔍 **What to Test on app.prepskul.com**

### **✅ Can Test (Sandbox Mode):**

1. **Trial Session Booking:**
   - ✅ Create trial request
   - ✅ Initiate Fapshi payment (sandbox)
   - ✅ Payment webhook (test transaction)
   - ✅ Generate Google Meet link
   - ✅ Create Google Calendar event

2. **Fathom Integration:**
   - ✅ OAuth flow (redirects to app.prepskul.com)
   - ✅ Auto-join meetings
   - ✅ Webhook for recording ready
   - ⚠️ Need actual meeting to test recording

3. **Notifications:**
   - ✅ In-app notifications
   - ⚠️ Email notifications (uses test domain)

4. **Admin Features:**
   - ✅ Admin dashboard
   - ✅ Session monitoring
   - ✅ Flag management

### **❌ Cannot Test (Requires Live Mode):**

1. **Real Payments:**
   - ❌ Real Fapshi transactions (need live credentials)
   - ❌ Real money transfers

2. **Production Email:**
   - ❌ Verified domain emails (need domain verification)

---

## ⚙️ **Configuration for app.prepskul.com**

### **Flutter App (.env):**

```bash
# Environment
ENVIRONMENT=development  # or 'production'

# Base URLs
APP_BASE_URL_DEV=https://app.prepskul.com
WEB_BASE_URL_DEV=https://www.prepskul.com
API_BASE_URL_DEV=https://www.prepskul.com/api

# Fapshi (Sandbox for testing)
FAPSHI_ENVIRONMENT=sandbox
FAPSHI_SANDBOX_API_USER=4a148e87-e185-437d-a641-b465e2bd8d17
FAPSHI_SANDBOX_API_KEY=FAK_TEST_0293bda0f3ef142be85b

# Fathom (Use DEV credentials for testing)
FATHOM_CLIENT_ID_DEV=R93SgO5R3BkFnV5HkvVmKQJWLrxAzAaKSntj8UNY1-4
FATHOM_CLIENT_SECRET_DEV=UknZ9sfoSNy2otV59k4_z600ERuXmHjd7edlrMrPRXY
FATHOM_REDIRECT_URI_DEV=https://app.prepskul.com/auth/fathom/callback

# Google Calendar
GOOGLE_CALENDAR_CLIENT_ID=your-google-calendar-client-id-here
GOOGLE_CALENDAR_CLIENT_SECRET=your-google-calendar-client-secret-here
GOOGLE_OAUTH_REDIRECT_URI_DEV=https://app.prepskul.com/auth/google/callback
```

### **Next.js App (.env.local):**

Same values as Flutter app, but use `.env.local` file.

---

## 🔐 **OAuth Redirect URLs**

### **Must Match in Provider Dashboards:**

1. **Fathom Dashboard:**
   - Go to: https://app.fathom.video/
   - Settings → OAuth Apps
   - Redirect URI: `https://app.prepskul.com/auth/fathom/callback`

2. **Google Cloud Console:**
   - Go to: https://console.cloud.google.com/
   - APIs & Services → Credentials
   - OAuth 2.0 Client → Authorized redirect URIs
   - Add: `https://app.prepskul.com/auth/google/callback`

---

## ✅ **Pre-Deployment Checklist**

Before pushing to app.prepskul.com:

- [ ] `.env` file created from `env.template`
- [ ] All API keys filled in `.env`
- [ ] `.env.local` created in `PrepSkul_Web/`
- [ ] All API keys filled in `.env.local`
- [ ] Fathom redirect URI matches dashboard
- [ ] Google OAuth redirect URI matches console
- [ ] `FAPSHI_ENVIRONMENT=sandbox` for testing
- [ ] `ENVIRONMENT=development` for testing
- [ ] `.env` and `.env.local` in `.gitignore`
- [ ] Test locally first

---

## 🧪 **Testing Strategy**

### **Phase 1: Sandbox Testing (Recommended First)**

1. **Set to Sandbox:**
   ```bash
   FAPSHI_ENVIRONMENT=sandbox
   ENVIRONMENT=development
   ```

2. **Test Features:**
   - Trial booking flow
   - Payment initiation (sandbox)
   - Google Meet generation
   - Fathom OAuth flow

3. **Verify:**
   - No real money transactions
   - All webhooks work
   - OAuth redirects work

### **Phase 2: Production Testing (After Sandbox Works)**

1. **Switch to Live:**
   ```bash
   FAPSHI_ENVIRONMENT=live
   ENVIRONMENT=production
   ```

2. **Use Live Credentials:**
   - `FAPSHI_COLLECTION_API_KEY_LIVE`
   - `FAPSHI_DISBURSE_API_KEY_LIVE`
   - `FATHOM_CLIENT_ID_PROD`
   - `FATHOM_CLIENT_SECRET_PROD`

3. **Test with Real:**
   - Real payment transactions
   - Production webhooks
   - Live Fathom recordings

---

## 📝 **Summary**

### **✅ Ready for Testing on app.prepskul.com:**

- ✅ **Sandbox Mode:** All features work (no real money)
- ✅ **OAuth Flows:** Fathom and Google Calendar work
- ✅ **Webhooks:** Work on any domain
- ✅ **API Keys:** Work on any domain

### **⚠️ Notes:**

- Sandbox credentials work on production domain
- OAuth redirects must match configured URLs
- Email uses test domain (`onboarding@resend.dev`)
- For real payments, switch to live credentials

### **🚀 Next Steps:**

1. Create `.env` from `env.template`
2. Fill in all credentials
3. Verify redirect URIs match dashboards
4. Deploy to app.prepskul.com
5. Test in sandbox mode first
6. Switch to live mode when ready

---

**Last Updated:** January 25, 2025  
**Status:** ✅ Ready for Testing

