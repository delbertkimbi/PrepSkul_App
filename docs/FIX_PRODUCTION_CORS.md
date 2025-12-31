# Fix Production CORS Error

## Problem
Production app at `https://operating-axis-420213.web.app` is getting:
```
FormatException: SyntaxError: Unexpected token '<', "<!DOCTYPE "... is not valid JSON
```

This means Supabase is returning HTML instead of JSON. This can happen due to:
1. **CORS/URL Configuration** - Domain not in allowed redirect URLs (if URLs were already added, skip this)
2. **Missing Credentials** - `assets/.env` not loading in production build
3. **Wrong Supabase URL** - Incorrect URL in `assets/.env`
4. **Supabase Project Paused** - Project might be paused or deleted

## Solution

### Step 1: Add Production Domain to Supabase Authentication Settings

**Important:** Supabase doesn't have a separate CORS setting. Instead, configure allowed origins through Authentication URL Configuration.

1. Go to [Supabase Dashboard](https://app.supabase.com)
2. Select your project
3. Go to **Settings** → **Authentication** (or click "Authentication" in the left sidebar)
4. Scroll to **URL Configuration** section
5. Add these domains to **"Redirect URLs"**:
   ```
   https://operating-axis-420213.web.app
   https://operating-axis-420213.web.app/**
   https://operating-axis-420213.firebaseapp.com
   https://operating-axis-420213.firebaseapp.com/**
   https://app.prepskul.com
   https://app.prepskul.com/**
   https://www.prepskul.com
   https://www.prepskul.com/**
   ```
6. Set **"Site URL"** to:
   ```
   https://operating-axis-420213.web.app
   ```
7. Click **Save**

### Step 2: Verify assets/.env Has Production Credentials

**CRITICAL:** Check that `assets/.env` exists and contains production credentials:

1. Open `prepskul_app/assets/.env`
2. Verify it contains:
   ```env
   ENVIRONMENT=production
   SUPABASE_URL_PROD=https://cpzaxdfxbamdsshdgjyg.supabase.co
   SUPABASE_ANON_KEY_PROD=your-actual-production-anon-key
   ```
3. **Important:** Make sure there are NO spaces around the `=` sign
4. **Important:** Make sure the values are NOT wrapped in quotes
5. Verify the file is listed in `pubspec.yaml` under `assets:`

### Step 2b: Check Browser Console Logs

After deploying, check the browser console for:
- `🔍 [PRODUCTION] Supabase Configuration:` logs
- Look for `❌ EMPTY` or `❌ NOT SET` indicators
- This will tell you if credentials are loading correctly

### Step 3: Rebuild and Redeploy

```bash
cd prepskul_app
flutter build web --release
firebase deploy
```

### Step 4: Verify in Browser Console

After deployment, check browser console for:
- ✅ `[PRODUCTION] Supabase Configuration:` logs showing correct URL
- ✅ No CORS errors
- ✅ Successful authentication

## Additional Notes

- **Supabase REST API CORS:** Supabase's REST API (PostgREST) automatically handles CORS, but authentication endpoints require URL configuration
- **No Separate CORS Setting:** As of 2025, Supabase doesn't have a dashboard CORS setting - use Authentication → URL Configuration instead
- The app now logs Supabase configuration in production builds
- HTML response errors are now caught and show user-friendly messages
- Check browser console for detailed diagnostic logs

## Alternative: If Still Getting CORS Errors

If you're still getting CORS errors after configuring URLs, the issue might be:
1. **Browser cache** - Clear browser cache and hard refresh (Ctrl+Shift+R / Cmd+Shift+R)
2. **Service worker** - Unregister service workers in DevTools → Application → Service Workers
3. **Wrong Supabase URL** - Verify `assets/.env` has the correct `SUPABASE_URL_PROD`

