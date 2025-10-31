# 📧 Hostinger SMTP Setup for PrepSkul

## Quick Answer

**Your Username for SMTP server:** `info@prepskul.com`

That's it! For Hostinger email accounts, the **username is your full email address**.

---

## Complete Supabase SMTP Configuration

### Step 1: Get Your Hostinger Email Details

1. Log in to **Hostinger hPanel**
2. Go to **Email** → **Email Accounts** (or **Professional Email**)
3. Find your `info@prepskul.com` account
4. Click on **Settings** or **Configure Email**

You should see:
- **Email:** `info@prepskul.com`
- **Password:** The password you set when creating the email

---

### Step 2: Configure SMTP in Supabase

Go to **Supabase Dashboard** → **Authentication** → **Email Templates** → **SMTP Settings**

**Click "Enable Custom SMTP"** and enter:

```
SMTP Host: smtp.hostinger.com
SMTP Port: 587
Encryption: TLS/STARTTLS
Username: info@prepskul.com
Password: [your email account password]
Sender Name: PrepSkul
Reply-To: info@prepskul.com
```

---

### Step 3: Alternative Port (If 587 Doesn't Work)

If port 587 has issues, try SSL on port 465:

```
SMTP Host: smtp.hostinger.com
SMTP Port: 465
Encryption: SSL
Username: info@prepskul.com
Password: [your email account password]
Sender Name: PrepSkul
Reply-To: info@prepskul.com
```

---

## Where to Find Your Email Password

If you forgot your email password:

1. Log into **Hostinger hPanel**
2. Go to **Email** → **Email Accounts**
3. Click on your `info@prepskul.com` account
4. Click **Change Password** or **Reset Password**
5. Set a new secure password

---

## Testing Your Setup

After configuring SMTP:

1. In Supabase, click **"Send a test email"**
2. Enter your personal email address
3. Check if you receive the test email
4. Confirm the "From" name shows **"PrepSkul"** instead of "Supabase Auth"

---

## Troubleshooting

### "Authentication Failed" Error

**Possible causes:**
- Wrong password
- Typo in username (should be `info@prepskul.com`)
- Wrong encryption setting

**Solutions:**
1. Double-check password in hPanel
2. Verify username is the **full email address**
3. Try TLS on port 587 first, then SSL on port 465

### "Connection Timeout" Error

**Possible causes:**
- Wrong SMTP host
- Firewall blocking port

**Solutions:**
1. Use `smtp.hostinger.com` (NOT `mail.hostinger.com`)
2. Try the alternative port/encryption combination
3. Check if your network/firewall allows SMTP ports

### Emails Not Being Delivered

**Possible causes:**
- DNS not fully propagated
- SPF/DKIM records missing

**Solutions:**
1. Wait 24-48 hours for DNS changes to propagate
2. Check Hostinger documentation for email DNS records
3. Verify domain settings in Hostinger control panel

---

## Important Notes

✅ **Username is ALWAYS your full email address** (`info@prepskul.com`)  
✅ **Password is the password for your email account** (NOT your hPanel password)  
✅ **Use TLS on port 587** (most reliable for most hosts)  
✅ **Set Reply-To** to the same address for proper replies  

---

## What This Changes

**Before:**
- From: Supabase Auth `<noreply@mail.app.supabase.io>`
- Looks unprofessional

**After:**
- From: PrepSkul `<info@prepskul.com>`
- Professional, branded emails
- Better deliverability
- Users trust your emails more

---

## Quick Reference Card

```
Host: smtp.hostinger.com
Port: 587 (or 465)
Encryption: TLS (or SSL)
Username: info@prepskul.com
Password: [your email password]
```

---

## Support

If you still have issues:
1. Check Hostinger email documentation
2. Try Hostinger support chat
3. Verify email account is active in hPanel
4. Test email sending from hPanel's webmail interface

---

**That's it!** Once configured, all your Supabase emails will show "PrepSkul" as the sender. 🎉
