# How to Test Your SMTP Configuration After Saving

## Step-by-Step Testing Process

### ✅ Step 1: Save Your Configuration

1. Click **"Save changes"** in Supabase SMTP settings
2. Wait for the success message
3. You should see: "SMTP settings updated successfully" or similar

### ✅ Step 2: Send a Test Email

**Option A: Direct Test Button (Preferred)**
1. Look for a **"Send Test Email"** or **"Test"** button on the SMTP settings page
2. It's usually right below the "Save changes" button
3. If you don't see it, scroll down or check the "Email Templates" section
4. Enter your email address (the one you want to test)
5. Click **"Send"** or **"Send Test Email"**

**Option B: Via Your App**
1. Open your PrepSkul app
2. Go to the **Authentication/Signup** screen
3. Try to sign up with email
4. Enter your email and password
5. Submit the form
6. You should receive a confirmation email

### ✅ Step 3: Check Your Inbox

**Where to Look:**
1. **Primary Inbox** - Check within 1-2 minutes
2. **Spam/Junk Folder** - Check if not in inbox
3. **Promotions Tab** (Gmail) - Sometimes ends up here

**What to Look For:**
- ✅ Email arrives (success!)
- ✅ **From:** Shows "PrepSkul" (not "Supabase Auth")
- ✅ **From email:** Shows `info@prepskul.com`
- ✅ Email looks formatted correctly
- ✅ Subject line is branded correctly

### ✅ Step 4: Verify the Sender Name

**Success looks like:**
```
From: PrepSkul
Email: info@prepskul.com
Subject: Welcome to PrepSkul! Confirm your email address
```

**Failure looks like:**
```
From: Supabase Auth
Email: noreply@mail.app.supabase.io
Subject: Confirm your email
```

## 🔍 What If I Don't See a Test Button?

### Alternative Method 1: Email Templates Section

1. Go to **Authentication** → **Email Templates**
2. Click on any template (e.g., "Confirm signup")
3. Look for **"Send a test email"** button
4. This will send a test using your SMTP configuration

### Alternative Method 2: Trigger from App

1. Open your Flutter app
2. Go to **Sign up with email**
3. Create a test account
4. Check if confirmation email arrives

### Alternative Method 3: Check Supabase Logs

1. Go to **Logs** → **Auth Logs** in Supabase
2. Look for recent email sending attempts
3. Check for any errors or success messages

## ✅ Success Indicators

### You'll Know It's Working When:

1. **Test email arrives** within 1-2 minutes ✅
2. **Sender shows "PrepSkul"** (not "Supabase Auth") ✅
3. **From email is** `info@prepskul.com` ✅
4. **Email is formatted** with your branding ✅
5. **No errors** in Supabase logs ✅
6. **Email arrives in inbox** (not just spam) ✅

## ❌ Failure Indicators

### You'll Know It's NOT Working When:

1. **Email doesn't arrive** after 5 minutes ❌
2. **Error message** appears in Supabase ❌
3. **Sender still shows "Supabase Auth"** ❌
4. **From email is** `noreply@mail.app.supabase.io` ❌
5. **"Authentication failed"** error ❌
6. **"Connection timeout"** error ❌

## 🔧 If It Doesn't Work

### Common Issues & Fixes

**1. Email Doesn't Arrive**
- **Check:** Spam folder
- **Check:** Wait 2-3 more minutes
- **Try:** Different email address
- **Solution:** Test button might not be sending to the right address

**2. Still Shows "Supabase Auth"**
- **Check:** Did you set "Sender Name" field?
- **Check:** Go back to SMTP settings and look for "Sender Name"
- **Solution:** This field might be separate from SMTP settings

**3. "Authentication Failed" Error**
- **Check:** Password is correct
- **Check:** Username is `info@prepskul.com` (not just "info")
- **Solution:** Reset password in Hostinger and retry

**4. "Connection Timeout" Error**
- **Check:** Try port 587 instead of 465
- **Check:** Change encryption to STARTTLS
- **Solution:** Some networks block port 465

**5. Email in Spam Folder**
- **Check:** Mark as "Not Spam"
- **Check:** Domain reputation needs time to build
- **Solution:** This is normal for new domains, will improve over time

## 🎯 Quick Test Checklist

After saving SMTP settings:
- [ ] Success message appeared
- [ ] Clicked "Send Test Email" button
- [ ] Entered your email address
- [ ] Waited 1-2 minutes
- [ ] Checked inbox
- [ ] Checked spam folder
- [ ] Verified "From: PrepSkul"
- [ ] Verified email formatting

## 📧 Where to Find Test Button

The "Send Test Email" button can be in different places:

1. **SMTP Settings page** - Below "Save changes" button
2. **Email Templates page** - In each template section
3. **Authentication Overview** - Quick action dropdown
4. **Project Settings** - Advanced features

**If you can't find it**, just trigger a real signup from your app to test!

## 🚀 Next Steps After Success

Once you confirm it's working:

1. ✅ Test with real user signup
2. ✅ Verify all email templates (confirmation, password reset, etc.)
3. ✅ Consider changing password to something stronger
4. ✅ Monitor email delivery rates
5. ✅ Set up email alerts for failures

## ❓ Still Can't Find the Test Button?

**No problem!** Just:

1. Open your PrepSkul app
2. Go to the **email signup screen**
3. Enter any email address
4. Complete the signup
5. Check that email's inbox

This is actually a better test because it's the real user experience!

## 🎉 You're Done!

Once the test email arrives with "From: PrepSkul", your SMTP is configured perfectly!

The authentication system is now fully branded and ready for production! 🚀

