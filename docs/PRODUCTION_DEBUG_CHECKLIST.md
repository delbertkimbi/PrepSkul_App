# Production Debug Checklist

## Current Status
- ✅ Supabase URL: `https://cpzaxdfxbamdsshdgjyg.supabase.co`
- ✅ Project is active (works locally)
- ✅ Root `.env` has credentials
- ✅ `assets/.env` has credentials
- ✅ `assets/.env` listed in `pubspec.yaml`
- ✅ Supabase Redirect URLs configured (including `https://operating-axis-420213.web.app/**`)
- ❌ Production web app shows "Connection error"

## Root Cause Analysis

The "Connection error" occurs when Supabase returns HTML instead of JSON. This happens when:

1. **CORS Issue** - Domain not in allowed origins ✅ (Already fixed - redirect URLs configured)
2. **Wrong Supabase URL** - URL doesn't match project
3. **Credentials Not Loaded** - `assets/.env` not bundled or not loading
4. **Wrong Environment Variable** - `ENVIRONMENT` not set to `production`

## Verification Steps

### Step 1: Verify `assets/.env` Content

Open `prepskul_app/assets/.env` and verify it contains:

```env
ENVIRONMENT=production
SUPABASE_URL_PROD=https://cpzaxdfxbamdsshdgjyg.supabase.co
SUPABASE_ANON_KEY_PROD=your-actual-anon-key-here
```

**Important:** The anon key must be the actual key, not a placeholder.

### Step 2: Check Browser Console in Production

After deploying, open `https://operating-axis-420213.web.app` and check the browser console for:

```
🔍 [PRODUCTION] Supabase Configuration:
   URL: https://cpzaxdfxbamdsshdgjyg.supabase.co...
   Key: eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...
   Environment: production
   Is Production: true
   ENVIRONMENT var: production
   SUPABASE_URL_PROD: ✅ SET
   SUPABASE_ANON_KEY_PROD: ✅ SET
```

If you see:
- `❌ EMPTY` for URL or Key → Credentials not loading
- `ENVIRONMENT var: NOT SET` → `ENVIRONMENT` not set in `assets/.env`
- `SUPABASE_URL_PROD: ❌ NOT SET` → Variable name mismatch

### Step 3: Check Login Attempt Logs

When you try to login, check console for:

```
🔍 [LOGIN] Attempting login with Supabase URL: https://cpzaxdfxbamdsshdgjyg.supabase.co
```

If this shows a different URL or is empty, credentials aren't loading correctly.

### Step 4: Check Error Logs

If login fails, look for:

```
🚨 [ERROR] HTML response detected - Supabase returned HTML instead of JSON
🚨 [ERROR] Current Supabase URL: ...
🚨 [ERROR] Expected: https://cpzaxdfxbamdsshdgjyg.supabase.co
```

This will tell you:
- What URL is actually being used
- Whether it matches the expected URL

## Common Issues & Fixes

### Issue 1: Credentials Not Loading

**Symptoms:**
- Console shows `❌ EMPTY` for URL or Key
- `SUPABASE_URL_PROD: ❌ NOT SET`

**Fix:**
1. Verify `assets/.env` exists and has correct content
2. Verify `pubspec.yaml` has `- assets/.env` in assets section
3. Rebuild: `flutter build web --release`
4. Redeploy: `firebase deploy`

### Issue 2: Wrong Environment Variable

**Symptoms:**
- `ENVIRONMENT var: NOT SET` or `ENVIRONMENT var: development`
- App thinks it's in development mode

**Fix:**
1. Open `assets/.env`
2. Set `ENVIRONMENT=production` (not `development`)
3. Rebuild and redeploy

### Issue 3: Variable Name Mismatch

**Symptoms:**
- `SUPABASE_URL_PROD: ❌ NOT SET` but you have it in `.env`

**Fix:**
1. Check exact variable names in `assets/.env`:
   - Must be `SUPABASE_URL_PROD` (not `SUPABASE_URL`)
   - Must be `SUPABASE_ANON_KEY_PROD` (not `SUPABASE_ANON_KEY`)
2. No spaces around `=`: `SUPABASE_URL_PROD=https://...`
3. No quotes needed: `SUPABASE_URL_PROD="https://..."` is wrong

### Issue 4: CORS Still Failing

**Symptoms:**
- Console shows correct URL and key
- Still getting HTML response error
- Error mentions CORS

**Fix:**
1. Go to Supabase Dashboard → Authentication → URL Configuration
2. Verify `https://operating-axis-420213.web.app/**` is in Redirect URLs
3. Verify `https://operating-axis-420213.web.app` is in Site URL (or allowed)
4. Save changes
5. Wait 1-2 minutes for changes to propagate
6. Try again

## Next Steps

1. **Rebuild and redeploy** with the diagnostic logging we added
2. **Open production app** in browser
3. **Open browser console** (F12 or Cmd+Option+I)
4. **Look for the diagnostic logs** listed above
5. **Share the console output** so we can identify the exact issue

The diagnostic logs will tell us exactly what's wrong:
- Are credentials loading? (Check `🔍 [PRODUCTION]` logs)
- What URL is being used? (Check `🔍 [LOGIN]` logs)
- What's the actual error? (Check `🚨 [ERROR]` logs)

