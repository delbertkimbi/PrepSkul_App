# Quick Answer: Email Confirmation

## Supabase Sends: **CONFIRMATION LINK** (not a code)

**Email Auth:** Always sends a clickable link
**Phone Auth:** Sends a 6-digit code (OTP)

---

## What You Need to Configure

### Development (Now):
```
Supabase Dashboard → Authentication → Email Auth
"Enable email confirmations" → OFF ❌

Result: No email sent, instant signup
```

### Production (Later):
```
Supabase Dashboard → Authentication → Email Auth
"Enable email confirmations" → ON ✅

Result: Email sent with confirmation link
```

---

## Redirect URLs Must Include:

**Development:**
- http://localhost:3000/**
- https://operating-axis-420213.web.app/**

**Production:**
- https://app.prepskul.com/**
- https://www.prepskul.com/**

**Why?** So the confirmation link can redirect users back to your app!

---

## Summary

✅ **Supabase sends:** Clickable confirmation link  
✅ **Your app handles:** Both modes automatically  
✅ **Configuration:** Just toggle on/off in Supabase  

**Read `EMAIL_CONFIRMATION_EXPLAINED.md` for full details!**
