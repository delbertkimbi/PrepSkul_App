# 🚀 Agora Video Session - Production Deployment Readiness Checklist

## ✅ Pre-Deployment Verification

### 1. Environment Variables Configuration

#### Flutter App (`.env` file in root)
- [x] `API_BASE_URL_PROD=https://www.prepskul.com/api` ✅ (Correct - Next.js API domain)
- [x] `API_BASE_URL_DEV=https://www.prepskul.com/api` ✅ (Correct)
- [x] `APP_BASE_URL_PROD=https://app.prepskul.com` ✅ (Correct - Flutter app domain)
- [x] `SUPABASE_URL_PROD` - Set to your Supabase project URL
- [x] `SUPABASE_ANON_KEY_PROD` - Set to your Supabase anon key

#### Next.js App (`.env.local` in PrepSkul_Web directory)
- [ ] `AGORA_APP_ID` - **REQUIRED** - Your Agora App ID
- [ ] `AGORA_APP_CERTIFICATE` - **REQUIRED** - Your Agora App Certificate
- [ ] `AGORA_DATA_CENTER=EU` (or your region)
- [ ] `AGORA_CUSTOMER_ID` - For cloud recording (optional but recommended)
- [ ] `AGORA_CUSTOMER_SECRET` - For cloud recording (optional but recommended)
- [ ] `NEXT_PUBLIC_SUPABASE_URL` - Your Supabase URL
- [ ] `NEXT_PUBLIC_SUPABASE_ANON_KEY` - Your Supabase anon key

### 2. Code Configuration ✅

- [x] `app_config.dart` - API URLs correctly point to `www.prepskul.com/api` ✅
- [x] `env.template` - API URLs correctly configured ✅
- [x] `web/index.html` - Agora SDK loaded (iris-web-rtc.js) ✅
- [x] Tutor flow - Session verification before navigation ✅
- [x] Student flow - Direct Agora join for online sessions ✅

### 3. Supabase Configuration

- [ ] Add production domains to Supabase Authentication → URL Configuration:
  - `https://app.prepskul.com`
  - `https://app.prepskul.com/**`
  - `https://www.prepskul.com` (if needed for API)
  - `https://www.prepskul.com/**`
- [ ] Set Site URL to: `https://app.prepskul.com`
- [ ] Verify RLS policies allow session access for tutors/learners/parents

### 4. Next.js API CORS Configuration

**CRITICAL:** Ensure your Next.js API route at `PrepSkul_Web/app/api/agora/token/route.ts` has CORS headers:

```typescript
export async function POST(request: Request) {
  // CORS headers
  const corsHeaders = {
    'Access-Control-Allow-Origin': 'https://app.prepskul.com', // Flutter app domain
    'Access-Control-Allow-Methods': 'POST, OPTIONS',
    'Access-Control-Allow-Headers': 'Content-Type, Authorization',
    'Access-Control-Allow-Credentials': 'true',
  };

  // Handle preflight
  if (request.method === 'OPTIONS') {
    return new Response(null, { status: 200, headers: corsHeaders });
  }

  // Your token generation logic here...
  // Return response with CORS headers
  return Response.json(data, { headers: corsHeaders });
}
```

### 5. Agora Console Configuration

- [ ] Agora App ID matches in both Flutter and Next.js
- [ ] Agora App Certificate is set in Next.js `.env.local`
- [ ] Domain `app.prepskul.com` is registered in Agora (if required)
- [ ] Cloud Recording enabled (if using recording feature)

### 6. Database Migrations

- [ ] Migration `041_add_agora_video_sessions.sql` has been run
- [ ] `individual_sessions` table has Agora-related fields
- [ ] `session_recordings` table exists (if using recording)

---

## 🧪 Testing Checklist

### Before Deployment

1. **Local Testing:**
   - [ ] Test with two browsers (tutor and student)
   - [ ] Verify token generation works
   - [ ] Verify video/audio works both ways
   - [ ] Test error scenarios (network failure, invalid session)

2. **Staging/Production Testing:**
   - [ ] Deploy to staging first
   - [ ] Test complete flow: Tutor starts → Student joins
   - [ ] Verify CORS works (no CORS errors in browser console)
   - [ ] Verify session validation works
   - [ ] Test on different browsers (Chrome, Firefox, Safari)

### Post-Deployment Verification

1. **Browser Console Checks:**
   - [ ] No CORS errors
   - [ ] No "Session not found" errors
   - [ ] Agora SDK loads successfully
   - [ ] Token generation succeeds
   - [ ] Video/audio streams work

2. **Network Tab Checks:**
   - [ ] API call to `https://www.prepskul.com/api/agora/token` succeeds (200 status)
   - [ ] Response includes: `token`, `channelName`, `uid`, `expiresAt`
   - [ ] No 401/403 errors

3. **User Flow Verification:**
   - [ ] Tutor clicks "Join Session" → Navigates to Agora screen
   - [ ] Student clicks "Join Meeting" → Navigates to Agora screen
   - [ ] Both users see each other's video
   - [ ] Audio works both ways
   - [ ] Controls work (mute, camera, end call)

---

## 🔧 Troubleshooting Guide

### If CORS Errors Occur:

1. **Check Next.js API CORS headers** (see section 4 above)
2. **Verify Supabase URL Configuration** (see section 3)
3. **Check browser console** for exact CORS error message
4. **Verify API URL** is `https://www.prepskul.com/api/agora/token` (not `app.prepskul.com`)

### If "Session not found" Errors Occur:

1. **Check RLS policies** - User must be tutor/learner/parent of the session
2. **Verify session exists** in `individual_sessions` table
3. **Check session status** - Must be 'scheduled' or 'in_progress'
4. **Verify user authentication** - User must be logged in

### If Agora SDK Not Loading:

1. **Check `web/index.html`** - iris-web-rtc.js script should be loaded
2. **Check browser console** for SDK loading errors
3. **Verify CDN URL** is accessible: `https://download.agora.io/sdk/release/iris-web-rtc_n450_w4220_0.8.6.js`
4. **Check network tab** - Script should load before Flutter initializes

### If Token Generation Fails:

1. **Check Next.js logs** for errors
2. **Verify Agora credentials** in Next.js `.env.local`
3. **Check API endpoint** is accessible: `https://www.prepskul.com/api/agora/token`
4. **Verify user authentication** - Supabase session token must be valid

---

## ✅ Deployment Steps

1. **Set Environment Variables:**
   - Flutter: Update `.env` with production values
   - Next.js: Update `.env.local` with Agora credentials

2. **Configure Supabase:**
   - Add production domains to allowed redirect URLs
   - Verify RLS policies

3. **Configure Next.js API:**
   - Add CORS headers to `/api/agora/token` route
   - Test API endpoint manually

4. **Build Flutter App:**
   ```bash
   flutter build web --release
   ```

5. **Deploy:**
   - Flutter app to `app.prepskul.com`
   - Next.js API to `www.prepskul.com`

6. **Test:**
   - Follow Post-Deployment Verification checklist above

---

## 🎯 Expected Flow

### Tutor Flow:
1. Tutor opens "My Sessions" screen
2. Sees online session with "Join Video Session" button
3. Clicks button → Session verified in database
4. Navigates to `AgoraVideoSessionScreen`
5. Agora service initializes → Fetches token from `www.prepskul.com/api/agora/token`
6. Joins Agora channel → Video/audio enabled
7. Session lifecycle started (status → in_progress)

### Student Flow:
1. Student opens "My Sessions" screen
2. Sees online session with "Join Meeting" button
3. Clicks button → Navigates to `AgoraVideoSessionScreen`
4. Agora service initializes → Fetches token from `www.prepskul.com/api/agora/token`
5. Joins Agora channel → Video/audio enabled
6. Sees tutor's video → Tutor sees student's video

---

## ⚠️ Critical Notes

1. **API Domain:** Next.js API MUST be on `www.prepskul.com/api`, NOT `app.prepskul.com/api`
2. **CORS:** Next.js API MUST have CORS headers allowing `app.prepskul.com`
3. **Agora SDK:** Must load before Flutter initializes (already configured in `index.html`)
4. **Session Validation:** Happens before navigation to prevent errors
5. **Error Handling:** All errors are caught and displayed to user with helpful messages

---

## 📝 Final Checklist Before Going Live

- [ ] All environment variables set correctly
- [ ] Supabase domains configured
- [ ] Next.js API CORS configured
- [ ] Agora credentials set in Next.js
- [ ] Database migrations run
- [ ] Tested on staging environment
- [ ] Browser console shows no errors
- [ ] Video/audio works both ways
- [ ] Session lifecycle works correctly
- [ ] Error handling works (test with invalid session)

---

**Status:** ✅ Code is ready for deployment. Follow this checklist to ensure seamless production deployment.

