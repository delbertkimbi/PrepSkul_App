# Supabase URLs to Add

## 🎯 Add These URLs to Supabase Dashboard

**Go to:** Supabase Dashboard → Authentication → URL Configuration

### **Add to "Redirect URLs":**

```
✅ prepskul://auth/callback
✅ prepskul://
✅ io.supabase.prepskul://auth/callback
✅ https://operating-axis-420213.web.app/**
✅ http://localhost:3000/**
✅ http://localhost:3001/**
✅ http://localhost:3002/**
✅ https://admin.prepskul.com/**
✅ https://www.prepskul.com/**
✅ https://prepskul.com/**
```

### **Set "Site URL" to:**

```
https://app.prepskul.com
```

**Or for development:**
```
https://operating-axis-420213.web.app
```

---

## 📱 Why These URLs?

| URL | Purpose |
|-----|---------|
| `prepskul://auth/callback` | Deep link for Android/iOS apps |
| `io.supabase.prepskul://auth/callback` | Alternative deep link |
| `https://app.prepskul.com/**` | Production web app |
| `https://operating-axis-420213.web.app/**` | Current web deployment |
| `http://localhost:*/**` | Local development |
| `https://admin.prepskul.com/**` | Admin dashboard |
| `https://www.prepskul.com/**` | Main website |

---

## ✅ Result

After adding these URLs, Supabase will redirect users to:
- **Web:** Your website
- **Mobile App:** Deep links open the app
- **Production:** Professional experience

**Configuration complete!** 🎉

