# Supabase Phone Auth Production Setup (Twilio)

## Current Status
✅ **Development**: Using Supabase test OTP (123456 for any number)
⏳ **Production**: Need Twilio configuration for real SMS

---

## Why Twilio?

Supabase uses Twilio for SMS delivery in production:
- ✅ Reliable delivery in Cameroon
- ✅ Competitive pricing (~$0.01/SMS)
- ✅ Works with MTN, Orange Cameroon
- ✅ Easy integration with Supabase

---

## Step-by-Step Setup

### Phase 1: Get Twilio Credentials

#### 1. Create Twilio Account
1. Go to: https://www.twilio.com/try-twilio
2. Sign up with your email
3. Verify your email and phone number

#### 2. Get Your Credentials
Once logged in, you'll see on the dashboard:
```
Account SID: ACxxxxxxxxxxxxxxxxxxxxxxxxxx
Auth Token: xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
```

#### 3. Get a Phone Number
1. In Twilio Console, go to: **Phone Numbers** → **Manage** → **Buy a number**
2. Select **Cameroon (+237)** for best local delivery
3. Enable **SMS** capability
4. Buy the number (usually $1-2/month)

**Alternative**: Use a US number if Cameroon numbers are not available (works fine, just shows international number)

---

### Phase 2: Configure Supabase

#### 1. Go to Supabase Dashboard
https://supabase.com/dashboard/project/YOUR_PROJECT_ID/auth/providers

#### 2. Enable Phone Provider
1. Click on **"Phone"** in Authentication Providers
2. Toggle **"Enable Phone Sign-in"** to ON

#### 3. Add Twilio Credentials
Scroll down to **"Phone Auth Provider Settings"**:

```
Twilio Account SID: [Paste your Account SID]
Twilio Auth Token: [Paste your Auth Token]
Twilio Message Service SID: [Optional - for better delivery]
```

#### 4. Configure SMS Template (Optional)
Customize your OTP message:
```
Your PrepSkul verification code is: {{ .Code }}
```

#### 5. Set Rate Limiting
Recommended settings:
- **Max OTPs per hour**: 3-5 (prevent abuse)
- **OTP expiry**: 5 minutes
- **Allow test OTP**: Disable for production

#### 6. Save Settings
Click **"Save"** at the bottom

---

### Phase 3: Update Your Flutter App

#### No Code Changes Needed! 🎉

Your existing code already works because you're using Supabase auth:

```dart
// This code works for both test and production!
await supabase.auth.signInWithOtp(
  phone: '+237XXXXXXXXX',
);
```

The only difference:
- **Before**: Supabase sends test OTP (123456)
- **After**: Supabase uses Twilio to send real OTP

---

### Phase 4: Testing

#### 1. Disable Test OTP
In Supabase Dashboard → Auth → Phone:
- Uncheck **"Enable test OTP"**
- Save

#### 2. Test with Real Number
```dart
// Try with your real Cameroon number
await supabase.auth.signInWithOtp(
  phone: '+237670000000',  // Your real number
);
```

#### 3. Check Twilio Logs
Go to Twilio Console → Monitor → Logs → Messages
- See delivery status
- Check costs
- Debug any issues

---

## Cost Estimates

### Twilio Pricing (Cameroon)
- **SMS to MTN Cameroon**: ~$0.045 per message
- **SMS to Orange Cameroon**: ~$0.045 per message
- **Phone number rental**: ~$1.50/month

### Monthly Cost Example
If you have **1,000 sign-ups/month**:
- 1,000 users × $0.045 = **$45/month**
- Plus phone rental: **$1.50/month**
- **Total: ~$46.50/month**

### Tips to Reduce Costs
1. **Rate limit OTP requests** (max 3 per hour per number)
2. **Longer OTP expiry** (10 min instead of 5 min = fewer resends)
3. **Use email for web** (free alternative)
4. **Cache verified numbers** (don't reverify too often)

---

## Alternative: Cheaper SMS Providers

If Twilio is too expensive for Cameroon, you can use:

### 1. Africa's Talking
- Website: https://africastalking.com
- **Much cheaper** for African countries
- Better delivery rates in Cameroon
- ~$0.01-0.02 per SMS

**How to integrate with Supabase:**
- Use Supabase Edge Functions
- Call Africa's Talking API directly
- Handle OTP generation yourself

### 2. Termii
- Website: https://termii.com
- Good for West African countries
- Competitive pricing

---

## Production Checklist

Before going live:

### Supabase Configuration
- [ ] Twilio credentials added
- [ ] Test OTP disabled
- [ ] Rate limiting enabled (3-5 per hour)
- [ ] OTP expiry set (5-10 minutes)
- [ ] SMS template customized with "PrepSkul"

### Twilio Configuration
- [ ] Cameroon phone number purchased (or US number)
- [ ] SMS capability enabled
- [ ] Billing configured (add credit card)
- [ ] Alert thresholds set (get notified at $20, $50, etc.)

### App Testing
- [ ] Test with real Cameroon MTN number
- [ ] Test with Orange Cameroon number
- [ ] Test rate limiting (try 5+ requests)
- [ ] Test on web (deployed version)
- [ ] Check Twilio logs for delivery

### Monitoring
- [ ] Set up Twilio usage alerts
- [ ] Monitor Supabase auth logs
- [ ] Track OTP success rate
- [ ] Monitor costs daily initially

---

## Quick Start Commands

### 1. Test Current Setup (Development)
```dart
// Should work with test OTP (123456)
await supabase.auth.signInWithOtp(
  phone: '+237670000000',
);
// Enter: 123456
```

### 2. Switch to Production
1. Add Twilio credentials in Supabase
2. Disable "Enable test OTP"
3. Save
4. Redeploy web app:
```bash
cd /Users/user/Desktop/PrepSkul/prepskul_app
flutter build web --release
firebase deploy --only hosting
```

### 3. Test Production
```dart
// Should send REAL SMS via Twilio
await supabase.auth.signInWithOtp(
  phone: '+237670000000',  // Your real number
);
// Wait for real SMS, enter the code
```

---

## Troubleshooting

### "Phone number not supported"
- Check format: Must be +237XXXXXXXXX (with +237)
- Verify Twilio has Cameroon enabled
- Try with a different number

### "SMS not delivered"
- Check Twilio logs for delivery status
- Verify phone number is active
- Check network connectivity (MTN/Orange)
- Try resending OTP

### "Twilio error: Invalid credentials"
- Double-check Account SID and Auth Token
- Make sure there are no extra spaces
- Verify Twilio account is active

### "Too expensive"
- Consider Africa's Talking instead
- Use email auth for web
- Implement "Sign in with Google" as alternative

---

## Recommended Approach for PrepSkul

### For MVP Launch:

**Option A: Hybrid Auth (Best for cost control)**
1. **Web users**: Email/Password (FREE)
2. **Mobile users**: Phone OTP with Twilio
3. **Estimated cost**: ~$20-30/month for 500 mobile users

**Option B: Africa's Talking (Cheaper for scale)**
1. Better pricing for Cameroon
2. Requires custom integration (I can help)
3. **Estimated cost**: ~$10-15/month for 500 users

**Option C: Keep Test Mode Longer**
1. Use test OTP (123456) for MVP testing
2. Switch to production after validating user demand
3. No cost until you're ready

---

## What I Recommend

For your **app.prepskul.com** web deployment:

1. **For now**: Keep test OTP enabled
   - Test with real users
   - Validate demand
   - No SMS costs

2. **After 50-100 sign-ups**: Switch to Twilio
   - Add Twilio credentials
   - Disable test OTP
   - Start with $20 budget

3. **After 500 users**: Consider Africa's Talking
   - Much cheaper for scale
   - Better for Cameroon market

---

## Need Help?

I can help you:
1. ✅ Set up Twilio account
2. ✅ Configure Supabase with Twilio
3. ✅ Implement Africa's Talking (cheaper alternative)
4. ✅ Add email auth for web users
5. ✅ Test the production setup

**What would you like to do?**

- **Option 1**: Keep test OTP for now, switch to Twilio later when ready
- **Option 2**: Set up Twilio now for production
- **Option 3**: Implement Africa's Talking (cheaper)
- **Option 4**: Use email auth for web, phone for mobile

Let me know! 🚀

