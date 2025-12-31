# Diagnose "Connection Error" in Production

## Where the Error Comes From

The error message **"Connection error. Please check your internet connection and try again. If the problem persists, contact support."** comes from:

**File:** `lib/core/services/auth_service.dart` (line 629)

**Triggered when:**
- Supabase returns HTML instead of JSON
- Error contains `<!DOCTYPE` or `FormatException: SyntaxError: Unexpected token '<'`
- This means the authentication request was blocked or redirected

## Why It Happens

This error occurs when:

1. **CORS Issue (Most Common)**
   - Production domain not in Supabase Authentication → URL Configuration
   - Domain: `https://operating-axis-420213.web.app` or `https://app.prepskul.com`
   - **Fix:** Add domain to Supabase Dashboard → Authentication → URL Configuration → Redirect URLs

2. **Wrong Supabase URL**
   - `assets/.env` has incorrect `SUPABASE_URL_PROD`
   - URL doesn't match your actual Supabase project
   - **Fix:** Verify URL in Supabase Dashboard → Settings → API

3. **Credentials Not Loaded**
   - `assets/.env` not bundled with production build
   - File not listed in `pubspec.yaml`
   - **Fix:** Ensure `assets/.env` exists and is in `pubspec.yaml` assets section

4. **Supabase Project Issues**
   - Project paused (free tier inactivity)
   - Project deleted
   - **Fix:** Check Supabase Dashboard project status

## When It Happens

- **During login attempts** (`email_login_screen.dart`)
- **During signup attempts** (`email_signup_screen.dart`)
- **During password reset** (`forgot_password_screen.dart`)
- **Any Supabase auth operation** that makes a network request

## How to Diagnose

### Step 1: Check Browser Console

After attempting login, check browser console for:

```
🚨 [ERROR] HTML response detected - Supabase returned HTML instead of JSON
🚨 [ERROR] Current Supabase URL: https://...
🚨 [ERROR] Expected: https://cpzaxdfxbamdsshdgjyg.supabase.co
```

### Step 2: Check Production Logs

Look for these logs in production:

```
🔍 [PRODUCTION] Supabase Configuration:
   URL: https://cpzaxdfxbamdsshdgjyg.supabase.co...
   Key: eyJhbGciOiJIUzI1NiIsInR5cCI6...
   SUPABASE_URL_PROD: ✅ SET
   SUPABASE_ANON_KEY_PROD: ✅ SET
```

If you see `❌ EMPTY` or `❌ NOT SET`, credentials aren't loading.

### Step 3: Verify Supabase Configuration

1. Go to [Supabase Dashboard](https://app.supabase.com)
2. Check Authentication → URL Configuration
3. Verify your production domain is listed
4. Check Settings → API for correct URL

### Step 4: Verify assets/.env

1. Open `prepskul_app/assets/.env`
2. Verify:
   ```env
   ENVIRONMENT=production
   SUPABASE_URL_PROD=https://cpzaxdfxbamdsshdgjyg.supabase.co
   SUPABASE_ANON_KEY_PROD=your-actual-key
   ```
3. Check `pubspec.yaml` has `assets/.env` listed

## Quick Fix Checklist

- [ ] Production domain added to Supabase Authentication → URL Configuration
- [ ] `assets/.env` has correct `SUPABASE_URL_PROD`
- [ ] `assets/.env` has correct `SUPABASE_ANON_KEY_PROD`
- [ ] `assets/.env` listed in `pubspec.yaml`
- [ ] Rebuilt with `flutter build web --release`
- [ ] Redeployed to Firebase
- [ ] Checked browser console for diagnostic logs

## Still Not Working?

1. **Check browser console** for the diagnostic logs we added
2. **Verify Supabase project is active** (not paused)
3. **Test with a different browser** (rule out browser cache)
4. **Clear browser cache** and hard refresh (Ctrl+Shift+R / Cmd+Shift+R)
5. **Check network tab** in DevTools to see the actual request/response

