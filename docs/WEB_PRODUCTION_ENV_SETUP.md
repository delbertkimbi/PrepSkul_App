# 🌐 Web Production Environment Variables Setup

## Problem

For Flutter web production builds, `.env` files are not reliably bundled. The app needs environment variables (especially Supabase credentials) to initialize properly.

## Solution

We've implemented a fallback mechanism that reads from `window.env` (JavaScript) when `.env` files aren't available. This works for production builds on platforms like Vercel.

---

## 🔧 Setup Instructions

### Option 1: Vercel Environment Variables (Recommended)

1. **Set Environment Variables in Vercel Dashboard:**
   - Go to your Vercel project → Settings → Environment Variables
   - Add these variables:
     ```
     SUPABASE_URL_PROD=your-production-supabase-url
     SUPABASE_ANON_KEY_PROD=your-production-supabase-anon-key
     SUPABASE_URL_DEV=your-dev-supabase-url (optional)
     SUPABASE_ANON_KEY_DEV=your-dev-supabase-anon-key (optional)
     ENVIRONMENT=production (or development)
     ```

2. **Update Vercel Build Command:**
   - In Vercel project settings → Build & Development Settings
   - Update the build command to:
     ```bash
     node scripts/inject-env.js && flutter build web
     ```
   - Or add a `vercel.json` with:
     ```json
     {
       "buildCommand": "node scripts/inject-env.js && flutter build web"
     }
     ```

3. **Deploy:**
   - The script will automatically inject environment variables into `index.html` during build
   - The Flutter app will read them from `window.env` at runtime

---

### Option 2: Manual Injection (For Testing)

If you need to test locally or don't have access to build scripts:

1. **Edit `web/index.html` directly:**
   ```html
   <script>
     window.env = window.env || {};
     window.env.SUPABASE_URL_PROD = 'your-supabase-url';
     window.env.SUPABASE_ANON_KEY_PROD = 'your-supabase-anon-key';
     // ... other variables
   </script>
   ```

2. **Build:**
   ```bash
   flutter build web
   ```

**⚠️ Warning:** Never commit actual credentials to Git! Use environment variables or build scripts.

---

### Option 3: Build-Time Injection (CI/CD)

For custom CI/CD pipelines:

1. **Create a build script** (already provided: `scripts/inject-env.js`)

2. **Set environment variables** in your CI/CD platform

3. **Run before build:**
   ```bash
   export SUPABASE_URL_PROD="your-url"
   export SUPABASE_ANON_KEY_PROD="your-key"
   node scripts/inject-env.js
   flutter build web
   ```

---

## 🔍 How It Works

1. **AppConfig reads environment variables in this order:**
   - First: `dotenv.env` (from `assets/.env` file)
   - Second: `window.env` (from JavaScript, web only)
   - Third: Fallback value (usually empty string)

2. **The `_safeEnv()` method in `AppConfig`:**
   ```dart
   static String _safeEnv(String key, String fallback) {
     // Try dotenv first
     // Then try window.env (web only)
     // Finally use fallback
   }
   ```

3. **If credentials are missing:**
   - The app will throw a clear error message
   - Error message includes instructions for fixing

---

## ✅ Verification

After deployment, check the browser console:

1. **Open browser DevTools → Console**
2. **Look for:**
   ```
   ✅ Environment variables loaded from assets/.env
   OR
   ⚠️ Environment variables not loaded - trying window.env
   ✅ Supabase initialized (production)
   ```

3. **If you see errors:**
   ```
   ❌ Supabase credentials not found
   Tried: 1) assets/.env file, 2) window.env
   ```
   → Environment variables are not set correctly

---

## 🐛 Troubleshooting

### Error: "Supabase is not initialized yet"

**Cause:** Environment variables not found in either `.env` or `window.env`

**Fix:**
1. Check Vercel environment variables are set
2. Verify build script runs: `node scripts/inject-env.js`
3. Check `index.html` contains `window.env` with values
4. Verify `AppConfig.isProduction` matches your environment

### Error: "Invalid login credentials" (but works locally)

**Cause:** Using wrong Supabase project (dev vs prod)

**Fix:**
1. Check `AppConfig.isProduction` flag in `app_config.dart`
2. Verify `ENVIRONMENT` variable matches (production vs development)
3. Ensure correct Supabase credentials for the environment

### Environment variables not injected

**Cause:** Build script not running or environment variables not set

**Fix:**
1. Check Vercel build logs for script execution
2. Verify environment variables are set in Vercel Dashboard
3. Manually check `index.html` in build output for `window.env`

---

## 📝 Required Environment Variables

### Production
- `SUPABASE_URL_PROD` - Production Supabase project URL
- `SUPABASE_ANON_KEY_PROD` - Production Supabase anon key
- `ENVIRONMENT=production` (optional, can use `AppConfig.isProduction`)

### Development (Optional)
- `SUPABASE_URL_DEV` - Development Supabase project URL
- `SUPABASE_ANON_KEY_DEV` - Development Supabase anon key
- `ENVIRONMENT=development` (optional)

---

## 🔐 Security Notes

1. **Never commit `.env` files** with real credentials
2. **Never commit `index.html`** with injected credentials
3. **Use environment variables** in CI/CD platforms
4. **Use different projects** for dev/prod if possible
5. **Rotate keys** if accidentally exposed

---

## 📚 Related Files

- `lib/core/config/app_config.dart` - Main configuration class
- `lib/core/config/web_env_helper.dart` - Web environment variable reader
- `lib/main.dart` - App initialization and Supabase setup
- `web/index.html` - HTML file where `window.env` is injected
- `scripts/inject-env.js` - Build script to inject environment variables

