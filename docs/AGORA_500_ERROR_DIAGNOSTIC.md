# Agora Token API 500 Error - Diagnostic Guide

## 🔴 Error Summary

**Error**: HTTP 500 Internal Server Error  
**Endpoint**: `https://www.prepskul.com/api/agora/token`  
**Status**: Server-side error in Next.js API route

## 🔍 Diagnostic Steps

### Step 1: Check Server Response Body

The browser console should show the actual server error message. Look for:
```
❌ [ERROR] Response body: {"error":"..."}
❌ [ERROR] Server error message: ...
```

If the response body is empty or shows a generic error, proceed to Step 2.

### Step 2: Check Next.js API Route

**File Location**: `PrepSkul_Web/app/api/agora/token/route.ts`

#### Common Issues to Check:

1. **Missing Environment Variables** (Most Common)
   ```typescript
   // Check if these are defined:
   const appId = process.env.AGORA_APP_ID;
   const appCertificate = process.env.AGORA_APP_CERTIFICATE;
   
   if (!appId || !appCertificate) {
     return Response.json(
       { error: 'Missing AGORA_APP_ID or AGORA_APP_CERTIFICATE' },
       { status: 500 }
     );
   }
   ```

2. **Database Connection Issues**
   ```typescript
   // Check Supabase connection
   const supabaseUrl = process.env.NEXT_PUBLIC_SUPABASE_URL;
   const supabaseKey = process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY;
   
   if (!supabaseUrl || !supabaseKey) {
     return Response.json(
       { error: 'Missing Supabase configuration' },
       { status: 500 }
     );
   }
   ```

3. **Missing Error Handling**
   ```typescript
   export async function POST(request: Request) {
     try {
       // Your code here
     } catch (error) {
       console.error('Agora token generation error:', error);
       return Response.json(
         { 
           error: error instanceof Error ? error.message : 'Unknown error',
           details: process.env.NODE_ENV === 'development' ? String(error) : undefined
         },
         { status: 500 }
       );
     }
   }
   ```

4. **Missing Dependencies**
   ```bash
   # In PrepSkul_Web directory
   npm install agora-access-token
   # or
   pnpm install agora-access-token
   ```

### Step 3: Check Vercel/Deployment Environment Variables

If deployed on Vercel:

1. Go to Vercel Dashboard → Your Project → Settings → Environment Variables
2. Verify these are set:
   - `AGORA_APP_ID`
   - `AGORA_APP_CERTIFICATE`
   - `NEXT_PUBLIC_SUPABASE_URL`
   - `NEXT_PUBLIC_SUPABASE_ANON_KEY`
   - `SUPABASE_SERVICE_ROLE_KEY` (if used)

3. **Important**: After adding/updating environment variables, **redeploy** your Next.js app

### Step 4: Check Server Logs

#### Vercel Logs:
1. Go to Vercel Dashboard → Your Project → Deployments
2. Click on the latest deployment
3. Go to "Functions" tab
4. Click on `/api/agora/token`
5. Check "Logs" for error messages

#### Local Testing:
```bash
# In PrepSkul_Web directory
npm run dev
# or
pnpm dev

# Then check terminal output when making a request
```

### Step 5: Verify API Route Structure

Your `route.ts` should look like this:

```typescript
import { NextRequest, NextResponse } from 'next/server';
import { RtcTokenBuilder, RtcRole } from 'agora-access-token';

export async function POST(request: NextRequest) {
  try {
    // 1. Validate environment variables
    const appId = process.env.AGORA_APP_ID;
    const appCertificate = process.env.AGORA_APP_CERTIFICATE;
    
    if (!appId || !appCertificate) {
      return NextResponse.json(
        { error: 'Agora credentials not configured' },
        { status: 500 }
      );
    }

    // 2. Parse request body
    const body = await request.json();
    const { sessionId } = body;
    
    if (!sessionId) {
      return NextResponse.json(
        { error: 'sessionId is required' },
        { status: 400 }
      );
    }

    // 3. Verify authentication
    const authHeader = request.headers.get('authorization');
    if (!authHeader) {
      return NextResponse.json(
        { error: 'Unauthorized' },
        { status: 401 }
      );
    }

    // 4. Verify session exists in database
    // ... your database query here ...

    // 5. Generate token
    const channelName = `session_${sessionId}`;
    const uid = 0; // or get from session
    const role = RtcRole.PUBLISHER;
    const expirationTimeInSeconds = 3600; // 1 hour
    
    const token = RtcTokenBuilder.buildTokenWithUid(
      appId,
      appCertificate,
      channelName,
      uid,
      role,
      expirationTimeInSeconds
    );

    // 6. Return response with CORS headers
    return NextResponse.json(
      {
        token,
        channelName,
        uid,
        expiresAt: Date.now() + expirationTimeInSeconds * 1000,
        role: 'publisher'
      },
      {
        headers: {
          'Access-Control-Allow-Origin': 'https://app.prepskul.com',
          'Access-Control-Allow-Methods': 'POST, OPTIONS',
          'Access-Control-Allow-Headers': 'Content-Type, Authorization',
        }
      }
    );
  } catch (error) {
    console.error('Agora token generation error:', error);
    return NextResponse.json(
      { 
        error: error instanceof Error ? error.message : 'Internal server error',
        details: process.env.NODE_ENV === 'development' ? String(error) : undefined
      },
      { status: 500 }
    );
  }
}

// Handle CORS preflight
export async function OPTIONS(request: NextRequest) {
  return NextResponse.json(
    {},
    {
      headers: {
        'Access-Control-Allow-Origin': 'https://app.prepskul.com',
        'Access-Control-Allow-Methods': 'POST, OPTIONS',
        'Access-Control-Allow-Headers': 'Content-Type, Authorization',
      }
    }
  );
}
```

## 🛠️ Quick Fixes

### Fix 1: Add Environment Variables to Vercel

1. Go to Vercel Dashboard → Project → Settings → Environment Variables
2. Add:
   - `AGORA_APP_ID` = your Agora App ID
   - `AGORA_APP_CERTIFICATE` = your Agora App Certificate
3. **Redeploy** the application

### Fix 2: Add Error Handling

Add try-catch block around your token generation code:

```typescript
export async function POST(request: NextRequest) {
  try {
    // Your existing code
  } catch (error) {
    console.error('Error:', error);
    return NextResponse.json(
      { error: error instanceof Error ? error.message : 'Unknown error' },
      { status: 500 }
    );
  }
}
```

### Fix 3: Verify Dependencies

```bash
cd PrepSkul_Web
npm install agora-access-token
# or
pnpm install agora-access-token
```

## 📋 Checklist

- [ ] `AGORA_APP_ID` is set in Vercel environment variables
- [ ] `AGORA_APP_CERTIFICATE` is set in Vercel environment variables
- [ ] `NEXT_PUBLIC_SUPABASE_URL` is set
- [ ] `NEXT_PUBLIC_SUPABASE_ANON_KEY` is set
- [ ] `agora-access-token` package is installed
- [ ] API route has try-catch error handling
- [ ] API route returns proper error messages
- [ ] Next.js app has been redeployed after adding env vars
- [ ] Checked Vercel function logs for actual error

## 🔗 Related Files

- Flutter: `lib/features/sessions/services/agora_token_service.dart`
- Next.js: `PrepSkul_Web/app/api/agora/token/route.ts` (check this file)
- Docs: `AGORA_SETUP_GUIDE.md`
- Docs: `DEPLOYMENT_READINESS_CHECKLIST.md`

## 📞 Next Steps

1. **Check Vercel Logs**: This will show the actual error message
2. **Verify Environment Variables**: Most 500 errors are due to missing env vars
3. **Test Locally**: Run Next.js locally to see detailed error messages
4. **Check Response Body**: The browser console should show the server error message

If you can see the actual error message in the browser console or Vercel logs, that will tell you exactly what's wrong.

