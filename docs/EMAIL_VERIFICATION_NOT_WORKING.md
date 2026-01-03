# 🔧 Email Verification Not Working - Diagnostic Guide

## 🚨 **The Problem**
Users are not receiving email verification emails after signing up.

## 📋 **Quick Checklist**

### **1. Check if Email Confirmations are Enabled**
- Go to: **Supabase Dashboard** → **Authentication** → **Providers** → **Email**
- Verify: **"Enable email confirmations"** is **ON** ✅
- If OFF, emails won't be sent (users auto-confirmed)

### **2. Check Supabase Email Service Status**
Supabase uses its own email service by default, which has **very restrictive limits**:
- **Free Tier:** 2 emails/hour per user
- **Pro Tier:** 4 emails/hour per user

**If you hit rate limits:**
- Users won't receive emails
- No error shown (silent failure)
- Check Supabase logs: **Authentication** → **Logs**

### **3. Check if Resend is Configured as SMTP**
**Resend is NOT automatically used for Supabase auth emails!**

You must configure Resend as SMTP in Supabase:

1. **Go to Supabase Dashboard:**
   - https://app.supabase.com
   - Select your project
   - Navigate to: **Authentication** → **Settings** → **SMTP Settings**

2. **Check if Custom SMTP is Enabled:**
   - If **OFF**: Supabase is using its default service (restrictive limits)
   - If **ON**: Check if Resend credentials are correct

3. **Configure Resend SMTP (if not done):**
   - **Enable Custom SMTP:** Toggle ON
   - **SMTP Host:** `smtp.resend.com`
   - **SMTP Port:** `587`
   - **SMTP Username:** `resend`
   - **SMTP Password:** `[Your Resend API Key]` (from Resend dashboard)
   - **Sender Email:** `noreply@mail.prepskul.com`
   - **Sender Name:** `PrepSkul`
   - Click **Save**

### **4. Check Resend Credits**
- Go to: https://resend.com/dashboard
- Check your **usage** and **credits remaining**
- Free tier: 3,000 emails/month
- If credits exhausted, emails won't send

### **5. Check Redirect URLs**
- Go to: **Authentication** → **URL Configuration**
- Verify these URLs are added:
  ```
  prepskul://email-login
  prepskul://
  io.supabase.prepskul://
  https://app.prepskul.com/**
  ```

### **6. Check Email Logs in Supabase**
- Go to: **Authentication** → **Logs**
- Look for email sending attempts
- Check for errors or rate limit messages

## 🔍 **How to Diagnose**

### **Test 1: Check if Email is Being Sent**
1. Sign up with a test email
2. Check Supabase logs: **Authentication** → **Logs**
3. Look for "Email sent" or error messages

### **Test 2: Check Resend Dashboard**
1. Go to: https://resend.com/dashboard
2. Check **Activity** tab
3. See if emails are being sent
4. Check for errors or bounces

### **Test 3: Check Supabase SMTP Configuration**
1. Go to: **Authentication** → **Settings** → **SMTP Settings**
2. Verify Custom SMTP is enabled
3. Test SMTP connection (if available)

## ✅ **Most Likely Causes**

### **Cause 1: Resend Not Configured as SMTP** (90% likely)
- **Symptom:** No emails received, no errors shown
- **Solution:** Configure Resend as SMTP in Supabase (see step 3 above)

### **Cause 2: Supabase Rate Limits Hit** (5% likely)
- **Symptom:** First email works, subsequent emails don't
- **Solution:** Configure Resend as SMTP to bypass limits

### **Cause 3: Email Confirmations Disabled** (3% likely)
- **Symptom:** Users auto-confirmed, no email sent
- **Solution:** Enable email confirmations in Supabase

### **Cause 4: Resend Credits Exhausted** (2% likely)
- **Symptom:** Emails stop working suddenly
- **Solution:** Check Resend dashboard, upgrade plan if needed

## 🚀 **Recommended Fix**

**Configure Resend as SMTP in Supabase:**

1. Get Resend API Key from: https://resend.com/api-keys
2. Go to Supabase → **Authentication** → **Settings** → **SMTP Settings**
3. Enable Custom SMTP
4. Enter Resend credentials:
   - Host: `smtp.resend.com`
   - Port: `587`
   - Username: `resend`
   - Password: `[Your Resend API Key]`
5. Save

**This will make ALL Supabase auth emails (signup, password reset, etc.) use Resend instead of Supabase's restrictive default service.**

## 📊 **Current Email Architecture**

- **Supabase Auth Emails** (signup, password reset):
  - Uses Supabase's email service OR Custom SMTP (Resend)
  - **NOT** using Resend API directly
  - Must configure Resend as SMTP to use Resend

- **Custom Notifications** (bookings, payments):
  - Uses Resend API directly (Next.js backend)
  - Already configured ✅

## ⚠️ **Important Notes**

1. **Resend API ≠ Resend SMTP**
   - Resend API: Used for custom emails (already working)
   - Resend SMTP: Must be configured in Supabase for auth emails

2. **Supabase Default Email Service**
   - Very restrictive (2-4 emails/hour per user)
   - No credits to exhaust, but rate limits are strict
   - Not recommended for production

3. **Email Confirmations Setting**
   - If disabled: No emails sent, users auto-confirmed
   - If enabled: Emails sent (if SMTP configured)

## 🧪 **Testing After Fix**

1. Sign up with a test email
2. Check inbox (and spam folder)
3. Verify email is from `noreply@mail.prepskul.com` (if Resend configured)
4. Click verification link
5. Should auto-login and navigate to app











