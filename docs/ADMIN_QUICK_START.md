# 🚀 Admin Dashboard - Quick Start

**5-Minute Overview**

---

## ✅ **YES, IT'S FREE!**

You can build the admin dashboard in your existing Next.js project and deploy it to `admin.prepskul.com` for **$0**.

---

## 🏗️ **ARCHITECTURE**

```
www.prepskul.com          →  PrepSkul_Web/app/[locale]/
admin.prepskul.com        →  PrepSkul_Web/app/admin/
                             (same project!)

Both use same Supabase backend ✅
```

---

## 💰 **COSTS**

| Item | Cost |
|------|------|
| Subdomain | **FREE** ✅ |
| Vercel Hosting | **FREE** ✅ |
| SSL Certificate | **FREE** ✅ (automatic) |
| **TOTAL** | **$0** 🎉 |

---

## 📁 **FOLDER STRUCTURE**

```
PrepSkul_Web/
├── app/
│   ├── [locale]/           # Main site (www.prepskul.com)
│   │   ├── page.tsx
│   │   └── about/
│   │
│   └── admin/              # Admin (admin.prepskul.com) ⭐ NEW
│       ├── layout.tsx      # Admin sidebar, auth
│       ├── page.tsx        # Dashboard
│       ├── tutors/
│       │   ├── pending/    # Review applications
│       │   ├── approved/
│       │   └── rejected/
│       ├── users/
│       ├── sessions/
│       └── analytics/
│
└── lib/
    └── supabase.ts         # Shared database client
```

---

## 🔧 **SETUP STEPS**

### **1. Install Dependencies** (2 min)
```bash
cd PrepSkul_Web
pnpm add @supabase/supabase-js @supabase/ssr
```

### **2. Create Admin Routes** (5 min)
```bash
mkdir -p app/admin/tutors/pending
touch app/admin/layout.tsx
touch app/admin/page.tsx
touch app/admin/tutors/pending/page.tsx
```

### **3. Setup Supabase** (3 min)
Create `lib/supabase.ts` with your credentials.

### **4. Build UI** (2-3 days)
- Login page
- Dashboard
- Tutor review interface
- Approve/reject buttons

### **5. Deploy to Vercel** (5 min)
- Push to GitHub
- Import in Vercel
- Add domains (www + admin)
- Done! ✅

---

## 🔒 **SECURITY**

Add `is_admin` column to profiles:

```sql
ALTER TABLE profiles ADD COLUMN is_admin BOOLEAN DEFAULT FALSE;
UPDATE profiles SET is_admin = TRUE WHERE email = 'admin@prepskul.com';
```

Check auth in admin layout:

```typescript
// app/admin/layout.tsx
const { data: profile } = await supabase
  .from('profiles')
  .select('is_admin')
  .eq('id', user.id)
  .single();

if (!profile?.is_admin) {
  redirect('/'); // Kick them out!
}
```

---

## 🌐 **DNS SETUP** (5 min)

In your domain registrar:

```
Type    Name    Value                TTL
CNAME   admin   cname.vercel-dns.com 3600
```

Vercel handles the rest! ✅

---

## 📊 **WEEK 1 FEATURES**

### **Admin Dashboard:**
- [ ] Login page
- [ ] Dashboard with stats
- [ ] View pending tutors
- [ ] Review tutor profiles (all data)
- [ ] Approve button
- [ ] Reject button (with reason)
- [ ] Send email notification
- [ ] Send SMS notification

---

## 🎯 **RECOMMENDED APPROACH**

**Option A: Same Project** ⭐ (BEST)
- ✅ Share code, components, Supabase client
- ✅ Single deployment
- ✅ Easier maintenance

**Option B: Separate Project**
- ❌ Duplicate code
- ❌ Two deployments
- ❌ More complexity

→ **Choose Option A!**

---

## 📝 **NEXT ACTION**

Let me know when you're ready, and I'll:
1. Create the admin routes in `PrepSkul_Web`
2. Setup authentication
3. Build the tutor review UI
4. Deploy to Vercel

**Total time: 2-3 days of development** ⏱️

---

## 💡 **KEY POINTS**

✅ Free subdomain  
✅ Free hosting  
✅ Same codebase  
✅ Shared database  
✅ Easy to maintain  
✅ Secure by default  

**No downsides! Just do it! 🚀**

---

**Questions? Ready to start? Let me know!**

