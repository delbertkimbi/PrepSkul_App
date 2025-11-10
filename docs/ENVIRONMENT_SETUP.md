# Environment Variables Setup Guide

## Overview

This guide explains how to securely store and manage all API keys and credentials for PrepSkul across different environments.

---

## File Structure

```
prepskul_app/
├── .env                    # Flutter app environment (DO NOT COMMIT)
├── .env.template           # Template file (safe to commit)
├── .gitignore             # Should include .env
│
PrepSkul_Web/
├── .env.local             # Next.js local environment (DO NOT COMMIT)
├── .env.example           # Example file (safe to commit)
└── .gitignore             # Should include .env.local
```

---

## Quick Setup

### 1. Flutter App (prepskul_app)

```bash
# Copy template
cp .env.template .env

# Edit with your values
nano .env  # or use your preferred editor
```

### 2. Next.js Web App (PrepSkul_Web)

```bash
cd PrepSkul_Web

# Copy template
cp .env.template .env.local

# Edit with your values
nano .env.local
```

### 3. Verify .gitignore

Ensure these files are in `.gitignore`:

```
# Environment variables
.env
.env.local
.env.*.local
*.env
```

---

## Required Credentials

### ✅ Already Obtained

1. **Fapshi:**
   - ✅ Sandbox credentials
   - ✅ Live credentials (Collection & Disburse)

2. **Fathom:**
   - ✅ Development OAuth credentials
   - ✅ Production OAuth credentials
   - ✅ Webhook secrets

3. **Google Calendar:**
   - ✅ OAuth Client ID: `330494350717-9ebevvvo8k6f0te9662n6np60oaeub6o.apps.googleusercontent.com`
   - ⚠️ Need: Client Secret (download from Google Cloud Console)

4. **Supabase:**
   - ⚠️ Need: Project URL and API keys

---

## Missing Credentials to Obtain

### 1. Google Calendar Client Secret

**Steps:**
1. Go to [Google Cloud Console](https://console.cloud.google.com/)
2. Select project: **PrepSkul** (prepskul-475900)
3. Navigate to: **APIs & Services** → **Credentials**
4. Find your OAuth 2.0 Client ID
5. Click to view details
6. Copy the **Client Secret**
7. Add to `.env` file

**Or download JSON:**
1. Click "Download JSON" button
2. File contains both Client ID and Client Secret
3. Extract and add to `.env`

### 2. Supabase Credentials

**Steps:**
1. Go to [Supabase Dashboard](https://app.supabase.com/)
2. Select your project
3. Go to: **Settings** → **API**
4. Copy:
   - **Project URL** → `SUPABASE_URL_DEV` or `SUPABASE_URL_PROD`
   - **anon/public key** → `SUPABASE_ANON_KEY_DEV` or `SUPABASE_ANON_KEY_PROD`
   - **service_role key** → `SUPABASE_SERVICE_ROLE_KEY_DEV` or `SUPABASE_SERVICE_ROLE_KEY_PROD`

**Note:** Use different projects for dev/prod, or same project with different keys.

### 3. Resend API Key (Email Service)

**Steps:**
1. Go to [Resend Dashboard](https://resend.com/)
2. Navigate to **API Keys**
3. Create new API key
4. Copy and add to `.env` as `RESEND_API_KEY`

---

## Environment-Specific Configuration

### Development

Use sandbox/test credentials:
- `FAPSHI_ENVIRONMENT=sandbox`
- `FATHOM_CLIENT_ID_DEV=...`
- `SUPABASE_URL_DEV=...`
- `ENVIRONMENT=development`

### Production

Use live credentials:
- `FAPSHI_ENVIRONMENT=live`
- `FATHOM_CLIENT_ID_PROD=...`
- `SUPABASE_URL_PROD=...`
- `ENVIRONMENT=production`

---

## Loading Environment Variables

### Flutter App

**Option 1: Using `flutter_dotenv` package**

1. Add to `pubspec.yaml`:
```yaml
dependencies:
  flutter_dotenv: ^5.1.0
```

2. Load in code:
```dart
import 'package:flutter_dotenv/flutter_dotenv.dart';

await dotenv.load(fileName: ".env");

final supabaseUrl = dotenv.env['SUPABASE_URL_DEV']!;
final fapshiApiKey = dotenv.env['FAPSHI_SANDBOX_API_KEY']!;
```

**Option 2: Using `--dart-define` (Recommended for production)**

```bash
flutter run --dart-define=SUPABASE_URL=$SUPABASE_URL --dart-define=API_KEY=$API_KEY
```

### Next.js Web App

Next.js automatically loads `.env.local`:

```typescript
// Access in code
const supabaseUrl = process.env.SUPABASE_URL_DEV!;
const fapshiApiKey = process.env.FAPSHI_SANDBOX_API_KEY!;
```

---

## Vercel Deployment (Production)

For production, set environment variables in Vercel:

1. Go to Vercel Dashboard
2. Select your project
3. Go to **Settings** → **Environment Variables**
4. Add all production variables:
   - `SUPABASE_URL_PROD`
   - `FAPSHI_COLLECTION_API_KEY_LIVE`
   - `FATHOM_CLIENT_ID_PROD`
   - `GOOGLE_CALENDAR_CLIENT_ID`
   - etc.

**Important:** Never commit production keys to Git!

---

## Security Best Practices

### ✅ DO:
- ✅ Use `.env.template` as reference (safe to commit)
- ✅ Add `.env` to `.gitignore`
- ✅ Use different keys for dev/prod
- ✅ Rotate keys regularly
- ✅ Store production keys in secure vaults
- ✅ Use environment-specific files (`.env.dev`, `.env.prod`)

### ❌ DON'T:
- ❌ Commit `.env` files to Git
- ❌ Share keys in chat/email
- ❌ Use production keys in development
- ❌ Hardcode keys in source code
- ❌ Store keys in client-side code (Flutter web)

---

## Current Status

### ✅ Completed:
- [x] Fapshi credentials (dev & prod)
- [x] Fathom OAuth credentials (dev & prod)
- [x] Google Calendar Client ID
- [x] Environment template created

### ⚠️ Need to Obtain:
- [ ] Google Calendar Client Secret
- [ ] Supabase credentials (dev & prod)
- [ ] Resend API key (optional, for emails)

---

## Next Steps

1. **Get Google Calendar Client Secret:**
   - Download JSON from Google Cloud Console
   - Extract Client Secret
   - Add to `.env` file

2. **Get Supabase Credentials:**
   - Copy from Supabase dashboard
   - Add to `.env` file

3. **Create `.env` files:**
   - Copy `.env.template` to `.env`
   - Fill in all values
   - Verify `.gitignore` includes `.env`

4. **Test Configuration:**
   - Verify all keys load correctly
   - Test API connections
   - Check environment detection

---

**Last Updated:** January 2025  
**Status:** Ready for Credential Setup

