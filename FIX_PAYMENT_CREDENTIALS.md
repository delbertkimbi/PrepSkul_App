# Fix: Payment Failure - Missing Fapshi API Credentials

## Problem

The browser console shows:
```
❌ [WINDOW_ENV] Error reading window.env.FAPSHI_COLLECTION_API_USER_LIVE: NoSuchMethodError: method not found: '[]'
❌ Fapshi API credentials are missing. Check your .env file.
```

**Root Cause:** The Fapshi API credentials are not injected into `web/index.html` because they weren't set when `inject-env.js` ran.

## Solution

You need to set the environment variables **before** running `inject-env.js`, then rebuild.

### Step 1: Set Environment Variables

**In PowerShell (Windows):**
```powershell
# Set Fapshi production credentials
$env:FAPSHI_COLLECTION_API_USER_LIVE="your-actual-live-api-user"
$env:FAPSHI_COLLECTION_API_KEY_LIVE="your-actual-live-api-key"

# Also set Supabase vars (if not already set)
$env:SUPABASE_URL_PROD="your-supabase-url"
$env:SUPABASE_ANON_KEY_PROD="your-supabase-anon-key"
```

**Or create a `.env` file** in the project root (if you're using dotenv):
```env
FAPSHI_COLLECTION_API_USER_LIVE=your-actual-live-api-user
FAPSHI_COLLECTION_API_KEY_LIVE=your-actual-live-api-key
SUPABASE_URL_PROD=your-supabase-url
SUPABASE_ANON_KEY_PROD=your-supabase-anon-key
```

### Step 2: Run inject-env.js

```powershell
node scripts/inject-env.js
```

**Expected output:**
```
✅ Environment variables injected into index.html
   Variables set: FAPSHI_COLLECTION_API_USER_LIVE, FAPSHI_COLLECTION_API_KEY_LIVE, SUPABASE_URL_PROD, SUPABASE_ANON_KEY_PROD, ENVIRONMENT
```

### Step 3: Verify index.html

Check that `web/index.html` now contains:
```javascript
window.env.FAPSHI_COLLECTION_API_USER_LIVE = "your-actual-live-api-user";
window.env.FAPSHI_COLLECTION_API_KEY_LIVE = "your-actual-live-api-key";
```

### Step 4: Rebuild Flutter Web

```powershell
flutter build web
```

### Step 5: Deploy

Deploy the new build to your hosting (Vercel, etc.).

## Important Notes

### Vercel Environment Variables vs Flutter Build

⚠️ **Vercel env vars are for the Next.js backend, NOT for Flutter web builds.**

- **Vercel env vars** → Used by Next.js backend API routes
- **Flutter web build** → Needs env vars set **locally** (or in CI) when running `inject-env.js`

### For CI/CD (Vercel Build)

If you're building Flutter web in Vercel, add these to your **Vercel project settings** → **Environment Variables**:

```
FAPSHI_COLLECTION_API_USER_LIVE=your-value
FAPSHI_COLLECTION_API_KEY_LIVE=your-value
SUPABASE_URL_PROD=your-value
SUPABASE_ANON_KEY_PROD=your-value
```

Then update your **Vercel build command** to run `inject-env.js` before `flutter build web`:

```json
{
  "buildCommand": "node scripts/inject-env.js && flutter build web"
}
```

### For Local Development

1. Set env vars in PowerShell (as shown above)
2. Run `node scripts/inject-env.js`
3. Run `flutter build web` or `flutter run -d chrome`

## Verification

After rebuilding, check the browser console. You should see:
```
✅ [WINDOW_ENV] Found FAPSHI_COLLECTION_API_USER_LIVE via direct eval
✅ [WINDOW_ENV] Found FAPSHI_COLLECTION_API_KEY_LIVE via direct eval
🔑 API User: abc... (not "EMPTY")
```

Instead of:
```
❌ [WINDOW_ENV] Error reading window.env.FAPSHI_COLLECTION_API_USER_LIVE
❌ Fapshi API credentials are missing
```

## Quick Fix Script

Create a file `build-with-env.ps1`:

```powershell
# Set your credentials here
$env:FAPSHI_COLLECTION_API_USER_LIVE="your-actual-live-api-user"
$env:FAPSHI_COLLECTION_API_KEY_LIVE="your-actual-live-api-key"
$env:SUPABASE_URL_PROD="your-supabase-url"
$env:SUPABASE_ANON_KEY_PROD="your-supabase-anon-key"

# Inject and build
Write-Host "Injecting environment variables..." -ForegroundColor Cyan
node scripts/inject-env.js

Write-Host "Building Flutter web..." -ForegroundColor Cyan
flutter build web

Write-Host "✅ Build complete!" -ForegroundColor Green
```

Then run:
```powershell
.\build-with-env.ps1
```

## Still Having Issues?

1. **Check `web/index.html`** - Do you see `window.env.FAPSHI_COLLECTION_API_USER_LIVE`?
2. **Check browser console** - Are the credentials being read?
3. **Verify credentials** - Are they correct in your Fapshi dashboard?
4. **Check production mode** - Is `AppConfig.isProduction = true`?
