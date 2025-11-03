# 🔑 Password Reset Email Setup Guide

## ❌ **Problem:**
Password reset emails are not being sent from Supabase.

## ✅ **Solution:**

### **Step 1: Configure Supabase Email Template**

1. **Go to Supabase Dashboard:**
   - https://app.supabase.com
   - Select your project: **PrepSkul**
   - Navigate to: **Authentication** → **Email Templates**

2. **Select "Reset Password" Template**

3. **Copy the Template:**
   - Open: `SUPABASE_PASSWORD_RESET_TEMPLATE.html`
   - Copy ALL content (Cmd+A, Cmd+C)

4. **Paste in Supabase:**
   - Delete existing template
   - Paste the new branded template
   - Click **Save**

---

### **Step 2: Check Supabase Email Settings**

1. **Go to:** **Authentication** → **Settings** → **Email Auth**

2. **Verify These Settings:**
   - ✅ **Enable Email Signup** should be ON
   - ✅ **Enable Email Confirmation** (can be OFF for testing)
   - ✅ **Secure Email Change** (optional)

3. **Check Rate Limits:**
   - **Max emails per hour:** Should be at least 5-10
   - If you hit rate limits, wait 10-15 minutes

---

### **Step 3: Verify Redirect URLs**

1. **Go to:** **Authentication** → **URL Configuration**

2. **Site URL:**
   ```
   https://app.prepskul.com
   ```
   (Your production web app URL)

3. **Redirect URLs (add ALL of these - one per line):**
   ```
   https://app.prepskul.com/**
   https://operating-axis-420213.web.app/**
   http://localhost:*
   io.supabase.prepskul://login-callback/**
   io.supabase.prepskul://**
   ```
   
   **Important Notes:**
   - ✅ Add `https://app.prepskul.com/**` for your production web app
   - ✅ Add `https://operating-axis-420213.web.app/**` for Firebase hosting (if still using)
   - ✅ Add `io.supabase.prepskul://**` for mobile app deep links
   - ✅ The `**` wildcard allows all paths under that domain
   - ✅ Each URL should be on a separate line

---

### **Step 4: Check Email Provider Settings**

If emails still don't arrive:

1. **Check Supabase Email Logs:**
   - Go to: **Authentication** → **Logs**
   - Look for failed email attempts
   - Check error messages

2. **Verify Email Address:**
   - Make sure the email exists in your database
   - Try a different email address

3. **Check Spam/Junk Folder:**
   - Some email providers block Supabase emails
   - Check spam folder
   - Wait 1-5 minutes (email delivery delay)

---

### **Step 5: Test in Development**

1. **Try sending password reset:**
   - Enter a valid email address
   - Click "Send Reset Link"
   - Check browser console (F12) for debug logs:
     ```
     🔍 [DEBUG] Sending password reset email to: ...
     🔍 [DEBUG] Using redirect URL: ...
     ✅ Password reset email sent successfully to: ...
     ```

2. **If you see errors:**
   - Copy the error message
   - Check what it says (rate limit, user not found, etc.)

---

### **Step 6: Verify Email Template Variables**

Make sure the template uses:
- `{{ .ConfirmationURL }}` for the reset link (NOT `{{ .Token }}`)

---

## 🐛 **Common Issues:**

### **1. Rate Limiting:**
**Error:** `email rate limit exceeded`  
**Solution:** Wait 10-15 minutes, then try again

### **2. User Not Found:**
**Error:** `No account found with this email address`  
**Solution:** Make sure the email exists in your `auth.users` table

### **3. Email Template Not Saved:**
**Symptom:** Default Supabase email appears  
**Solution:** Make sure you clicked "Save" after pasting the template

### **4. Redirect URL Mismatch:**
**Error:** Link doesn't work when clicked  
**Solution:** Add your redirect URLs in Supabase dashboard

---

## 📧 **Email Subject Line:**

In Supabase Email Templates, set the **Subject** to:
```
Reset your PrepSkul password
```

---

## ✅ **Testing Checklist:**

- [ ] Template saved in Supabase dashboard
- [ ] Email auth enabled in Supabase settings
- [ ] Redirect URLs configured
- [ ] Valid email address tested
- [ ] Checked spam folder
- [ ] Waited 1-5 minutes for delivery
- [ ] Checked browser console for errors
- [ ] Verified email exists in database

---

## 🔍 **Debug Logs:**

The app now shows debug logs when sending:
```
🔍 [DEBUG] Sending password reset email to: user@example.com
🔍 [DEBUG] Using redirect URL: https://operating-axis-420213.web.app/
✅ Password reset email sent successfully to: user@example.com
```

If you see errors, copy them and check the error message.

---

**That's it! Your password reset emails should now work! 🎉**

