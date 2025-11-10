# Credentials Checklist - What You Have vs What You Need

## ✅ Credentials You Already Have

### Fapshi Payment API
- ✅ **Sandbox API User:** `4a148e87-e185-437d-a641-b465e2bd8d17`
- ✅ **Sandbox API Key:** `FAK_TEST_0293bda0f3ef142be85b`
- ✅ **Live Collection API User:** `54652088-94b9-4642-8d04-fdab02beb71d`
- ✅ **Live Collection API Key:** `FAK_9194147b613e1fc4ba03237bb6640241`
- ✅ **Live Disburse API User:** `f4eec807-8e00-4edb-9bca-2cebe302cde0`
- ✅ **Live Disburse API Key:** `FAK_fa3eef96f98e9ec6b6c004d2cea6eeb2`

### Fathom AI
- ✅ **Dev Client ID:** `R93SgO5R3BkFnV5HkvVmKQJWLrxAzAaKSntj8UNY1-4`
- ✅ **Dev Client Secret:** `UknZ9sfoSNy2otV59k4_z600ERuXmHjd7edlrMrPRXY`
- ✅ **Dev Webhook Secret:** `whsec_zr7u8JUmfHY9VFtKyFRen23MbulcFKjb`
- ✅ **Prod Client ID:** `o4W2hmB98DMRdPN7leYaf9kfOZ0nAq9rkolg41JEbZY`
- ✅ **Prod Client Secret:** `acgbMHXLjRgD280UxS3m1_ZBRdghC8sN1fS7oECd6zw`
- ✅ **Prod Webhook Secret:** `whsec_NJJSHL4KKraedQj8/CeGUSkwsehYEVxd`

### Google Calendar API
- ✅ **OAuth Client ID:** `[REDACTED - Get from Google Cloud Console]`
- ✅ **Client Secret:** `[REDACTED - Get from Google Cloud Console]`
- ✅ **Project ID:** `prepskul-475900`
- ✅ **Project Number:** `330494350717`

### PrepSkul Virtual Assistant
- ✅ **Email:** `deltechhub237@gmail.com`
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
- ✅ **Project URL:** `https://cpzaxdfxbamdsshdgjyg.supabase.co`
- ✅ **Anon Key:** `eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImNwemF4ZGZ4YmFtZHNzaGRnanlnIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjE1MDUwMDYsImV4cCI6MjA3NzA4MTAwNn0.FWBFrseEeYqFaJ7FGRUAYtm10sz0JqPyerJ0BfoYnCU`
- ✅ **Service Role Key:** `eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImNwemF4ZGZ4YmFtZHNzaGRnanlnIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc2MTUwNTAwNiwiZXhwIjoyMDc3MDgxMDA2fQ.OssueeFlLBeAsaneOojmdoONWNMI2yUp3oTjpcK9Cjc`

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

