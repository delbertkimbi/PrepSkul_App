# 🔔 Fapshi Webhook Integration Guide

## Overview

The Fapshi webhook integration handles payment confirmations for all payment types:
- **Trial Session Payments** (`trial_*`)
- **Payment Request Payments** (`payment_request_*`)
- **Session Payments** (`session_*`)

## Architecture

### Flutter Service
**File:** `lib/features/payment/services/fapshi_webhook_service.dart`

Centralized webhook handler that routes to appropriate handlers based on `externalId` pattern.

### Next.js API Endpoint (Required)
**File:** `PrepSkul_Web/app/api/webhooks/fapshi/route.ts`

This endpoint receives webhooks from Fapshi and calls the Flutter service.

---

## Payment Types & ExternalId Patterns

### 1. Trial Session Payments
- **Pattern:** `trial_{trialSessionId}`
- **Example:** `trial_abc123-def456-ghi789`
- **Handler:** `_handleTrialSessionPayment()`
- **Actions:**
  - Updates `trial_sessions.payment_status` → `paid`
  - Updates `trial_sessions.status` → `scheduled`
  - Generates Meet link (for online sessions)
  - Sends success notifications

### 2. Payment Request Payments
- **Pattern:** `payment_request_{paymentRequestId}`
- **Example:** `payment_request_xyz789-abc123`
- **Handler:** `_handlePaymentRequestPayment()`
- **Actions:**
  - Updates `payment_requests.status` → `paid`
  - Links payment to booking request
  - Sends success notifications

### 3. Session Payments
- **Pattern:** `session_{sessionId}`
- **Example:** `session_session123`
- **Handler:** `_handleSessionPayment()`
- **Actions:**
  - Updates `session_payments.payment_status` → `paid`
  - Moves balance from `pending` → `active`
  - Updates `tutor_earnings.earnings_status` → `active`
  - Sends success notifications

---

## Next.js Webhook Endpoint Implementation

Create this file in your Next.js app:

**File:** `PrepSkul_Web/app/api/webhooks/fapshi/route.ts`

```typescript
import { NextRequest, NextResponse } from 'next/server';
import { createClient } from '@supabase/supabase-js';

// Initialize Supabase client
const supabase = createClient(
  process.env.NEXT_PUBLIC_SUPABASE_URL!,
  process.env.SUPABASE_SERVICE_ROLE_KEY!
);

export async function POST(request: NextRequest) {
  try {
    const payload = await request.json();
    
    // Verify webhook (if Fapshi provides signature verification)
    // const isValid = verifyWebhookSignature(payload, request.headers);
    // if (!isValid) {
    //   return NextResponse.json({ error: 'Unauthorized' }, { status: 401 });
    // }
    
    const {
      transId,        // Fapshi transaction ID
      status,         // SUCCESS, SUCCESSFUL, FAILED, EXPIRED, etc.
      externalId,     // Our external ID (trial_*, payment_request_*, session_*)
      userId,         // User ID (optional)
      amount,         // Payment amount (optional)
      failureReason,  // Reason for failure (optional)
    } = payload;

    // Call Flutter service via Supabase Edge Function or direct database update
    // Since we can't directly call Flutter code from Next.js, we'll use Supabase RPC
    
    // Option 1: Use Supabase RPC function (recommended)
    const { error } = await supabase.rpc('handle_fapshi_webhook', {
      transaction_id: transId,
      status: status,
      external_id: externalId,
      user_id: userId,
      amount: amount,
      failure_reason: failureReason,
    });

    if (error) {
      console.error('Error processing webhook:', error);
      return NextResponse.json(
        { error: 'Failed to process webhook' },
        { status: 500 }
      );
    }

    return NextResponse.json({ success: true });
  } catch (error) {
    console.error('Webhook error:', error);
    return NextResponse.json(
      { error: 'Internal server error' },
      { status: 500 }
    );
  }
}
```

---

## Supabase RPC Function (Alternative Approach)

If you prefer to handle webhook logic in the database, create this RPC function:

**File:** `supabase/migrations/025_fapshi_webhook_rpc.sql`

```sql
-- Create RPC function to handle Fapshi webhooks
CREATE OR REPLACE FUNCTION handle_fapshi_webhook(
  transaction_id TEXT,
  status TEXT,
  external_id TEXT,
  user_id TEXT DEFAULT NULL,
  amount NUMERIC DEFAULT NULL,
  failure_reason TEXT DEFAULT NULL
)
RETURNS JSON
LANGUAGE plpgsql
AS $$
DECLARE
  result JSON;
BEGIN
  -- This function can be called from Next.js webhook endpoint
  -- It will update the appropriate tables based on external_id pattern
  
  -- For now, we'll just log and return success
  -- The actual logic should be in Flutter service or Edge Function
  
  INSERT INTO webhook_logs (
    transaction_id,
    status,
    external_id,
    user_id,
    amount,
    failure_reason,
    created_at
  ) VALUES (
    transaction_id,
    status,
    external_id,
    user_id,
    amount,
    failureReason,
    NOW()
  );
  
  RETURN json_build_object('success', true);
END;
$$;
```

---

## Direct Database Update Approach (Simplest)

Alternatively, update the Next.js webhook endpoint to directly update the database:

```typescript
export async function POST(request: NextRequest) {
  try {
    const payload = await request.json();
    const { transId, status, externalId, userId, amount, failureReason } = payload;

    // Normalize status
    const normalizedStatus = status.toUpperCase();
    const isSuccess = normalizedStatus === 'SUCCESS' || normalizedStatus === 'SUCCESSFUL';

    // Route based on externalId pattern
    if (externalId.startsWith('trial_')) {
      const trialSessionId = externalId.replace('trial_', '');
      
      if (isSuccess) {
        await supabase
          .from('trial_sessions')
          .update({
            payment_status: 'paid',
            status: 'scheduled',
            fapshi_trans_id: transId,
            payment_confirmed_at: new Date().toISOString(),
            updated_at: new Date().toISOString(),
          })
          .eq('id', trialSessionId);
      } else {
        await supabase
          .from('trial_sessions')
          .update({
            payment_status: 'unpaid',
            updated_at: new Date().toISOString(),
          })
          .eq('id', trialSessionId);
      }
    } else if (externalId.startsWith('payment_request_')) {
      const paymentRequestId = externalId.replace('payment_request_', '');
      
      await supabase
        .from('payment_requests')
        .update({
          status: isSuccess ? 'paid' : 'failed',
          fapshi_trans_id: transId,
          ...(isSuccess ? { paid_at: new Date().toISOString() } : { failed_at: new Date().toISOString() }),
          updated_at: new Date().toISOString(),
        })
        .eq('id', paymentRequestId);
    } else if (externalId.startsWith('session_')) {
      const sessionId = externalId.replace('session_', '');
      
      // Find payment by session_id
      const { data: payment } = await supabase
        .from('session_payments')
        .select('id, tutor_earnings, individual_sessions!inner(tutor_id)')
        .eq('session_id', sessionId)
        .eq('fapshi_trans_id', transId)
        .maybeSingle();

      if (payment && isSuccess) {
        const paymentId = payment.id;
        const tutorId = payment.individual_sessions.tutor_id;
        const tutorEarnings = payment.tutor_earnings;

        // Update payment status
        await supabase
          .from('session_payments')
          .update({
            payment_status: 'paid',
            payment_confirmed_at: new Date().toISOString(),
            updated_at: new Date().toISOString(),
          })
          .eq('id', paymentId);

        // Update tutor earnings to active
        await supabase
          .from('tutor_earnings')
          .update({
            earnings_status: 'active',
            added_to_active_balance: true,
            active_balance_added_at: new Date().toISOString(),
            updated_at: new Date().toISOString(),
          })
          .eq('session_payment_id', paymentId);
      }
    }

    return NextResponse.json({ success: true });
  } catch (error) {
    console.error('Webhook error:', error);
    return NextResponse.json({ error: 'Internal server error' }, { status: 500 });
  }
}
```

---

## Webhook Configuration in Fapshi Dashboard

1. **Login to Fapshi Dashboard**
2. **Navigate to:** Settings → Webhooks
3. **Add Webhook URL:**
   - **Production:** `https://app.prepskul.com/api/webhooks/fapshi`
   - **Sandbox:** `https://app.prepskul.com/api/webhooks/fapshi` (or your dev URL)
4. **Select Events:**
   - ✅ Payment Success
   - ✅ Payment Failed
   - ✅ Payment Expired
5. **Save Configuration**

---

## Testing Webhooks

### Using Fapshi Sandbox
1. Initiate a test payment in the app
2. Use Fapshi test credentials
3. Complete payment in test environment
4. Webhook should be triggered automatically

### Manual Testing (cURL)
```bash
curl -X POST https://app.prepskul.com/api/webhooks/fapshi \
  -H "Content-Type: application/json" \
  -d '{
    "transId": "test_trans_123",
    "status": "SUCCESS",
    "externalId": "trial_abc123",
    "userId": "user_123",
    "amount": 2000
  }'
```

---

## Payment Status Flow

### Trial Session Payment
```
1. Student initiates payment → status: 'pending'
2. Fapshi webhook received → status: 'SUCCESS'
3. Update trial_sessions:
   - payment_status: 'paid'
   - status: 'scheduled'
   - fapshi_trans_id: set
4. Generate Meet link (if online)
5. Send notifications
```

### Payment Request Payment
```
1. Student initiates payment → status: 'pending'
2. Fapshi webhook received → status: 'SUCCESS'
3. Update payment_requests:
   - status: 'paid'
   - fapshi_trans_id: set
   - paid_at: timestamp
4. Send notifications
```

### Session Payment
```
1. Session completed → payment created → status: 'pending'
2. Earnings added to pending_balance
3. Fapshi webhook received → status: 'SUCCESS'
4. Update session_payments:
   - payment_status: 'paid'
5. Update tutor_earnings:
   - earnings_status: 'active'
   - Move to active_balance
6. Send notifications
```

---

## Error Handling

The webhook service includes comprehensive error handling:
- ✅ Silent failures (webhooks should not crash)
- ✅ Logging for monitoring
- ✅ Fallback to transaction ID lookup
- ✅ Notification failures don't block payment updates

---

## Monitoring

### Webhook Logs Table (Optional)
Create a table to log all webhook events:

```sql
CREATE TABLE IF NOT EXISTS webhook_logs (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  transaction_id TEXT NOT NULL,
  status TEXT NOT NULL,
  external_id TEXT,
  user_id TEXT,
  amount NUMERIC,
  failure_reason TEXT,
  processed BOOLEAN DEFAULT FALSE,
  error_message TEXT,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  processed_at TIMESTAMP WITH TIME ZONE
);
```

---

## Next Steps

1. ✅ **Flutter Service:** Complete (fapshi_webhook_service.dart)
2. ⏳ **Next.js Endpoint:** Create webhook route
3. ⏳ **Fapshi Configuration:** Configure webhook URL in dashboard
4. ⏳ **Testing:** Test with sandbox payments
5. ⏳ **Monitoring:** Set up webhook logs and alerts

---

## Support

For issues or questions:
- Check webhook logs in Supabase
- Verify Fapshi dashboard configuration
- Test with sandbox environment first
- Monitor Next.js API logs





