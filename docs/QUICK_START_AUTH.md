# 🚀 Quick Start: Email & Phone Authentication

## ✅ DOES AUTH WORK? **YES!**

Email authentication works immediately. Phone authentication works in test mode.

---

## 🎯 WHAT TO DO IN SUPABASE DASHBOARD

### For Local Development (Do This Now):

#### Email Auth: **NOTHING** ✅
- Already enabled by default
- No configuration needed
- Works immediately

#### Phone Auth: **Enable Test Mode** ⏱️ (2 minutes)

1. Go to **Supabase Dashboard** → Your Project
2. Navigate to **Authentication** → **Providers** → **Phone**
3. Find **"Test mode"** toggle
4. **Turn it ON** ✅
5. Click **Save**

**That's it!** Now phone auth works in development.

---

## 🧪 TESTING NOW

### Test Email Auth:
1. Run your app
2. Complete onboarding
3. Select "Sign up with email"
4. Enter name, email, password
5. Select role
6. Complete survey
7. ✅ Should work!

### Test Phone Auth (Test Mode):
1. Run your app
2. Complete onboarding  
3. Select "Sign up with phone"
4. Enter phone number
5. Use OTP code: **`123456`** (test mode always uses this)
6. Complete survey
7. ✅ Should work!

---

## 📱 FOR PRODUCTION (Later)

### Email Auth:
- ✅ Already ready for production
- (Optional) Enable email verification in settings

### Phone Auth:
You need to set up Twilio:

1. **Create Twilio account** at [twilio.com](https://www.twilio.com)
2. **Get credentials**:
   - Account SID
   - Auth Token
   - Phone number
3. **In Supabase Dashboard**:
   - Go to Authentication → Providers → Phone
   - **Turn OFF** "Test mode" ❌
   - Enter Twilio credentials
   - Save
4. **Test** with real phone numbers

**Cost**: ~$0.0075 per SMS (very cheap)

---

## 🎁 BONUS: Test Phone Numbers

In test mode, you can use these test numbers:

- **US**: `+15005550006`
- **Any**: `+1234567890` (fake numbers work)

**OTP Code**: Always `123456` in test mode

---

## ✅ SUMMARY

| Environment | Email Auth | Phone Auth |
|-------------|-----------|------------|
| **Local** | ✅ Works (no setup) | ✅ Works (enable test mode) |
| **Production** | ✅ Works | ⚠️ Needs Twilio |

---

## 🆘 TROUBLESHOOTING

### "Phone OTP not working"
- ✅ Check test mode is ON
- ✅ Use test number or real number
- ✅ Use OTP: `123456`

### "Email auth not working"
- ✅ Check email not already used
- ✅ Check password is 6+ characters
- ✅ Try different email

### "Profile not created"
- ✅ Check database logs
- ✅ Verify RLS policies
- ✅ Check user is authenticated

---

## 📞 NEXT STEPS

1. **Enable phone test mode** in Supabase (2 min)
2. **Test email auth** (already works)
3. **Test phone auth** (with test mode)
4. **When ready for production**: Set up Twilio

**You're ready to go! 🎉**

See `SUPABASE_AUTH_SETUP.md` for detailed configuration.

