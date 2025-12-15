# SMTP Submission Checklist

## ✅ Your Current Configuration Looks Good!

You have:
```
Host: smtp.hostinger.com
Port: 465
Username: info@prepskul.com
Password: Prepskul123#
Minimum interval: 60 seconds
```

## 🔍 Before Submitting - Check These

### 1. Encryption Setting
**IMPORTANT:** Port 465 requires **SSL**, not STARTTLS

- ✅ Port **465** = Use **SSL** encryption
- ❌ Port **465** ≠ Use **STARTTLS** (will fail)

**If Supabase doesn't have an SSL/STARTTLS dropdown:**
- The system might auto-detect from the port
- Supabase should automatically use SSL for port 465

### 2. Sender Name
Look for an additional field:
- **"Sender Name"** or **"From Name"** or **"Display Name"**
- Set it to: `PrepSkul`
- This is what users will see instead of "Supabase Auth"

**If you don't see this field:**
- It might be set in the email templates section instead
- Or it might use the email by default
- Check if there's a "Configure" or "Advanced" option

### 3. Reply-To Address
Check if there's a:
- **"Reply-To"** field
- Set it to: `info@prepskul.com`
- This ensures replies come to your business email

## 📧 After Submitting - Test Immediately

### Step 1: Send Test Email
1. Click **"Save changes"**
2. Look for a **"Send Test Email"** or **"Test"** button
3. Enter your email address
4. Click **Send**

### Step 2: Check Your Email
Look for:
- ✅ Email arrives within 1-2 minutes
- ✅ From: **PrepSkul** (not "Supabase Auth")
- ✅ From email: info@prepskul.com
- ✅ Email looks properly formatted
- ✅ No errors in your inbox

### Step 3: Check Spam Folder
- If email doesn't arrive, check spam
- If in spam, mark as "Not Spam"
- Domain reputation builds over time

## ⚠️ If Submission Fails

### Error: "Authentication Failed"
**Possible causes:**
1. Wrong password
   - Solution: Reset password in Hostinger and retry
2. Wrong username format
   - Solution: Use full email `info@prepskul.com` (not just "info")
3. Account locked
   - Solution: Log into Hostinger email and unlock

### Error: "Connection Timed Out"
**Possible causes:**
1. Port blocked by firewall
   - Solution: Try port 587 instead with STARTTLS
2. Wrong hostname
   - Solution: Verify `smtp.hostinger.com` is correct

### Error: "SSL/TLS Error"
**Possible causes:**
1. Wrong encryption setting
   - Solution: Port 465 MUST use SSL
2. Server doesn't support SSL on 465
   - Solution: Try port 587 with STARTTLS

## 🎯 Recommended Next Steps

### For Production
1. Create dedicated email: `noreply@prepskul.com`
2. Use that for SMTP instead of `info@`
3. Benefits:
   - ✅ Separates business from automated emails
   - ✅ Easier to track email quotas
   - ✅ Better organization

### Security
1. Change password to something stronger
   - Use at least 16 characters
   - Mix of uppercase, lowercase, numbers, symbols
   - Don't use "Prepskul123#" (it's too simple!)
2. Enable 2FA on Hostinger account
3. Monitor email usage

## ✅ Submission Ready Checklist

Before clicking "Save changes":
- [ ] Host: `smtp.hostinger.com` ✓
- [ ] Port: `465` ✓
- [ ] Username: `info@prepskul.com` ✓
- [ ] Password: Entered correctly ✓
- [ ] Encryption: SSL (auto for port 465) ✓
- [ ] Sender Name: `PrepSkul` (check if field exists)
- [ ] Reply-To: `info@prepskul.com` (check if field exists)
- [ ] Minimum interval: `60` seconds ✓

After clicking "Save changes":
- [ ] Click "Send Test Email" immediately
- [ ] Check inbox within 2 minutes
- [ ] Verify "From: PrepSkul" appears
- [ ] Check spam folder if not arrived
- [ ] Report any errors

## 🚨 ONE THING TO CHANGE

**Your password `Prepskul123#` is WEAK**

Consider changing it to something stronger after testing:
- Minimum 16 characters
- Random, not dictionary words
- Mix of characters: `Ab3$kL9mP2xQ8wR5#n`

But first, **TEST with current password** to make sure everything works, then you can change it.

## ✨ You're Ready to Submit!

Your configuration looks correct. The most important thing is checking if Supabase has fields for:
1. **Sender Name** (to show "PrepSkul")
2. **Reply-To** (optional but good to have)

**GO AHEAD AND CLICK "SAVE CHANGES"!** 🚀

Then immediately send a test email to verify everything works.

