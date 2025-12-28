# 🔧 Production Supabase Initialization Fix

## Problem

The error "Supabase is not initialized yet. Call Supabase.initialize() first." appears in production because:

1. **Environment Detection**: `AppConfig.isProduction = false` by default, so it looks for `SUPABASE_URL_DEV` instead of `SUPABASE_URL_PROD`
2. **Missing Environment Variables**: Environment variables aren't being injected into `window.env` during build
3. **Silent Failure**: The initialization error is caught and the app continues running, causing issues later

## Solution Implemented

### 1. **Auto-Detection for Web Production**
- Web release builds (`kReleaseMode`) now default to **production** mode
- Checks `window.env.ENVIRONMENT` first (highest priority)
- Falls back to `dotenv.env['ENVIRONMENT]`
- Finally uses `AppConfig.isProduction` flag

### 2. **Better Debugging**
- Added detailed logging to show:
  - Which environment is detected
  - Which variables are being looked for
  - Whether values were found
  - What was tried (dotenv vs window.env)

### 3. **Improved Error Messages**
- Error messages now specify exactly which variables are needed
- Shows current environment (production vs development)
- Provides clear instructions for fixing

## Required Setup for Production

### Step 1: Set Environment Variables in Vercel

Go to **Vercel Dashboard → Your Project → Settings → Environment Variables** and add:

```
SUPABASE_URL_PROD=your-production-supabase-url
SUPABASE_ANON_KEY_PROD=your-production-supabase-anon-key
ENVIRONMENT=production
```

### Step 2: Update Build Command

In **Vercel Dashboard → Settings → Build & Development Settings**, set:

**Build Command:**
```bash
node scripts/inject-env.js && flutter build web
```

**OR** add to `vercel.json`:
```json
{
  "buildCommand": "node scripts/inject-env.js && flutter build web"
}
```

### Step 3: Verify Build Script

Make sure `scripts/inject-env.js` exists and is executable:
```bash
chmod +x scripts/inject-env.js
```

## How It Works Now

1. **Build Time:**
   - `scripts/inject-env.js` reads environment variables from Vercel
   - Injects them into `web/index.html` as `window.env`

2. **Runtime:**
   - App checks `window.env.ENVIRONMENT` first
   - If production, looks for `SUPABASE_URL_PROD` and `SUPABASE_ANON_KEY_PROD`
   - If development, looks for `SUPABASE_URL_DEV` and `SUPABASE_ANON_KEY_DEV`
   - Falls back to `dotenv` if `window.env` not available
   - Initializes Supabase with found credentials

3. **Error Handling:**
   - If credentials missing, throws clear error with instructions
   - Logs detailed debugging info in console
   - Shows which environment and variables were checked

## Verification

After deploying, check browser console for:

✅ **Success:**
```
🔍 Supabase Config Check:
   Environment: production
   isProd: true
   URL key: SUPABASE_URL_PROD
   Anon key: SUPABASE_ANON_KEY_PROD
   URL found: true
   Anon key found: true
✅ Supabase initialized (production)
```

❌ **Failure:**
```
❌ Supabase credentials not found
   Environment: production
   Looking for: PROD credentials
Tried: 1) assets/.env file, 2) window.env
```

## Quick Fix Checklist

- [ ] Set `SUPABASE_URL_PROD` in Vercel environment variables
- [ ] Set `SUPABASE_ANON_KEY_PROD` in Vercel environment variables  
- [ ] Set `ENVIRONMENT=production` in Vercel environment variables
- [ ] Update build command to run `node scripts/inject-env.js`
- [ ] Redeploy and check browser console
- [ ] Verify Supabase initializes successfully

## Alternative: Manual Injection

If you can't modify the build command, manually edit `web/index.html` before building:

```html
<script>
  window.env = window.env || {};
  window.env.ENVIRONMENT = 'production';
  window.env.SUPABASE_URL_PROD = 'your-supabase-url';
  window.env.SUPABASE_ANON_KEY_PROD = 'your-supabase-anon-key';
</script>
```

⚠️ **Warning:** Never commit this file with real credentials to Git!

## Troubleshooting

### Still seeing "Supabase is not initialized yet"

1. **Check browser console** for the detailed error message
2. **Verify environment variables** are set in Vercel
3. **Check build logs** to see if `inject-env.js` ran
4. **Inspect `index.html`** in the built output for `window.env` values
5. **Verify `ENVIRONMENT=production`** is set (or web release will auto-detect)

### Wrong environment detected

- Check `window.env.ENVIRONMENT` value in `index.html`
- Verify it's set to `"production"` (not `"prod"` or `"PRODUCTION"`)
- Or rely on auto-detection (web release = production)

### Variables not found

- Check variable names match exactly: `SUPABASE_URL_PROD` (not `SUPABASE_URL`)
- Verify they're set for the correct environment (Production, not Preview/Development)
- Check build script is actually running and injecting values

