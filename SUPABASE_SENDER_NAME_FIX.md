# Why Does My Email Show "Supabase Auth"?

## The Problem

When users receive email confirmations, they see:
- **Sender:** "Supabase Auth" `<noreply@mail.app.supabase.io>`
- **Instead of:** "PrepSkul" or your custom name

This is because Supabase sends emails from their own infrastructure.

## Why "Supabase Auth" Appears

Supabase uses its own email sending service (`mail.app.supabase.io`). The sender name defaults to "Supabase Auth" because:
1. You're using Supabase's built-in email service
2. The "From" name is set to default values
3. No custom branding has been configured

## ✅ The Solution: Custom SMTP

To change the sender name to "PrepSkul":

### Option 1: Custom SMTP (Recommended)

Configure your own SMTP server in Supabase:

1. Go to **Supabase Dashboard** → **Authentication** → **Email Templates**
2. Scroll down to **SMTP Settings**
3. Click **Configure Custom SMTP**
4. Enter your SMTP credentials (Gmail, SendGrid, Mailgun, etc.)
5. Set **Sender Name** to "PrepSkul"
6. Set **Reply-To** to `support@prepskul.com`

**Example SMTP Setup:**
```
SMTP Server: smtp.gmail.com
Port: 587
Username: noreply@prepskul.com
Password: [your app password]
Sender Name: PrepSkul
Reply-To: support@prepskul.com
```

### Option 2: Email Service Integration (Best for Production)

Use a dedicated email service:

1. **SendGrid** (recommended for production)
2. **Mailgun**
3. **AWS SES**
4. **Postmark**

These services give you:
- ✅ Custom sender names
- ✅ Better deliverability
- ✅ Analytics & tracking
- ✅ Professional branding
- ✅ Dedicated IP addresses

### Option 3: Keep Supabase Default (For Development)

If you're still in development, you can:
- Explain to test users that "Supabase Auth" is normal
- Note it's for development only
- Switch to custom SMTP before production

## 📧 Quick Gmail Setup

If you want to use Gmail for SMTP:

```bash
# 1. Enable 2-Factor Authentication on your Gmail account
# 2. Generate an App Password:
#    - Go to Google Account → Security
#    - App Passwords → Select "Mail" and "Other (Custom name)"
#    - Enter "PrepSkul Supabase" → Generate
#    - Copy the 16-character password

# 3. In Supabase:
SMTP Server: smtp.gmail.com
Port: 587
Username: your-email@gmail.com
Password: [app password from step 2]
Encryption: TLS
Sender Name: PrepSkul
Reply-To: your-email@gmail.com
```

## 🎯 What Changes

**Before (Supabase Default):**
- From: Supabase Auth `<noreply@mail.app.supabase.io>`
- Users see generic branding

**After (Custom SMTP):**
- From: PrepSkul `<noreply@prepskul.com>`
- Custom branding throughout
- Professional appearance
- Better user trust

## 📝 Important Notes

1. **Email Templates Still Work:** Your custom HTML templates will still work with custom SMTP
2. **Domain Reputation:** Using custom SMTP helps build your domain's email reputation
3. **Deliverability:** Production services (SendGrid, etc.) have better inbox rates than generic SMTP
4. **Cost:** Gmail SMTP is free but has limits; dedicated services cost money but are more reliable

## 🚀 Next Steps

1. **For Now:** Continue testing with Supabase default
2. **Before Launch:** Set up custom SMTP or email service
3. **Production:** Use a dedicated email service for best results

## ❓ FAQ

**Q: Can I just change the sender name without custom SMTP?**  
A: No. Supabase uses their own email infrastructure, so the sender name is fixed to "Supabase Auth" unless you configure custom SMTP.

**Q: Will my users see "Supabase Auth" in production?**  
A: Yes, unless you set up custom SMTP or an email service.

**Q: Is Gmail SMTP good enough for production?**  
A: It works for small apps, but dedicated services are better for scale and deliverability.

**Q: How do I test email sending with custom SMTP?**  
A: Use the "Send a test email" button in Supabase Authentication settings.

## 🎉 Summary

"Supabase Auth" appears because you're using Supabase's default email service. Set up custom SMTP or an email service to show "PrepSkul" as the sender. For now, focus on testing the app functionality; switch to custom SMTP before your production launch.

