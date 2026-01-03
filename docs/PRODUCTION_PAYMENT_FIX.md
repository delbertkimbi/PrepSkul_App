# Production Payment Fix

## Issues Fixed

### 1. Production Mode Not Enabled
**Problem**: App was still using sandbox API (`https://sandbox.fapshi.com/direct-pay`) even though production should be on.

**Fix**: Changed `isProduction` flag in `app_config.dart`:
```dart
static const bool isProduction = true; // ← PRODUCTION MODE ENABLED
```

**Impact**: 
- App now uses `https://live.fapshi.com` for payments
- Uses production Fapshi API credentials
- Payments will send real payment requests to phones

### 2. Payment Status Polling Too Fast
**Problem**: Payment was marked as successful on first polling attempt (after 3 seconds), before user could receive payment request.

**Fix**: Increased minimum wait time to 10 seconds for production:
```dart
final effectiveMinWaitTime = minWaitTime ?? 
    (isProduction 
        ? const Duration(seconds: 10) // Production: wait 10s to ensure request was sent
        : const Duration(seconds: 10)); // Sandbox: also 10s to detect auto-success
```

**Impact**:
- App waits at least 10 seconds before accepting payment as successful
- Gives user time to receive and confirm payment request on phone
- Prevents false positives from sandbox auto-success

### 3. Missing RLS Policies for Credits Tables
**Problem**: `user_credits` and `credit_transactions` tables had no RLS policies, causing "new row violates row-level security policy" errors.

**Fix**: Created migration `038_user_credits_system.sql` with:
- Table definitions for `user_credits` and `credit_transactions`
- RLS policies allowing users to:
  - View their own credits and transactions
  - Insert their own credits (for initialization)
  - Update their own credits
  - Insert their own transactions (for purchases)
- Service role policies for backend operations

**Impact**:
- Users can now convert payments to credits
- Credit transactions are properly recorded
- Security maintained through RLS

## Next Steps

1. **Run the migration**:
   ```bash
   # Apply migration to Supabase
   supabase db push
   # OR manually run the SQL in Supabase dashboard
   ```

2. **Test payment flow**:
   - Make a payment with a real phone number
   - Verify you receive payment request on phone
   - Confirm payment on phone
   - Verify credits are added to account

3. **Monitor logs**:
   - Check that app uses `https://live.fapshi.com`
   - Verify payment status polling waits at least 10 seconds
   - Confirm no RLS errors when converting payments to credits

## Important Notes

- **Production API Keys**: Ensure `FAPSHI_COLLECTION_API_USER_LIVE` and `FAPSHI_COLLECTION_API_KEY_LIVE` are set in your environment variables
- **Direct Pay**: Must be enabled in your Fapshi production account
- **Phone Numbers**: Use real phone numbers in production (sandbox test numbers like `670000000` won't work)

## Verification

After deploying, check logs for:
- ✅ `🌐 Fapshi API URL: https://live.fapshi.com/direct-pay` (not sandbox)
- ✅ `⚠️ Payment marked as SUCCESSFUL too quickly` warning if payment succeeds too fast
- ✅ No RLS errors when converting payments to credits
- ✅ Payment request received on phone before payment is marked successful

