# Agora Token Service - Enhanced Error Logging

## Overview
Enhanced error logging in `agora_token_service.dart` to provide accurate, detailed error messages that help diagnose production issues.

## Changes Made

### 1. **Detailed Request Logging**
- Logs session ID, user ID, and platform (Web/Mobile) before making request
- Logs request headers and body for debugging
- Tracks request duration for performance monitoring

### 2. **Comprehensive Response Logging**
- **Full response body logging** for all non-200 status codes
- **Response headers logging** to check CORS and other headers
- **Parsed error message extraction** from server response
- **Multiple error field parsing**: `error`, `message`, `details`

### 3. **Server Error Message Display**
- **HTTP 500 errors** now show the actual server error message
- Includes diagnostic information:
  - Next.js API route logs
  - Environment variables (AGORA_APP_ID, AGORA_APP_CERTIFICATE)
  - Database connection status
  - Server deployment status

### 4. **Enhanced Retry Logic Logging**
- Logs error type and message for each failed attempt
- Provides specific guidance based on error type:
  - `ClientException` → CORS/network issues
  - `timeout` → Server performance issues
  - `[server]` → Server-side errors
- Logs total attempts and final failure reason

### 5. **Improved User-Facing Error Messages**
- **Server errors (500+)**: Shows actual server error message with diagnostic steps
- **CORS errors**: Explains CORS configuration issue with origin details
- **Network errors**: Provides specific troubleshooting steps
- **Timeout errors**: Explains possible causes (slow server, network latency, etc.)

## What You'll See Now

### In Browser Console (for HTTP 500 errors):
```
❌ [ERROR] ========== AGORA TOKEN FETCH ERROR ==========
❌ [ERROR] Error type: Exception
❌ [ERROR] Error message: Server Error (500): [Actual server error message here]
❌ [ERROR] API URL: https://www.prepskul.com/api/agora/token
❌ [ERROR] Session ID: [session-id]
❌ [ERROR] Platform: Web
❌ [ERROR] ============================================
❌ [ERROR] Server returned error status: 500
❌ [ERROR] Response body: {"error":"Missing AGORA_APP_ID environment variable"}
❌ [ERROR] Response headers: {content-type: application/json, ...}
❌ [ERROR] Server error message: Missing AGORA_APP_ID environment variable
```

### In User Dialog:
```
Server Error (500): Missing AGORA_APP_ID environment variable

This is a server-side issue. Please check:
1. Next.js API route logs
2. Environment variables (AGORA_APP_ID, AGORA_APP_CERTIFICATE)
3. Database connection
4. Server deployment status
```

## Benefits

1. **Accurate Diagnosis**: You'll see the exact server error message instead of generic "CORS/network" errors
2. **Faster Debugging**: All relevant information is logged in one place
3. **Better User Experience**: Users see actionable error messages instead of confusing generic ones
4. **Production Debugging**: Can diagnose production issues without needing server logs immediately

## Next Steps

When you deploy and see the error again:

1. **Check Browser Console**: Look for the detailed error logs showing:
   - Actual server error message
   - Response body
   - Response status code

2. **Check Server Logs**: The error message will guide you to check:
   - Next.js API route logs
   - Environment variables
   - Database connection

3. **Common Issues to Check**:
   - Missing `AGORA_APP_ID` or `AGORA_APP_CERTIFICATE` in production environment
   - Supabase connection issues
   - Database query failures
   - Authentication token validation failures

## Example Error Scenarios

### Scenario 1: Missing Environment Variable
**Server Response**: `{"error":"AGORA_APP_ID is not defined"}`
**User Sees**: "Server Error (500): AGORA_APP_ID is not defined"
**Action**: Add `AGORA_APP_ID` to production environment variables

### Scenario 2: Database Connection Failure
**Server Response**: `{"error":"Failed to connect to database"}`
**User Sees**: "Server Error (500): Failed to connect to database"
**Action**: Check Supabase connection and credentials

### Scenario 3: Invalid Session
**Server Response**: `{"error":"Session not found"}`
**User Sees**: "Client Error (404): Session not found"
**Action**: Verify session exists in database

## Testing

The enhanced logging works in both:
- ✅ Development (localhost)
- ✅ Production (app.prepskul.com / www.prepskul.com)

All error information is logged to browser console for easy debugging.

