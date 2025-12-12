# Hostinger SMTP Setup for PrepSkul

## Your Email Account
- **Email:** `info@prepskul.com`
- **Domain:** `prepskul.com`
- **Hosting:** Hostinger

## Hostinger SMTP Configuration

### SMTP Settings for Supabase
```
SMTP Host: smtp.hostinger.com
SMTP Port: 587 (TLS/STARTTLS) OR 465 (SSL)
Encryption: STARTTLS (for port 587) OR SSL (for port 465)
SMTP Username: info@prepskul.com
SMTP Password: [Your Hostinger email password]
Sender Name: PrepSkul
Reply-To: info@prepskul.com
```

### Recommended Configuration (Most Compatible)
```
SMTP Host: smtp.hostinger.com
SMTP Port: 587
Encryption: STARTTLS
SMTP Username: info@prepskul.com
SMTP Password: [Your Hostinger email password]
Sender Name: PrepSkul
Reply-To: info@prepskul.com
```

## How to Configure in Supabase

1. **Go to Supabase Dashboard**
   - Navigate to your PrepSkul project
   - Click **Authentication** in the left sidebar
   - Click **Email Templates**

2. **Find SMTP Settings**
   - Scroll down to the **SMTP Settings** section
   - Click **Configure Custom SMTP** or **Edit SMTP Settings**

3. **Enter Your Details**
   ```
   SMTP Host: smtp.hostinger.com
   Port: 587
   Username: info@prepskul.com
   Password: [Enter your Hostinger email password]
   Encryption: STARTTLS
   Sender Name: PrepSkul
   Reply-To: info@prepskul.com
   ```

4. **Save & Test**
   - Click **Save** or **Update**
   - Use the "Send Test Email" button to verify it works
   - Check that the sender appears as "PrepSkul" instead of "Supabase Auth"

## How to Find Your SMTP Password

### Option 1: Use Your Hostinger Email Password
- Log into **Hostinger Control Panel** (hpanel.hostinger.com)
- Go to **Email Accounts**
- Find `info@prepskul.com`
- Your password is the one you set when creating the email

### Option 2: Reset Your Email Password (If Needed)
1. Log into **Hostinger Control Panel**
2. Go to **Email** → **Email Accounts**
3. Find `info@prepskul.com`
4. Click **Manage** or **Change Password**
5. Set a new password
6. Copy it carefully (use a secure password!)

### Option 3: Create a Dedicated SMTP Account (Recommended)
**For Production:** Create a separate email account just for app emails:

1. In Hostinger Control Panel:
   - Go to **Email** → **Email Accounts**
   - Click **Create Email Account**
   - Create: `noreply@prepskul.com`
   - Set a strong password
   - Save the credentials

2. Use This in Supabase:
   ```
   SMTP Username: noreply@prepskul.com
   Password: [Your new password]
   Sender Name: PrepSkul
   Reply-To: info@prepskul.com
   ```

**Benefits:**
- ✅ Separates app emails from business emails
- ✅ Easier to manage email quotas
- ✅ Clear distinction between automated and manual emails
- ✅ Better security isolation

## Testing Your Setup

### Test in Supabase
1. After configuring SMTP, click **Send a Test Email**
2. Enter your email address
3. Check your inbox
4. Verify:
   - ✅ Email arrives successfully
   - ✅ Sender shows as "PrepSkul" (not "Supabase Auth")
   - ✅ From address is `info@prepskul.com`
   - ✅ Email looks branded and professional

### Test in Your App
1. Trigger email authentication in your app
2. Sign up with email
3. Check the confirmation email
4. Verify branding and sender name

## Troubleshooting

### "Authentication Failed" Error
**Problem:** Wrong username or password

**Solution:**
1. Double-check your email password in Hostinger
2. Make sure you're using `info@prepskul.com` as username (not just "info")
3. Try resetting the password and re-entering

### "Connection Timed Out" Error
**Problem:** Firewall or port blocking

**Solution:**
1. Try port **465** with **SSL** instead of 587
2. Check Hostinger firewall settings
3. Verify your domain DNS is correctly configured

### "SSL/TLS Error"
**Problem:** Wrong encryption setting

**Solution:**
- If using port **587**: Set encryption to **STARTTLS**
- If using port **465**: Set encryption to **SSL**

### Emails Not Delivering
**Possible Causes:**
1. DNS records not configured (MX records)
2. Domain not fully pointing to Hostinger
3. Email account not created yet

**Check:**
1. Go to Hostinger → **Advanced** → **DNS Zone Editor**
2. Verify MX records exist:
   ```
   Type: MX
   Name: @ (or prepskul.com)
   Value: mx1.hostinger.com
   Priority: 0
   ```
3. Create the email account if it doesn't exist yet

## Port Comparison

### Port 587 (Recommended)
- ✅ Most widely supported
- ✅ STARTTLS encryption
- ✅ Better deliverability
- ✅ Compatible with most email clients

### Port 465 (Alternative)
- ✅ Direct SSL/TLS
- ✅ Sometimes faster
- ⚠️ Older standard
- Use if 587 doesn't work

## Email Sending Limits

**Hostinger Limits:**
- **Free/VPS Hosting:** ~500 emails per day
- **Business Hosting:** ~1,000-2,000 emails per day
- **Email Hosting:** ~10,000+ emails per day

**For PrepSkul:**
- During development: Free tier is fine
- For production: Consider Hostinger Business Email or dedicated SMTP service
- If sending many emails: Use SendGrid, Mailgun, or similar

## Security Best Practices

### Use Strong Password
- Minimum 16 characters
- Mix of upper, lower, numbers, symbols
- Don't reuse passwords from other services

### Enable 2FA (Two-Factor Authentication)
- In Hostinger, enable 2FA on your account
- Protects your email credentials

### Monitor Email Usage
- Check Hostinger Control Panel → Email → Usage
- Watch for unusual spikes (possible hack)
- Set up email alerts for issues

## Next Steps

1. ✅ Create `noreply@prepskul.com` in Hostinger (recommended)
2. ✅ Get the email password
3. ✅ Configure in Supabase with settings above
4. ✅ Send test email
5. ✅ Verify "PrepSkul" appears as sender
6. ✅ Test in your app

## Support

**If you need help:**
- **Hostinger Support:** [support.hostinger.com](https://support.hostinger.com)
- **Supabase Docs:** [supabase.com/docs/guides/auth/smtp](https://supabase.com/docs/guides/auth/smtp)
- **Hostinger Email Guide:** [support.hostinger.com/en/articles/1575756](https://support.hostinger.com/en/articles/1575756)

## Quick Reference Card

```
┌─────────────────────────────────────────────────┐
│         HOSTINGER SMTP QUICK SETUP              │
├─────────────────────────────────────────────────┤
│ Host: smtp.hostinger.com                        │
│ Port: 587                                       │
│ Encryption: STARTTLS                            │
│ Username: info@prepskul.com                     │
│ Password: [Your email password]                 │
│ Sender: PrepSkul                                │
│ Reply-To: info@prepskul.com                     │
└─────────────────────────────────────────────────┘
```

✅ You'll know it works when emails show "From: PrepSkul" instead of "From: Supabase Auth"

