# How Supabase Email Templates Work

## 🔍 **What the Preview Shows**

The Supabase email preview is a **simplified version** that shows the **core structure** but not all the details.

---

## 📧 **Template Variables**

### **Available Variables:**

| Variable | Used For | Example |
|----------|----------|---------|
| `{{ .ConfirmationURL }}` | Email signup confirmation, password reset | Full clickable link |
| `{{ .Token }}` | Magic link signin | 6-digit OTP code |
| `{{ .SiteURL }}` | Your app's base URL | https://app.prepskul.com |
| `{{ .Email }}` | User's email address | user@example.com |

---

## 🎯 **Which Variables for Which Templates**

### **1. Confirm Signup:**
```html
<a href="{{ .ConfirmationURL }}" class="button">Confirm Email Address</a>
<div class="alternate-link">
    <p><strong>Or copy and paste this link into your browser:</strong></p>
    <a href="{{ .ConfirmationURL }}">{{ .ConfirmationURL }}</a>
</div>
```
**Variable:** `{{ .ConfirmationURL }}`

### **2. Reset Password:**
```html
<a href="{{ .ConfirmationURL }}" class="button">Reset Password</a>
<div class="alternate-link">
    <p><strong>Or copy and paste this link into your browser:</strong></p>
    <a href="{{ .ConfirmationURL }}">{{ .ConfirmationURL }}</a>
</div>
```
**Variable:** `{{ .ConfirmationURL }}`

### **3. Magic Link:**
```html
<a href="{{ .Token }}" class="button">Sign In Now</a>
<p>This link will expire in 1 hour.</p>
```
**Variable:** `{{ .Token }}` (Note: Magic links are different!)

---

## 📱 **What the Preview Shows vs. Reality**

### **Preview (Supabase Dashboard):**
- ✅ Shows main button/link
- ✅ Shows basic structure
- ✅ Shows expiry notice
- ❌ **May not show** alternate link section
- ❌ **May not show** full HTML styling

### **Actual Email:**
- ✅ All HTML rendered
- ✅ Full styling applied
- ✅ Alternate link shown
- ✅ Footer included
- ✅ Responsive design
- ✅ Brand colors

**The preview is just a quick check - actual emails will look much better!**

---

## 🔗 **The "Or copy and paste" Section**

### **Why Include It:**
1. **Accessibility** - For users who can't click links
2. **Email clients** - Some strip styles from buttons
3. **Reliability** - Always have a backup method
4. **Best practice** - Industry standard

### **How It Works:**
```html
<div class="alternate-link">
    <p><strong>Or copy and paste this link into your browser:</strong></p>
    <a href="{{ .ConfirmationURL }}">{{ .ConfirmationURL }}</a>
</div>
```

**Supabase replaces `{{ .ConfirmationURL }}` with:**
```
https://cpzaxdfxbamdsshdgjyg.supabase.co/auth/v1/verify?token=abc123...&type=signup
```

**User sees:**
- Full clickable link (styled)
- Can copy/paste if needed

---

## ✉️ **Email Templates Structure**

### **Standard Structure:**

```
1. Header (Gradient background)
   - Logo/Icon
   - Title

2. Content (White background)
   - Heading
   - Greeting
   - Main message
   - Primary button
   - Alternate link (if needed)
   - Expiry notice
   - Security notice (if needed)

3. Footer (Light gray background)
   - Company name
   - Contact links
   - Copyright
```

---

## 🎨 **What Your Users Will See**

### **Email Confirmation:**
```
┌─────────────────────────────────────┐
│  📚 Welcome to PrepSkul             │
├─────────────────────────────────────┤
│  Confirm your email address         │
│                                     │
│  Hi there! 👋                       │
│  Thank you for signing up...        │
│                                     │
│  [Confirm Email Address]  ← Button  │
│                                     │
│  Or copy and paste:                 │
│  https://...supabase.co/...link     │
│                                     │
│  This link expires in 24 hours.     │
├─────────────────────────────────────┤
│  PrepSkul                           │
│  Visit website | Contact support    │
└─────────────────────────────────────┘
```

### **Password Reset:**
```
┌─────────────────────────────────────┐
│  🔐 Password Reset                  │
├─────────────────────────────────────┤
│  Reset your password                │
│                                     │
│  Click the button below...          │
│                                     │
│  [Reset Password]  ← Button         │
│                                     │
│  Or copy and paste:                 │
│  https://...supabase.co/...link     │
│                                     │
│  Expires in 1 hour.                 │
│  Security notice...                 │
├─────────────────────────────────────┤
│  PrepSkul                           │
│  Get help                           │
└─────────────────────────────────────┘
```

---

## 🔧 **Template Differences**

### **Confirm Signup vs Magic Link:**

**Confirm Signup:**
- **Variable:** `{{ .ConfirmationURL }}`
- **Use:** Button + copy/paste link
- **Length:** Full URL
- **Expiry:** 24 hours

**Magic Link:**
- **Variable:** `{{ .Token }}`
- **Use:** Direct link only
- **Length:** Shorter token
- **Expiry:** 1 hour

**Important:** Use the correct variable for each template!

---

## ✅ **Your Templates Include:**

1. ✅ **Primary button** - Large, branded, clickable
2. ✅ **Alternate link** - For copy/paste backup
3. ✅ **Expiry notice** - Security information
4. ✅ **Security notice** - When needed
5. ✅ **Footer** - Contact and branding
6. ✅ **Responsive design** - Mobile-friendly

**Professional, complete, and user-friendly!** ✨

---

## 🧪 **Testing Your Templates**

### **In Supabase Preview:**
- Shows basic structure ✅
- Shows variable placeholders ✅
- May not show full styling ⚠️

### **Send Test Email:**
1. Click **"Send test email"** button
2. Enter your email
3. Check inbox
4. See **full rendered email** ✅
5. Click link to verify it works ✅

**This is the best way to see how users will see it!**

---

## 📝 **Summary**

| Question | Answer |
|----------|--------|
| **Will alternate link show?** | ✅ Yes in actual email |
| **Preview shows everything?** | ⚠️ No, simplified view |
| **Which variable?** | `{{ .ConfirmationURL }}` for signup/reset |
| **Does it look branded?** | ✅ Yes with your HTML |
| **Test before using?** | ✅ Send test email! |

---

## 🎯 **Bottom Line**

**The Supabase preview is simplified.** The actual emails users receive will:
- ✅ Include the "Or copy and paste" section
- ✅ Show full branded styling
- ✅ Display all elements correctly
- ✅ Look professional and complete

**Your templates are comprehensive and will render beautifully in real emails!** ✨

---

**Want to test?** Click "Send test email" in Supabase dashboard to see the full rendered result!

