# 📱 Password Reset: Cross-Device Flow Guide

## 🎯 **What Happens When User Receives Email on Another Device?**

### **Scenario 1: Email on Mobile, Clicking on Mobile** ✅
```
User requests reset on web app
    ↓
Email arrives on user's phone
    ↓
User clicks "Reset Password" link in email
    ↓
Link opens in mobile browser: https://app.prepskul.com/reset-password?token=...
    ↓
Supabase validates token automatically
    ↓
User is redirected to mobile app via deep link: io.supabase.prepskul://login-callback/...
    ↓
Mobile app handles the deep link
    ↓
App shows "Set New Password" screen
    ↓
User enters new password → Done! ✅
```

### **Scenario 2: Email on Desktop, Clicking on Desktop** ✅
```
User requests reset on mobile app
    ↓
Email arrives on desktop
    ↓
User clicks "Reset Password" link in email
    ↓
Link opens in desktop browser: https://app.prepskul.com/reset-password?token=...
    ↓
Supabase validates token automatically
    ↓
User is redirected to web app
    ↓
Web app shows "Set New Password" screen
    ↓
User enters new password → Done! ✅
```

### **Scenario 3: Email on Mobile, Clicking on Desktop** ✅
```
User requests reset on mobile app
    ↓
Email arrives on phone
    ↓
User opens email on desktop (synced email)
    ↓
User clicks "Reset Password" link
    ↓
Link opens in desktop browser: https://app.prepskul.com/reset-password?token=...
    ↓
Supabase validates token automatically
    ↓
User completes password reset on desktop
    ↓
Can now login on mobile with new password ✅
```

---

## 🔧 **How It Works**

### **1. Email Link Structure**
When Supabase sends the password reset email, the link looks like:
```
https://app.prepskul.com/reset-password?token=abc123&type=recovery
```

### **2. Token Validation**
- Supabase automatically validates the token when the link is clicked
- Token expires after 1 hour (by default)
- Token can only be used once

### **3. Platform Detection**
The app detects which platform is opening the link:
- **Web browser** → Stays on web, shows password reset form
- **Mobile browser** → Attempts to redirect to mobile app via deep link
- **Mobile app** → Handles deep link directly

---

## 📋 **Required Redirect URLs in Supabase**

Go to: **Supabase Dashboard** → **Authentication** → **URL Configuration**

### **Site URL:**
```
https://app.prepskul.com
```

### **Redirect URLs (add all):**
```
https://app.prepskul.com/**
https://operating-axis-420213.web.app/**
http://localhost:*
io.supabase.prepskul://login-callback/**
io.supabase.prepskul://**
```

**Important:**
- Each URL on a separate line
- Use `**` wildcard to allow all paths
- Include both production and development URLs

---

## 🌐 **Creating Password Reset Page (Web)**

You need a web page at `https://app.prepskul.com/reset-password` that:

1. **Extracts the token from URL**
2. **Shows password reset form**
3. **Submits new password to Supabase**

### **Next.js Example:**
```typescript
// app/reset-password/page.tsx
'use client';

import { useEffect, useState } from 'react';
import { useSearchParams, useRouter } from 'next/navigation';
import { createClient } from '@supabase/supabase-js';

export default function ResetPasswordPage() {
  const searchParams = useSearchParams();
  const router = useRouter();
  const token = searchParams.get('token');
  const [password, setPassword] = useState('');
  const [loading, setLoading] = useState(false);

  const handleReset = async (e: React.FormEvent) => {
    e.preventDefault();
    setLoading(true);

    try {
      const supabase = createClient(
        process.env.NEXT_PUBLIC_SUPABASE_URL!,
        process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY!
      );

      // Supabase automatically handles the token from URL
      const { error } = await supabase.auth.updateUser({
        password: password
      });

      if (error) throw error;

      alert('Password reset successful!');
      router.push('/login');
    } catch (error: any) {
      alert(error.message);
    } finally {
      setLoading(false);
    }
  };

  if (!token) {
    return <div>Invalid or expired reset link</div>;
  }

  return (
    <form onSubmit={handleReset}>
      <h1>Reset Password</h1>
      <input
        type="password"
        value={password}
        onChange={(e) => setPassword(e.target.value)}
        placeholder="New Password"
        required
      />
      <button type="submit" disabled={loading}>
        {loading ? 'Resetting...' : 'Reset Password'}
      </button>
    </form>
  );
}
```

---

## 📱 **Handling Deep Links (Mobile)**

### **For Flutter App:**

The app should handle the deep link `io.supabase.prepskul://login-callback/...`

When the link is clicked:
1. Mobile browser opens the link
2. Browser attempts to open app via deep link
3. Flutter app receives the deep link
4. Extract token from URL
5. Show password reset screen
6. Submit new password to Supabase

### **Example Deep Link Handler:**
```dart
// In main.dart or app initialization
void handleDeepLink(String link) {
  final uri = Uri.parse(link);
  
  if (uri.pathSegments.contains('login-callback')) {
    // Check if it's a password reset
    if (uri.queryParameters.containsKey('type') && 
        uri.queryParameters['type'] == 'recovery') {
      // Navigate to password reset screen
      Navigator.pushNamed(context, '/reset-password', 
        arguments: {'token': uri.queryParameters['token']}
      );
    }
  }
}
```

---

## ✅ **Complete Flow Summary**

1. **User requests reset** → `AuthService.sendPasswordResetEmail(email)`
2. **Supabase sends email** → Contains link with token
3. **User clicks link** → Opens in browser/web view
4. **Supabase validates token** → Automatically (no code needed)
5. **Platform detection:**
   - **Web:** Shows reset form on web app
   - **Mobile:** Redirects to mobile app via deep link
6. **User enters new password** → Submits to Supabase
7. **Password updated** → User can now login with new password

---

## 🔒 **Security Notes**

- ✅ Token expires after 1 hour
- ✅ Token can only be used once
- ✅ Token is validated by Supabase automatically
- ✅ Password reset requires email verification
- ✅ No password reset without valid token

---

## 🐛 **Troubleshooting**

### **Issue: Link doesn't open app on mobile**
**Solution:** Make sure deep link is configured in Android/iOS settings

### **Issue: "Invalid or expired token"**
**Solution:** Request a new password reset (token expired or already used)

### **Issue: Link opens but no form shows**
**Solution:** Create the password reset page at the redirect URL path

### **Issue: Deep link not working**
**Solution:** Verify redirect URLs include `io.supabase.prepskul://**`

---

**That's it! Your password reset now works across all devices! 🎉**

