# Credentials Checklist - What You Have vs What You Need

## ✅ Credentials You Already Have

### Fapshi Payment API
- ✅ **Sandbox API User:** `[REDACTED - Get from Fapshi Dashboard]`
- ✅ **Sandbox API Key:** `[REDACTED - Get from Fapshi Dashboard]`
- ✅ **Live Collection API User:** `[REDACTED - Get from Fapshi Dashboard]`
- ✅ **Live Collection API Key:** `[REDACTED - Get from Fapshi Dashboard]`
- ✅ **Live Disburse API User:** `[REDACTED - Get from Fapshi Dashboard]`
- ✅ **Live Disburse API Key:** `[REDACTED - Get from Fapshi Dashboard]`

### Fathom AI
- ✅ **Dev Client ID:** `[REDACTED - Get from Fathom Dashboard]`
- ✅ **Dev Client Secret:** `[REDACTED - Get from Fathom Dashboard]`
- ✅ **Dev Webhook Secret:** `[REDACTED - Get from Fathom Dashboard]`
- ✅ **Prod Client ID:** `[REDACTED - Get from Fathom Dashboard]`
- ✅ **Prod Client Secret:** `[REDACTED - Get from Fathom Dashboard]`
- ✅ **Prod Webhook Secret:** `[REDACTED - Get from Fathom Dashboard]`

### Google Calendar API
- ✅ **OAuth Client ID:** `[REDACTED - Get from Google Cloud Console]`
- ✅ **Client Secret:** `[REDACTED - Get from Google Cloud Console]`
- ✅ **Project ID:** `prepskul-475900`
- ✅ **Project Number:** `[REDACTED - Get from Google Cloud Console]`

### PrepSkul Virtual Assistant
- ✅ **Email:** `[REDACTED - Use your VA email]`
- ✅ **Name:** PrepSkul Virtual Assistant

---

## ⚠️ Credentials You Need to Get

### 1. Google Calendar Client Secret ✅ COMPLETED

**How to Get:**
1. Go to [Google Cloud Console](https://console.cloud.google.com/)
2. Select project: **PrepSkul** (prepskul-475900)
3. Navigate to: **APIs & Services** → **Credentials**
4. Click on your OAuth 2.0 Client ID
5. You'll see the Client Secret (or click "Download JSON" button)
6. Copy the Client Secret value

**Where to Add:**
- Add to `.env` file as: `GOOGLE_CALENDAR_CLIENT_SECRET=your-secret-here`

### 2. Supabase Credentials ✅ COMPLETED

**Credentials Obtained:**
- ✅ **Project URL:** `[REDACTED - Get from Supabase Dashboard]`
- ✅ **Anon Key:** `[REDACTED - Get from Supabase Dashboard]`
- ✅ **Service Role Key:** `[REDACTED - Get from Supabase Dashboard]`

**Status:** ✅ Added to `env.template` file

### 3. Resend API Key (Optional - for emails)

**How to Get:**
1. Go to [Resend Dashboard](https://resend.com/)
2. Sign up or log in
3. Navigate to **API Keys**
4. Create new API key
5. Copy the key

**Where to Add:**
- Add to `.env` file as: `RESEND_API_KEY=your-key-here`
- Add to `.env.local` in Next.js app

---

## 📝 Next Steps

1. **Get Google Calendar Client Secret:** ✅ COMPLETED
   - [x] Go to Google Cloud Console
   - [x] Download OAuth client JSON or copy Client Secret
   - [x] Add to `env.template` file

2. **Get Supabase Credentials:** ✅ COMPLETED
   - [x] Go to Supabase Dashboard
   - [x] Copy Project URL and API keys
   - [x] Add to `env.template` file

3. **Create .env Files:**
   - [ ] Copy `.env.template` to `.env` in `prepskul_app/`
   - [ ] Copy `.env.template` to `.env.local` in `PrepSkul_Web/`
   - [ ] Fill in all values
   - [ ] Verify `.gitignore` includes `.env` files

4. **Verify Setup:**
   - [ ] All credentials added
   - [ ] No secrets committed to Git
   - [ ] Environment variables load correctly

---

## 🔒 Security Reminders

- ✅ Never commit `.env` files to Git
- ✅ Use `.env.template` as reference (safe to commit)
- ✅ Different keys for dev/prod
- ✅ Store production keys in Vercel/environment variables
- ✅ Rotate keys regularly

---

**Status:** Ready to collect remaining credentials




