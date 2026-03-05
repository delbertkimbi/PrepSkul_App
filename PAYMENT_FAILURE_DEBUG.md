# Payment Failure Debug Guide

## Error Message You're Seeing

**"We couldn't process your payment. Please check your phone number and try again."**

This is a **generic error message** that appears when:
1. Fapshi API returns an error during payment initiation
2. Payment status polling detects a failure
3. The actual error gets converted to a user-friendly message

## Most Common Causes in Production

### 1. **Fapshi API Credentials Not Set** ⚠️ MOST LIKELY
**Symptom:** Payment fails immediately, no transaction ID created

**Check:**
- In your Flutter app's `.env` file (or build-time injection):
  - `FAPSHI_COLLECTION_API_USER_LIVE` must be set
  - `FAPSHI_COLLECTION_API_KEY_LIVE` must be set
- In `app_config.dart`: `isProduction = true` (you confirmed this ✅)

**Fix:**
```bash
# Set these before running inject-env.js
$env:FAPSHI_COLLECTION_API_USER_LIVE="your-live-api-user"
$env:FAPSHI_COLLECTION_API_KEY_LIVE="your-live-api-key"

# Then inject and build
node scripts/inject-env.js
flutter build web
```

**Verify:** Check browser console logs for:
```
🔑 API User: abc... (should show first 3 chars, not "EMPTY")
```

### 2. **Phone Number Format Issue**
**Symptom:** Payment fails immediately with phone validation error

**Your number:** `+237653188043`
- Should normalize to: `653188043` ✅ (9 digits, starts with 65 = MTN)
- Format is correct

**If still failing:** Check browser console for:
```
Please enter a valid phone number. Use format: 67XXXXXXX or 69XXXXXXX
```

### 3. **Fapshi API Returning Error**
**Symptom:** Payment request sent but Fapshi rejects it

**Common Fapshi errors:**
- **"Insufficient balance"** → User doesn't have enough money (but you said you have money)
- **"Invalid phone number"** → Phone format issue (unlikely with your number)
- **"Payment declined"** → User rejected on phone
- **"Service unavailable"** → Fapshi API issue
- **401/403 errors** → API credentials wrong

**Check:** Browser console logs should show:
```
📥 Fapshi response status: XXX
📥 Fapshi response body: {...}
Fapshi API error: <actual error message>
```

### 4. **Payment Request Not Reaching User's Phone**
**Symptom:** Payment initiated but no notification received

**Possible causes:**
- Direct Pay not enabled in Fapshi dashboard (but docs say it's approved ✅)
- Phone number not registered for mobile money
- Network issues between Fapshi and MTN
- User's mobile money app not active

**Check:** 
- Did you receive a payment notification on your phone?
- Check Fapshi dashboard for transaction status

### 5. **Payment Status Polling Detects Failure**
**Symptom:** Payment initiated successfully, but status check shows FAILED

**Possible causes:**
- User rejected payment on phone
- Payment timed out
- Network error during payment processing
- Insufficient balance (even if you think you have money)

## How to Debug

### Step 1: Check Browser Console Logs

**Open browser DevTools (F12) → Console tab**

Look for these log messages:
```
📤 Fapshi payment request: {...}
🌐 Fapshi API URL: https://live.fapshi.com/direct-pay
🔑 API User: abc... (or "EMPTY" if not set)
📥 Fapshi response status: 200 (or error code)
📥 Fapshi response body: {...}
Fapshi API error: <actual error>
```

**What to look for:**
- If `API User: EMPTY` → Credentials not set
- If `response status: 401/403` → Wrong credentials
- If `response status: 400` → Invalid request (phone/amount)
- If `response status: 200` but body has error → Fapshi API error

### Step 2: Check Actual Fapshi Error

The generic error message hides the real error. Check console logs for the **actual Fapshi API error message**.

**Common actual errors:**
- `"Insufficient balance"` → Check your MTN mobile money balance
- `"Payment declined"` → You rejected on phone
- `"Invalid phone number"` → Format issue
- `"Service unavailable"` → Fapshi API issue
- `"Unauthorized"` → Wrong API credentials

### Step 3: Verify Production Credentials

**In your `.env` file or environment:**
```env
FAPSHI_COLLECTION_API_USER_LIVE=your-actual-live-user
FAPSHI_COLLECTION_API_KEY_LIVE=your-actual-live-key
```

**Verify in code:**
- `AppConfig.isProduction = true` ✅ (you confirmed)
- `AppConfig.fapshiApiUser` should return your live user
- `AppConfig.fapshiApiKey` should return your live key

### Step 4: Check Fapshi Dashboard

1. Log into **Fapshi Dashboard**: https://dashboard.fapshi.com
2. Check **Transactions** → Look for your payment attempt
3. Check transaction status and error message
4. Verify **Direct Pay is enabled** in settings

### Step 5: Test Payment Flow

**What happens:**
1. You enter phone: `+237653188043`
2. App normalizes to: `653188043`
3. App calls: `POST https://live.fapshi.com/direct-pay`
4. Fapshi sends payment request to your phone
5. You approve/reject on phone
6. App polls status: `GET https://live.fapshi.com/payment-status/{transId}`

**At which step does it fail?**
- Step 3 (API call) → Check credentials, network
- Step 4 (no notification) → Check Direct Pay enabled, phone number
- Step 5 (you reject) → Payment will show as FAILED
- Step 6 (status check) → Check what status Fapshi returns

## Quick Fixes

### Fix 1: Verify Credentials Are Set
```bash
# Check if env vars are set (PowerShell)
$env:FAPSHI_COLLECTION_API_USER_LIVE
$env:FAPSHI_COLLECTION_API_KEY_LIVE

# If empty, set them:
$env:FAPSHI_COLLECTION_API_USER_LIVE="your-user"
$env:FAPSHI_COLLECTION_API_KEY_LIVE="your-key"

# Then rebuild
node scripts/inject-env.js
flutter build web
```

### Fix 2: Check Browser Console
1. Open payment screen
2. Open DevTools (F12)
3. Go to Console tab
4. Try payment again
5. Look for Fapshi API logs
6. Share the actual error message

### Fix 3: Check Fapshi Dashboard
1. Log into Fapshi dashboard
2. Check recent transactions
3. See actual error message from Fapshi
4. Verify Direct Pay is enabled

### Fix 4: Test with Different Amount
- Try minimum amount: **100 XAF**
- If that works, issue might be amount-related

### Fix 5: Verify Phone Number
- Ensure phone number is registered for MTN Mobile Money
- Check if mobile money is active on that number
- Try a different phone number to isolate the issue

## Most Likely Issue

Based on your description ("payment fails in production"), the most likely causes are:

1. **API credentials not set in production build** (60% likely)
   - Credentials might be set in Vercel but not injected into Flutter web build
   - Check: Browser console for "API User: EMPTY"

2. **Fapshi API returning specific error** (30% likely)
   - Check browser console for actual Fapshi error
   - Could be: insufficient balance, payment declined, service unavailable

3. **Payment rejected on phone** (10% likely)
   - You might have accidentally rejected the payment request
   - Check: Did you receive notification? Did you approve it?

## Next Steps

1. **Check browser console** → Share the actual Fapshi API error
2. **Verify credentials** → Ensure they're set before building
3. **Check Fapshi dashboard** → See transaction status and error
4. **Try again** → With console open to see detailed logs

## Need More Help?

Share:
- Browser console logs (especially Fapshi API response)
- Fapshi dashboard transaction details
- Whether you received payment notification on phone
- Whether you approved/rejected the payment

This will help pinpoint the exact issue!
