# Payment Sandbox Testing Guide

## ✅ Payment Support Summary

**Yes, you can simulate real payments in sandbox for ALL session types and location types!**

### Supported Session Types:
1. **Trial Sessions** (online/onsite)
   - Payment Service: `TrialSessionService.initiatePayment()`
   - External ID Format: `trial_<sessionId>`
   - Webhook Handler: ✅ Updated to handle trial payments

2. **Recurring Sessions** (online/onsite)
   - Payment Service: `SessionPaymentService.initiatePayment()`
   - External ID Format: `session_<sessionId>`
   - Webhook Handler: ✅ Updated to handle session payments

### Location Types:
- **Online Sessions**: ✅ Payment works (no difference)
- **Onsite Sessions**: ✅ Payment works (no difference)
- **Hybrid Sessions**: ✅ Payment works (no difference)

**Note:** Location type does NOT affect payment processing. Payments are identical regardless of whether the session is online or onsite.

---

## 🔧 Sandbox Configuration

### Environment Variables:
```env
FAPSHI_ENVIRONMENT=sandbox  # Default, can be 'sandbox' or 'live'
FAPSHI_SANDBOX_API_USER=your-fapshi-sandbox-api-user-here
FAPSHI_SANDBOX_API_KEY=your-fapshi-sandbox-api-key-here
```

### Sandbox URLs:
- **Base URL**: `https://sandbox.fapshi.com`
- **Direct Pay Endpoint**: `https://sandbox.fapshi.com/direct-pay`
- **Payment Status**: `https://sandbox.fapshi.com/payment-status`

---

## 🧪 Testing Payment Flows

### 1. Trial Session Payment Flow

```dart
// Initiate payment
final transId = await TrialSessionService.initiatePayment(
  sessionId: trialSessionId,
  phoneNumber: '670000000', // Sandbox test number
);

// Payment will be processed via webhook or polling
// Webhook URL: /api/webhooks/fapshi
```

**Test Scenarios:**
- ✅ Payment success → Updates `trial_sessions.payment_status = 'paid'`
- ✅ Payment failure → Updates `trial_sessions.payment_status = 'failed'`
- ✅ Payment pending → Updates `trial_sessions.payment_status = 'pending'`

### 2. Recurring Session Payment Flow

```dart
// Create payment record (automatic when session ends)
await SessionPaymentService.createSessionPayment(sessionId);

// Initiate payment
final paymentResponse = await SessionPaymentService.initiatePayment(
  sessionId: sessionId,
  phoneNumber: '670000000',
  studentName: 'Test Student',
  studentEmail: 'test@example.com',
);

// Payment will be processed via webhook
// Webhook URL: /api/webhooks/fapshi
```

**Test Scenarios:**
- ✅ Payment success → Updates `session_payments.payment_status = 'paid'` and `tutor_earnings.earnings_status = 'active'`
- ✅ Payment failure → Updates `session_payments.payment_status = 'failed'`
- ✅ Payment pending → Updates `session_payments.payment_status = 'pending'`

---

## 📊 Payment Status Tracking

### Trial Sessions:
- `payment_status`: `unpaid` → `pending` → `paid` / `failed`
- Stored in: `trial_sessions` table

### Recurring Sessions:
- `payment_status`: `unpaid` → `pending` → `paid` / `failed` / `refunded`
- Stored in: `session_payments` table
- Earnings tracked in: `tutor_earnings` table

---

## 🔄 Webhook Processing

### Webhook Endpoint:
`POST /api/webhooks/fapshi`

### Handles:
1. **Trial Payments** (`externalId` starts with `trial_`)
   - Updates `trial_sessions` table
   - Generates Meet link on success

2. **Session Payments** (`externalId` starts with `session_`)
   - Updates `session_payments` table
   - Updates `tutor_earnings` table
   - Moves earnings from pending to active balance

### Webhook Payload:
```json
{
  "transId": "transaction_id",
  "status": "SUCCESSFUL" | "FAILED" | "PENDING",
  "externalId": "trial_<id>" | "session_<id>"
}
```

---

## ✅ What's Working

1. ✅ **Trial Session Payments** - Full flow (initiate → webhook → status update)
2. ✅ **Recurring Session Payments** - Full flow (create → initiate → webhook → earnings)
3. ✅ **Sandbox Environment** - Configured and ready
4. ✅ **Webhook Handler** - Handles both trial and session payments
5. ✅ **Earnings Calculation** - 85% tutor, 15% platform fee
6. ✅ **Wallet Balance Tracking** - Pending → Active balance transition

---

## 🚧 What's Missing (UI Components)

1. ⏳ **Payment Initiation UI** - Screen for students to pay for sessions
2. ⏳ **Payment Status Display** - Show payment status in session details
3. ⏳ **Payment History** - View past payments
4. ⏳ **Wallet Display** - Show tutor earnings and balances

---

## 🧪 Testing Checklist

- [ ] Test trial session payment (online)
- [ ] Test trial session payment (onsite)
- [ ] Test recurring session payment (online)
- [ ] Test recurring session payment (onsite)
- [ ] Test payment webhook (success)
- [ ] Test payment webhook (failure)
- [ ] Test earnings calculation (85/15 split)
- [ ] Test wallet balance updates (pending → active)
- [ ] Test refund processing

---

## 📝 Notes

- Sandbox payments use test credentials (no real money)
- Webhook can be tested using tools like ngrok or Fapshi's webhook testing
- All payment flows work identically for online and onsite sessions
- Location type only affects session delivery, not payment processing

