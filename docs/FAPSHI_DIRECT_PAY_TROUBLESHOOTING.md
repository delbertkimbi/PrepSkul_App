# Fapshi Direct Pay Troubleshooting Guide

## Issue: Payment Fails Immediately / No Phone Notification

### Root Causes

1. **Direct Pay Not Enabled in Production** (MOST LIKELY)
   - Direct Pay is **disabled by default** in Fapshi's live environment
   - You must contact Fapshi support to enable it
   - **Solution**: Email support@fapshi.com with your API User to request Direct Pay activation

2. **Phone Number Format Issues**
   - Phone number must be in format: `67XXXXXXX` or `69XXXXXXX` (9 digits)
   - No country code prefix needed
   - **Solution**: Ensure phone number is normalized correctly

3. **Payment Status Handling**
   - Initial status can be `CREATED` (not just `PENDING`)
   - Code now handles both `CREATED` and `PENDING` as pending states
   - **Solution**: Fixed in latest code update

### How to Check if Direct Pay is Enabled

1. **Check Fapshi Dashboard**
   - Log into your Fapshi dashboard
   - Go to your service settings
   - Look for "Direct Pay" or "Direct Payment" option
   - If it's disabled/grayed out, you need to request activation

2. **Test with Sandbox**
   - Switch to sandbox environment
   - Test with sandbox test numbers (670000000, 690000000)
   - If it works in sandbox but not production, Direct Pay is likely not enabled

3. **Check API Response**
   - Look for error messages containing "direct pay", "disabled", "not enabled"
   - These indicate Direct Pay is not activated

### Steps to Enable Direct Pay

1. **Contact Fapshi Support**
   - Email: support@fapshi.com
   - Subject: "Request to Enable Direct Pay for Production"
   - Include:
     - Your API User
     - Your service name
     - Reason for needing Direct Pay

2. **Wait for Activation**
   - Fapshi will review and activate Direct Pay
   - You'll receive confirmation email
   - Test immediately after activation

3. **Verify Activation**
   - Test with a small amount (minimum 100 XAF)
   - Use a real phone number
   - Check if you receive payment notification

### Testing Direct Pay

**Sandbox Test Numbers:**
- Success: `670000000`, `670000002`, `650000000` (MTN)
- Success: `690000000`, `690000002`, `656000000` (Orange)
- Failure: `670000001`, `670000003`, `650000001` (MTN)
- Failure: `690000001`, `690000003`, `656000001` (Orange)

**Production:**
- Use real phone numbers
- User will receive payment request on their phone
- User must approve payment in their mobile money app

### Common Error Messages

1. **"Direct Pay is not enabled"**
   - **Solution**: Contact Fapshi support to enable

2. **"Invalid phone number"**
   - **Solution**: Ensure phone is 9 digits, starting with 67, 69, 65, or 66

3. **"Payment failed immediately"**
   - **Solution**: Check if Direct Pay is enabled, verify phone number format

4. **"No notification received"**
   - **Solution**: 
     - Verify Direct Pay is enabled
     - Check phone number is correct
     - Ensure user has mobile money account active
     - Check if user's mobile money app is working

### Payment Status Flow

1. **CREATED** → Payment request sent, waiting for user action
2. **PENDING** → User is processing payment
3. **SUCCESSFUL** → Payment completed
4. **FAILED** → Payment failed (user rejected or network error)
5. **EXPIRED** → Payment link expired (only for initiate-pay, not direct-pay)

### Important Notes

- **Direct Pay transactions do NOT expire** (unlike initiate-pay)
- Final state is either SUCCESSFUL or FAILED
- User must approve payment in their mobile money app
- Payment can take 1-5 minutes to process
- Webhook will be called when status changes

### Verification Checklist

- [ ] Direct Pay enabled in Fapshi dashboard
- [ ] Using correct API credentials (production vs sandbox)
- [ ] Phone number format is correct (9 digits, no country code)
- [ ] User has active mobile money account
- [ ] Webhook URL is configured in Fapshi dashboard
- [ ] Webhook URL is publicly accessible (not localhost)
- [ ] Payment amount is at least 100 XAF

