# 🔗 Supabase Redirect URLs Setup

## 🚨 CRITICAL: Email Verification Won't Work Without This!

### The Error
```
{"error":"requested path is invalid"}
```

### The Problem
Supabase doesn't know where to redirect users after email confirmation because redirect URLs aren't configured.

### ⚡ Quick Fix (5 minutes)

1. **Go to Supabase Dashboard:**
   ```
   https://supabase.com/dashboard/project/cpzaxdfxbamdsshdgjyg
   ```

2. **Navigate to:**
   ```
   Authentication → URL Configuration
   ```

3. **Add these URLs to "Redirect URLs":**
   ```
   https://operating-axis-420213.web.app
   https://operating-axis-420213.web.app/#
   io.supabase.prepskul://
   ```

4. **Also set "Site URL":**
   ```
   https://operating-axis-420213.web.app
   ```

5. **Click "Save"**

### ✅ After This

- Email verification will work instantly
- Users can confirm their email from Gmail
- Deep links will work properly
- No more "invalid path" errors

### 📝 Notes

- These URLs tell Supabase: "If someone clicks an auth link, redirect them here"
- The `#` URL is needed for SPA routing
- The `io.supabase.prepskul://` is for mobile deep linking
- This is **required** for email auth to work

### 🎯 Current Status

- ✅ Code is correct (PKCE flow configured)
- ✅ Deep linking is set up
- ❌ Redirect URLs NOT configured in Supabase dashboard
- ⏸️ Email verification paused until URLs are added

---

**Cannot be automated** - Must be done manually in Supabase dashboard!

