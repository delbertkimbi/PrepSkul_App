# Supabase Authentication Setup Guide

## Overview
This guide explains how to configure Supabase for **both email and phone authentication** to work in **both development and production**.

---

## ✅ EMAIL AUTHENTICATION

### Setup Required: **NONE** (Works out of the box!)

Email authentication is enabled by default in Supabase. **No configuration needed.**

#### For Development:
- ✅ Already working in local development
- ✅ No API keys required
- ✅ No credits needed
- ✅ Users created automatically in `auth.users` table

#### For Production:
1. **Authentication → Email Templates** (Optional customization)
   - Welcome emails
   - Password reset emails
   - Email change notifications

2. **Authentication → Settings → Email Auth**
   - ✅ Enable "Confirm email" (Recommended for production)
   - ✅ Enable "Secure email change"
   - Configure SMTP provider (Optional - for custom emails)

---

## 📱 PHONE AUTHENTICATION (SMS OTP)

### Setup Required: **YES** (API configuration needed)

Phone authentication requires a **Twilio account** or similar SMS provider.

#### For Development:
You have two options:

**Option 1: Use Test Mode (Free)**
1. Go to **Authentication → Providers → Phone**
2. Enable "Test mode"
3. Use default test phone numbers
   - Test OTP code: `123456` (always works)
   - Test phone: `+15005550006` (US number)

**Option 2: Configure Twilio (Production-ready)**
1. Sign up for [Twilio](https://www.twilio.com)
2. Get your Account SID and Auth Token
3. In Supabase Dashboard:
   - **Authentication → Providers → Phone**
   - Enter Twilio credentials
   - Test with real phone numbers

#### For Production:
1. **Create Twilio Account**
   - Sign up at [twilio.com](https://www.twilio.com)
   - Purchase phone number
   - Get Account SID and Auth Token

2. **Configure in Supabase**
   - Go to **Authentication → Providers → Phone**
   - Enter:
     - **Account SID**: Your Twilio Account SID
     - **Auth Token**: Your Twilio Auth Token
     - **Phone Number**: Your Twilio phone number
   - **Disable** "Test mode" checkbox

3. **Costs**
   - Twilio charges per SMS sent
   - ~$0.0075 per message (US/Cameroon)
   - Free tier: 100 credits to start

---

## 🔧 DATABASE TABLES CONFIGURATION

Both email and phone auth users are stored in the same tables.

### Required Tables:

1. **auth.users** (Managed by Supabase)
   - ✅ Automatically created
   - Stores authentication data
   - No manual setup needed

2. **profiles** (Your custom table)
   ```sql
   - id (uuid, primary key, references auth.users.id)
   - email (text, nullable)
   - phone_number (text, nullable)
   - full_name (text)
   - user_type (text) -- 'tutor', 'learner', 'parent'
   - survey_completed (boolean)
   - is_admin (boolean)
   - avatar_url (text, nullable)
   - created_at, updated_at (timestamps)
   ```

### Row-Level Security (RLS) Policies:

Your `profiles` table should have RLS enabled with these policies:

```sql
-- Users can insert their own profile
CREATE POLICY "Users can insert own profile"
ON profiles FOR INSERT
WITH CHECK (auth.uid() = id);

-- Users can view their own profile
CREATE POLICY "Users can view own profile"
ON profiles FOR SELECT
USING (auth.uid() = id);

-- Users can update their own profile
CREATE POLICY "Users can update own profile"
ON profiles FOR UPDATE
USING (auth.uid() = id);

-- Anyone can view public profiles (optional)
CREATE POLICY "Anyone can view public profiles"
ON profiles FOR SELECT
USING (true); -- Or add conditions
```

---

## 🧪 TESTING CHECKLIST

### Email Auth Testing:
- [ ] Sign up with email
- [ ] Login with email
- [ ] Complete survey
- [ ] Verify profile created in database
- [ ] Check email stored correctly

### Phone Auth Testing:
- [ ] Sign up with phone (test mode)
- [ ] Receive OTP code
- [ ] Verify OTP
- [ ] Complete survey
- [ ] Verify profile created in database
- [ ] Check phone number stored correctly

### Tutor Onboarding Testing:
- [ ] Email auth user → Asked for phone in onboarding
- [ ] Phone auth user → Asked for email in onboarding
- [ ] Verify correct contact info saved

---

## 📝 SUPABASE DASHBOARD CONFIGURATION

### Step-by-Step Checklist:

#### 1. Email Auth (No Setup Needed ✅)
- [x] Email provider enabled by default
- [ ] (Optional) Customize email templates
- [ ] (Optional) Configure SMTP for custom sender

#### 2. Phone Auth (Setup Required)
- [ ] Go to Authentication → Providers → Phone
- [ ] Choose Test Mode OR configure Twilio
- [ ] Test with phone number
- [ ] Verify OTP received

#### 3. Database Configuration
- [ ] Verify `profiles` table exists
- [ ] Check RLS policies are enabled
- [ ] Verify `email` and `phone_number` columns exist
- [ ] Test insert/update operations

#### 4. Production Deployment
- [ ] Disable test mode for phone auth
- [ ] Configure real Twilio credentials
- [ ] (Optional) Enable email verification
- [ ] Test in production environment
- [ ] Monitor authentication logs

---

## 🚨 COMMON ISSUES & SOLUTIONS

### Issue: "Email auth not working"
**Solution**: Check if email is already in use in `auth.users` table. Try different email.

### Issue: "Phone OTP not received"
**Solutions**:
1. Check Twilio credits balance
2. Verify phone number format (+237XXXXXXXXX)
3. Check Supabase logs for errors
4. Use test mode for development

### Issue: "Profile not created"
**Solutions**:
1. Check RLS policies allow insert
2. Verify `id` matches `auth.users.id`
3. Check database logs for errors
4. Ensure required fields provided

### Issue: "RLS policy violation"
**Solutions**:
1. Review RLS policies above
2. Ensure `auth.uid()` equals profile `id`
3. Check if user is authenticated
4. Verify policy conditions

---

## 📊 COSTS SUMMARY

| Feature | Development Cost | Production Cost |
|---------|------------------|-----------------|
| **Email Auth** | **FREE** ✅ | **FREE** ✅ |
| **Phone Auth (Test)** | **FREE** ✅ | N/A |
| **Phone Auth (Real)** | Twilio setup | ~$0.0075/SMS |
| **Database** | FREE tier | $25/month (Pro) |
| **Storage** | 1GB free | Based on usage |

---

## 🎯 RECOMMENDED SETUP

### For Development:
- ✅ Use **Email Auth** (no setup)
- ✅ Use **Phone Auth Test Mode** (free)
- ✅ No costs incurred

### For Production:
- ✅ Enable **Email Auth** with verification
- ⚠️ Configure **Twilio for Phone Auth** (~$50 for testing)
- ✅ Monitor SMS costs
- ✅ Set up budget alerts in Twilio

---

## 📞 NEXT STEPS

1. **Test email auth** - Already works, just run the app
2. **Test phone auth in test mode** - Free, no setup needed
3. **When ready for production**:
   - Sign up for Twilio
   - Configure credentials
   - Test with real numbers
   - Monitor costs

**You're all set for development! 🚀**

