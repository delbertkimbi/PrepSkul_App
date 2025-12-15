# PrepSkul Email Template Customization

## Overview
Complete guide for customizing branded email templates in Supabase for PrepSkul authentication and notifications.

---

## 🎨 Brand Information

### **Company Details:**
- **Name:** PrepSkul
- **Tagline:** Connecting students with expert tutors in Cameroon
- **Website:** https://www.prepskul.com
- **App:** https://app.prepskul.com

### **Brand Colors:**
- **Primary Deep Blue:** `#1B2C4F`
- **Primary Light Blue:** `#4A6FBF`
- **Primary Dark Blue:** `#0F1A2E`
- **Success Green:** `#10B981`
- **Accent Purple:** `#6366F1`

### **Typography:**
- **Font Family:** Poppins (as used in app)
- **Website Font:** Inter/System fonts for emails

---

## 📧 Configuring Email Templates in Supabase

### **Step 1: Access Email Templates**

1. Go to **Supabase Dashboard**
2. Select your project: **PrepSkul**
3. Navigate to **Authentication** → **Email Templates**
4. You'll see all available email templates

### **Step 2: Customize Each Template**

---

## 🔐 Template 1: Confirm Signup (Magic Link)

**When sent:** When user signs up with email (if email confirmation enabled)  
**Purpose:** Verify email address

### **Subject:**
```
Welcome to PrepSkul! Confirm your email address
```

### **Body (HTML):**
```html
<!DOCTYPE html>
<html>
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <style>
        body {
            font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, 'Helvetica Neue', Arial, sans-serif;
            line-height: 1.6;
            color: #1F2937;
            margin: 0;
            padding: 0;
            background-color: #F9FAFB;
        }
        .container {
            max-width: 600px;
            margin: 40px auto;
            background-color: #FFFFFF;
            border-radius: 12px;
            overflow: hidden;
            box-shadow: 0 4px 6px rgba(0, 0, 0, 0.1);
        }
        .header {
            background: linear-gradient(135deg, #1B2C4F 0%, #4A6FBF 100%);
            padding: 40px 30px;
            text-align: center;
        }
        .logo {
            width: 80px;
            height: 80px;
            background-color: rgba(255, 255, 255, 0.2);
            border-radius: 16px;
            margin: 0 auto 20px;
            display: flex;
            align-items: center;
            justify-content: center;
            font-size: 40px;
        }
        .header h1 {
            color: #FFFFFF;
            font-size: 28px;
            font-weight: 700;
            margin: 0;
        }
        .content {
            padding: 40px 30px;
        }
        .content h2 {
            color: #1B2C4F;
            font-size: 24px;
            font-weight: 600;
            margin: 0 0 20px;
        }
        .content p {
            color: #6B7280;
            font-size: 16px;
            margin: 0 0 20px;
        }
        .button {
            display: inline-block;
            padding: 16px 32px;
            background: linear-gradient(135deg, #1B2C4F 0%, #4A6FBF 100%);
            color: #FFFFFF !important;
            text-decoration: none;
            border-radius: 8px;
            font-weight: 600;
            font-size: 16px;
            margin: 20px 0;
            transition: transform 0.2s;
        }
        .button:hover {
            transform: translateY(-2px);
        }
        .alternate-link {
            margin-top: 30px;
            padding-top: 30px;
            border-top: 1px solid #E5E7EB;
        }
        .alternate-link p {
            font-size: 14px;
            color: #9CA3AF;
            margin: 0 0 10px;
        }
        .alternate-link a {
            color: #1B2C4F;
            word-break: break-all;
            font-size: 14px;
        }
        .footer {
            background-color: #F9FAFB;
            padding: 30px;
            text-align: center;
        }
        .footer p {
            color: #6B7280;
            font-size: 14px;
            margin: 0 0 10px;
        }
        .footer a {
            color: #4A6FBF;
            text-decoration: none;
        }
        .footer a:hover {
            text-decoration: underline;
        }
        .social-links {
            margin-top: 20px;
        }
        .social-links a {
            display: inline-block;
            margin: 0 10px;
            color: #1B2C4F;
            font-size: 14px;
        }
    </style>
</head>
<body>
    <div class="container">
        <div class="header">
            <div class="logo">📚</div>
            <h1>Welcome to PrepSkul</h1>
        </div>
        <div class="content">
            <h2>Confirm your email address</h2>
            <p>Hi there! 👋</p>
            <p>Thank you for signing up for PrepSkul - your platform for connecting with expert tutors in Cameroon.</p>
            <p>Click the button below to verify your email address and start your learning journey:</p>
            <a href="{{ .ConfirmationURL }}" class="button">Confirm Email Address</a>
            <div class="alternate-link">
                <p><strong>Or copy and paste this link into your browser:</strong></p>
                <a href="{{ .ConfirmationURL }}">{{ .ConfirmationURL }}</a>
            </div>
            <p style="margin-top: 30px; font-size: 14px; color: #9CA3AF;">This link will expire in 24 hours. If you didn't create an account with PrepSkul, you can safely ignore this email.</p>
        </div>
        <div class="footer">
            <p><strong>PrepSkul</strong></p>
            <p>Connecting students with expert tutors in Cameroon</p>
            <p>
                <a href="https://www.prepskul.com">Visit our website</a> | 
                <a href="https://app.prepskul.com">Open app</a>
            </p>
            <div class="social-links">
                <a href="https://www.prepskul.com">Website</a>
                <a href="mailto:support@prepskul.com">Support</a>
            </div>
            <p style="margin-top: 20px; font-size: 12px; color: #9CA3AF;">© 2025 PrepSkul. All rights reserved.</p>
        </div>
    </div>
</body>
</html>
```

---

## 🔑 Template 2: Reset Password

**When sent:** When user requests password reset  
**Purpose:** Allow user to set new password

### **Subject:**
```
Reset your PrepSkul password
```

### **Body (HTML):**
```html
<!DOCTYPE html>
<html>
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <style>
        body {
            font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, 'Helvetica Neue', Arial, sans-serif;
            line-height: 1.6;
            color: #1F2937;
            margin: 0;
            padding: 0;
            background-color: #F9FAFB;
        }
        .container {
            max-width: 600px;
            margin: 40px auto;
            background-color: #FFFFFF;
            border-radius: 12px;
            overflow: hidden;
            box-shadow: 0 4px 6px rgba(0, 0, 0, 0.1);
        }
        .header {
            background: linear-gradient(135deg, #1B2C4F 0%, #4A6FBF 100%);
            padding: 40px 30px;
            text-align: center;
        }
        .logo {
            width: 80px;
            height: 80px;
            background-color: rgba(255, 255, 255, 0.2);
            border-radius: 16px;
            margin: 0 auto 20px;
            display: flex;
            align-items: center;
            justify-content: center;
            font-size: 40px;
        }
        .header h1 {
            color: #FFFFFF;
            font-size: 28px;
            font-weight: 700;
            margin: 0;
        }
        .content {
            padding: 40px 30px;
        }
        .content h2 {
            color: #1B2C4F;
            font-size: 24px;
            font-weight: 600;
            margin: 0 0 20px;
        }
        .content p {
            color: #6B7280;
            font-size: 16px;
            margin: 0 0 20px;
        }
        .button {
            display: inline-block;
            padding: 16px 32px;
            background: linear-gradient(135deg, #1B2C4F 0%, #4A6FBF 100%);
            color: #FFFFFF !important;
            text-decoration: none;
            border-radius: 8px;
            font-weight: 600;
            font-size: 16px;
            margin: 20px 0;
            transition: transform 0.2s;
        }
        .button:hover {
            transform: translateY(-2px);
        }
        .alternate-link {
            margin-top: 30px;
            padding-top: 30px;
            border-top: 1px solid #E5E7EB;
        }
        .alternate-link p {
            font-size: 14px;
            color: #9CA3AF;
            margin: 0 0 10px;
        }
        .alternate-link a {
            color: #1B2C4F;
            word-break: break-all;
            font-size: 14px;
        }
        .security-note {
            background-color: #FEF3C7;
            border-left: 4px solid #F59E0B;
            padding: 16px;
            border-radius: 4px;
            margin: 20px 0;
        }
        .security-note p {
            color: #92400E;
            font-size: 14px;
            margin: 0;
        }
        .footer {
            background-color: #F9FAFB;
            padding: 30px;
            text-align: center;
        }
        .footer p {
            color: #6B7280;
            font-size: 14px;
            margin: 0 0 10px;
        }
        .footer a {
            color: #4A6FBF;
            text-decoration: none;
        }
    </style>
</head>
<body>
    <div class="container">
        <div class="header">
            <div class="logo">🔐</div>
            <h1>Password Reset</h1>
        </div>
        <div class="content">
            <h2>Reset your password</h2>
            <p>Hi there! 👋</p>
            <p>We received a request to reset the password for your PrepSkul account.</p>
            <p>Click the button below to create a new password:</p>
            <a href="{{ .ConfirmationURL }}" class="button">Reset Password</a>
            <div class="alternate-link">
                <p><strong>Or copy and paste this link into your browser:</strong></p>
                <a href="{{ .ConfirmationURL }}">{{ .ConfirmationURL }}</a>
            </div>
            <div class="security-note">
                <p><strong>🔒 Security Notice:</strong> If you didn't request a password reset, please ignore this email. Your password won't change unless you use the link above.</p>
            </div>
            <p style="margin-top: 30px; font-size: 14px; color: #9CA3AF;">This link will expire in 1 hour for security reasons.</p>
        </div>
        <div class="footer">
            <p><strong>PrepSkul</strong></p>
            <p>Connecting students with expert tutors in Cameroon</p>
            <p>
                <a href="https://www.prepskul.com">Visit our website</a> | 
                <a href="mailto:support@prepskul.com">Get help</a>
            </p>
            <p style="margin-top: 20px; font-size: 12px; color: #9CA3AF;">© 2025 PrepSkul. All rights reserved.</p>
        </div>
    </div>
</body>
</html>
```

---

## 📧 Template 3: Magic Link

**When sent:** When user requests magic link login  
**Purpose:** Passwordless authentication

### **Subject:**
```
Your PrepSkul login link
```

### **Body (HTML):**
Use similar structure as Confirm Signup template, with:
```html
<h2>Sign in to PrepSkul</h2>
<p>Click the button below to securely sign in to your account:</p>
<a href="{{ .Token }}" class="button">Sign In Now</a>
<p style="margin-top: 30px; font-size: 14px; color: #9CA3AF;">This link will expire in 1 hour and can only be used once.</p>
```

---

## ✉️ Template 4: Email Change

**When sent:** When user changes email address  
**Purpose:** Confirm new email

### **Subject:**
```
Confirm your new PrepSkul email
```

### **Body (HTML):**
Use similar structure as Confirm Signup template, with:
```html
<h2>Confirm your new email</h2>
<p>You requested to change the email address for your PrepSkul account.</p>
<p>Click the button below to confirm this new email address:</p>
<a href="{{ .ConfirmationURL }}" class="button">Confirm New Email</a>
<p style="margin-top: 30px; font-size: 14px; color: #9CA3AF;">If you didn't request this change, please contact support immediately.</p>
```

---

## 📱 Template 5: Change Email Notice

**When sent:** When email change is successful  
**Purpose:** Notify user of successful email change

### **Subject:**
```
Your PrepSkul email was changed
```

### **Body (HTML):**
```html
<!DOCTYPE html>
<html>
<head>
    <meta charset="UTF-8">
    <style>
        /* Same styles as above */
    </style>
</head>
<body>
    <div class="container">
        <div class="header">
            <div class="logo">✉️</div>
            <h1>Email Changed</h1>
        </div>
        <div class="content">
            <h2>Your email address was successfully changed</h2>
            <p>Hi there! 👋</p>
            <p>The email address for your PrepSkul account has been successfully updated.</p>
            <div class="security-note">
                <p><strong>🔒 Security Notice:</strong> If you didn't make this change, please contact our support team immediately.</p>
            </div>
            <p style="margin-top: 20px;">All future emails will be sent to your new address.</p>
        </div>
        <div class="footer">
            <p><strong>PrepSkul</strong></p>
            <p>
                <a href="mailto:support@prepskul.com">Contact support</a>
            </p>
        </div>
    </div>
</body>
</html>
```

---

## ✅ Setup Instructions

### **1. Access Supabase Email Templates**
1. Go to https://supabase.com/dashboard
2. Select your project
3. Navigate to **Authentication** → **Email Templates**

### **2. For Each Template**
1. Click on the template name
2. Replace the default HTML with the provided code above
3. Test the email by clicking "Send test email"
4. Click **Save**

### **3. Configuration Settings**

In **Authentication** → **Email Auth**:

#### **Email Confirmation:**
- ✅ **Enable** for production (extra security)
- ❌ **Disable** for development (faster testing)

#### **Secure Email Change:**
- ✅ **Enable** for production
- Requires confirmation before email change

#### **Rate Limiting:**
- **Max emails per hour:** 5-10
- **Email expiry:** 24 hours (signup), 1 hour (password reset)

---

## 🔗 URL Configuration

### **Current Supabase URLs:**

Go to **Authentication** → **URL Configuration**

#### **For Development:**
**Site URL:**
```
https://operating-axis-420213.web.app
```

**Redirect URLs:**
```
https://operating-axis-420213.web.app/**
https://app.prepskul.com/**
https://www.prepskul.com/**
https://admin.prepskul.com/**
http://localhost:3000/**
```

#### **For Production:**
Once custom domain is live:

**Site URL:**
```
https://app.prepskul.com
```

**Redirect URLs:**
```
https://app.prepskul.com/**
https://www.prepskul.com/**
https://admin.prepskul.com/**
```

---

## 🧪 Testing Email Templates

### **Method 1: Send Test Email**
1. In each template editor
2. Click **"Send test email"**
3. Enter your email
4. Check your inbox

### **Method 2: Live Testing**
1. Run your app locally or in production
2. Trigger the email action (signup, reset password, etc.)
3. Check the email in your inbox
4. Test the links work correctly

### **Method 3: Email Preview**
- Use Supabase's built-in preview
- Test different screen sizes
- Verify all links work

---

## 🎨 Customization Tips

### **Color Variables:**
```css
Primary Deep Blue:  #1B2C4F
Primary Light Blue: #4A6FBF
Text Dark:          #1F2937
Text Medium:        #6B7280
Text Light:         #9CA3AF
Success Green:      #10B981
Warning Orange:     #F59E0B
Background:         #F9FAFB
White:              #FFFFFF
```

### **Logo Options:**
1. Use emoji: 📚 (current - no setup needed)
2. Use image URL: Replace emoji with `<img src="https://www.prepskul.com/logo.png" alt="PrepSkul">`
3. Use SVG: Best for quality at any size

### **Responsive Design:**
- All templates use responsive CSS
- Test on mobile (width < 600px)
- Ensure buttons are tappable (min 44x44px)

---

## ✅ Checklist

- [ ] Customize all email templates
- [ ] Test each email with test sender
- [ ] Verify all links work correctly
- [ ] Configure URL redirects
- [ ] Set rate limits appropriately
- [ ] Enable email confirmation for production
- [ ] Test on mobile devices
- [ ] Add company logo (optional)
- [ ] Configure SMTP (optional - for custom sender)

---

## 🚀 Next Steps

1. **Access Supabase Email Templates** → Authentication → Email Templates
2. **Copy each template** from this guide
3. **Save and test** each one
4. **Configure URLs** in Authentication → URL Configuration
5. **Test live** by signing up/resetting password

**Your emails will look professional and branded!** ✨

