# Twilio Setup for PrepSkul - Quick Guide

## Step 1: Create Twilio Account (2 minutes)

1. **Go to**: https://www.twilio.com/try-twilio
2. **Sign up** with: delbertdrums5@gmail.com
3. **Verify** your email and phone number
4. You'll get **$15 FREE credits** automatically! 🎉

---

## Step 2: Get Your Credentials (1 minute)

Once logged in, you'll see your Twilio Console Dashboard.

**Copy these 3 things:**

1. **Account SID**: 
   - Looks like: `ACxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx`
   - Found on dashboard homepage

2. **Auth Token**: 
   - Click "Show" to reveal
   - Looks like: `xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx`
   - Found below Account SID

3. **Phone Number** (if you got one):
   - Format: `+1XXXXXXXXXX` (US number)
   - Or: `+237XXXXXXXXX` (Cameroon number if available)

**Screenshot where to find them:**
```
┌─────────────────────────────────────────┐
│ Twilio Console                          │
├─────────────────────────────────────────┤
│                                         │
│ Account SID:  ACxxxxxxxxxxxx  [Copy]   │
│ Auth Token:   **************** [Show]  │
│                                         │
│ Phone Numbers:                          │
│   +1234567890                           │
│                                         │
└─────────────────────────────────────────┘
```

---

## Step 3: Buy a Phone Number (2 minutes)

### Option A: US Number (Recommended - Works globally)
1. Go to: **Phone Numbers** → **Manage** → **Buy a number**
2. Select **United States** (+1)
3. Check **SMS** capability
4. Click **Search**
5. Choose any number (usually $1.15/month)
6. Click **Buy**

**Cost**: ~$1.15/month + SMS usage

### Option B: Cameroon Number (Best for local users)
1. Same process but select **Cameroon** (+237)
2. May not be available - US number works fine too!

**Which to choose?**
- **US number**: Works everywhere, available immediately
- **Cameroon number**: Better trust with local users, may not be available

**My recommendation**: Get a US number for now. You can add a Cameroon number later.

---

## Step 4: Configure Supabase (3 minutes)

### A. Go to Supabase Dashboard
1. Visit: https://supabase.com/dashboard
2. Select your project
3. Go to: **Authentication** → **Providers**
4. Click on **"Phone"**

### B. Enable Phone Authentication
Toggle **"Enable Phone Sign-in"** to **ON**

### C. Add Twilio Credentials
Scroll down to find these fields:

```
┌─────────────────────────────────────────────────────┐
│ Phone Auth Provider Settings                        │
├─────────────────────────────────────────────────────┤
│                                                     │
│ Twilio Account SID:                                 │
│ ┌─────────────────────────────────────────────┐   │
│ │ ACxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx          │   │
│ └─────────────────────────────────────────────┘   │
│                                                     │
│ Twilio Auth Token:                                  │
│ ┌─────────────────────────────────────────────┐   │
│ │ xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx            │   │
│ └─────────────────────────────────────────────┘   │
│                                                     │
│ ☐ Enable test OTP                                  │
│   (Uncheck this for production!)                   │
│                                                     │
└─────────────────────────────────────────────────────┘
```

**Important**: Uncheck **"Enable test OTP"** for production!

### D. Optional: Customize SMS Template
```
Your PrepSkul verification code is: {{ .Code }}

Valid for 10 minutes.
```

### E. Configure Rate Limiting
Recommended settings:
- **Max OTP requests per hour**: 5
- **OTP expiry time**: 10 minutes

### F. Save Settings
Click **"Save"** at the bottom

---

## Step 5: Test Production Setup (2 minutes)

### A. Redeploy Your Web App
```bash
cd /Users/user/Desktop/PrepSkul/prepskul_app
flutter build web --release
firebase deploy --only hosting
```

### B. Test with Real Number
1. Go to: https://operating-axis-420213.web.app
2. Click "Sign Up" or "Login"
3. Enter your real Cameroon number: `+237XXXXXXXXX`
4. Click "Send OTP"
5. **Check your phone for REAL SMS!** 📱
6. Enter the code you received
7. Should login successfully! ✅

### C. Check Twilio Logs
1. Go to Twilio Console
2. **Monitor** → **Logs** → **Messages**
3. You should see your SMS delivery status
4. Check the cost (should be ~$0.045)

---

## Troubleshooting

### "No SMS received"
**Possible causes:**
1. Phone number format wrong (must include +237)
2. Network issue (check MTN/Orange signal)
3. Twilio account needs verification
4. Credits depleted

**Solutions:**
- Verify number format: `+237670123456`
- Check Twilio logs for delivery status
- Try a different phone number
- Check Twilio account balance

### "Twilio error: Invalid credentials"
- Double-check Account SID (starts with AC)
- Verify Auth Token (no extra spaces)
- Make sure you clicked "Save" in Supabase

### "Rate limit exceeded"
- Wait 1 hour before trying again
- Or increase rate limit in Supabase settings

---

## Cost Breakdown

### With $15 Free Credits:

**SMS Costs (Cameroon)**:
- MTN Cameroon: ~$0.045 per SMS
- Orange Cameroon: ~$0.045 per SMS

**Your $15 covers:**
- ~333 SMS messages
- Or ~166 users (2 SMS per user: signup + forgot password)

**Phone Number**:
- US number: $1.15/month (deducted from credits)
- First month: $1.15, leaves you $13.85 in credits
- **~308 SMS messages remaining**

### After $15, with $100 Budget:

- **$100 = ~2,200 SMS messages**
- **= ~1,100 user signups**
- **= Enough for MVP launch!**

---

## Production Checklist

Before going live, make sure:

### Twilio
- [x] Account created
- [ ] $15 free credits activated
- [ ] Phone number purchased
- [ ] SMS capability enabled
- [ ] Usage alerts set ($5, $10, $15)

### Supabase
- [ ] Twilio credentials added
- [ ] Test OTP **disabled**
- [ ] Rate limiting enabled (5/hour)
- [ ] SMS template customized
- [ ] Settings saved

### App
- [ ] Web app redeployed
- [ ] Tested with real Cameroon number
- [ ] OTP received and verified
- [ ] Login successful

---

## Next Steps After Setup

1. **Monitor Usage**
   - Check Twilio daily for first week
   - Set up alerts at $5, $10, $15
   - Track cost per user

2. **Optimize Costs**
   - Increase OTP expiry (10 min → 15 min)
   - Add rate limiting (prevent abuse)
   - Consider Africa's Talking if costs too high

3. **Scale Up**
   - When $15 runs out, add $100
   - Monitor usage patterns
   - Adjust rate limits as needed

---

## Quick Commands

### Redeploy after Twilio setup:
```bash
cd /Users/user/Desktop/PrepSkul/prepskul_app
flutter build web --release
firebase deploy --only hosting
```

### Check deployment:
```bash
open https://operating-axis-420213.web.app
```

### Test with real number:
- Format: `+237670123456`
- Wait for SMS (5-30 seconds)
- Enter 6-digit code received

---

## Ready to Start?

Follow the steps above in order:
1. Create Twilio account (get $15 free!)
2. Copy Account SID + Auth Token
3. Buy phone number ($1.15)
4. Add credentials to Supabase
5. Redeploy app
6. Test with your real number!

**Total time**: ~10 minutes
**Total cost**: $0 (using free credits)

Let me know when you're done with each step! 🚀

