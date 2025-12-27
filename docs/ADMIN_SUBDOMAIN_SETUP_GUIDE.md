# 🔐 Admin Subdomain Setup Guide

**Project:** PrepSkul Admin Dashboard  
**URL:** `https://admin.prepskul.com`  
**Main Site:** `https://www.prepskul.com`  
**Backend:** Shared Supabase (prepskul_app)

---

## ✅ **YES, IT'S ABSOLUTELY POSSIBLE!**

You can build the admin dashboard in the same Next.js project (`PrepSkul_Web`) and deploy it to `admin.prepskul.com`. This is a **common and recommended approach**.

---

## 💰 **COSTS**

### **Subdomain Hosting Costs:**
✅ **$0 - FREE!**

- Subdomains are **completely free**
- You already own `prepskul.com`
- You can create unlimited subdomains (admin.prepskul.com, api.prepskul.com, etc.)
- No additional domain purchase needed

### **Deployment Costs:**

**Option 1: Vercel (RECOMMENDED)** ⭐
- ✅ **FREE** for hobby projects
- ✅ Unlimited deployments
- ✅ Automatic SSL certificates
- ✅ Global CDN
- ✅ Easy subdomain setup
- ⚠️ Pro Plan: $20/month (only if you need more features)

**Option 2: Netlify**
- ✅ **FREE** for personal projects
- Similar features to Vercel

**Option 3: Your own VPS**
- 💰 $5-10/month (DigitalOcean, Linode)
- More control, but more setup

---

## 🏗️ **RECOMMENDED ARCHITECTURE**

```
PrepSkul/
├── prepskul_app/          # Flutter app (iOS, Android, Web)
│   └── supabase/          # Database schema
│
└── PrepSkul_Web/          # Next.js (Main site + Admin)
    ├── app/
    │   ├── [locale]/      # Main website (www.prepskul.com)
    │   │   ├── page.tsx
    │   │   ├── about/
    │   │   └── contact/
    │   │
    │   └── admin/         # Admin dashboard (admin.prepskul.com) ⭐ NEW
    │       ├── layout.tsx
    │       ├── page.tsx   # Dashboard home
    │       ├── login/
    │       ├── tutors/
    │       │   ├── pending/
    │       │   ├── approved/
    │       │   └── rejected/
    │       ├── users/
    │       ├── sessions/
    │       └── analytics/
    │
    └── lib/
        └── supabase.ts    # Shared Supabase client
```

---

## 📝 **IMPLEMENTATION PLAN**

### **Option A: Single Project with Routes** ⭐ **RECOMMENDED**

**Pros:**
- ✅ Share components, utilities, Supabase client
- ✅ Single codebase, easier maintenance
- ✅ Single deployment
- ✅ Shared authentication logic

**Cons:**
- ⚠️ Slightly larger bundle size (but Next.js optimizes this)

**How it works:**
- Main site: `/app/[locale]/...` → `www.prepskul.com`
- Admin: `/app/admin/...` → `admin.prepskul.com`
- Use Next.js middleware to route based on domain

---

### **Option B: Separate Projects** (Not Recommended)

**Pros:**
- Complete separation
- Smaller individual bundle sizes

**Cons:**
- ❌ Duplicate code (Supabase client, types, utilities)
- ❌ Two separate deployments
- ❌ Harder to maintain
- ❌ More complexity

---

## 🚀 **STEP-BY-STEP SETUP (OPTION A)**

### **Step 1: Create Admin Routes in Next.js**

```typescript
// PrepSkul_Web/app/admin/layout.tsx
import { redirect } from 'next/navigation';
import { createServerSupabaseClient } from '@/lib/supabase-server';

export default async function AdminLayout({
  children,
}: {
  children: React.ReactNode;
}) {
  const supabase = createServerSupabaseClient();
  const { data: { user } } = await supabase.auth.getUser();

  // Check if user is admin
  if (!user) {
    redirect('/admin/login');
  }

  const { data: profile } = await supabase
    .from('profiles')
    .select('role, is_admin')
    .eq('id', user.id)
    .single();

  if (!profile?.is_admin) {
    return <div>Unauthorized</div>;
  }

  return (
    <div className="admin-layout">
      <AdminSidebar />
      <main>{children}</main>
    </div>
  );
}
```

```typescript
// PrepSkul_Web/app/admin/page.tsx
export default function AdminDashboard() {
  return (
    <div>
      <h1>Admin Dashboard</h1>
      {/* Stats, charts, etc. */}
    </div>
  );
}
```

```typescript
// PrepSkul_Web/app/admin/tutors/pending/page.tsx
import { createServerSupabaseClient } from '@/lib/supabase-server';

export default async function PendingTutors() {
  const supabase = createServerSupabaseClient();
  
  const { data: tutors } = await supabase
    .from('tutor_profiles')
    .select('*, profiles(*)')
    .eq('status', 'pending')
    .order('created_at', { ascending: false });

  return (
    <div>
      <h1>Pending Tutor Applications</h1>
      {tutors?.map((tutor) => (
        <TutorCard key={tutor.id} tutor={tutor} />
      ))}
    </div>
  );
}
```

---

### **Step 2: Setup Supabase Client**

```typescript
// PrepSkul_Web/lib/supabase.ts
import { createClient } from '@supabase/supabase-js';

export const supabase = createClient(
  process.env.NEXT_PUBLIC_SUPABASE_URL!,
  process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY!
);
```

```typescript
// PrepSkul_Web/lib/supabase-server.ts (for server components)
import { createServerClient } from '@supabase/ssr';
import { cookies } from 'next/headers';

export function createServerSupabaseClient() {
  const cookieStore = cookies();

  return createServerClient(
    process.env.NEXT_PUBLIC_SUPABASE_URL!,
    process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY!,
    {
      cookies: {
        get(name: string) {
          return cookieStore.get(name)?.value;
        },
      },
    }
  );
}
```

---

### **Step 3: Add Middleware for Domain Routing** (Optional)

If you want different UI/behavior based on subdomain:

```typescript
// PrepSkul_Web/middleware.ts
import { NextResponse } from 'next/server';
import type { NextRequest } from 'next/server';

export function middleware(request: NextRequest) {
  const hostname = request.headers.get('host') || '';
  
  // Admin subdomain
  if (hostname.startsWith('admin.')) {
    // Redirect to /admin route if not already there
    if (!request.nextUrl.pathname.startsWith('/admin')) {
      const url = request.nextUrl.clone();
      url.pathname = `/admin${url.pathname}`;
      return NextResponse.rewrite(url);
    }
  }
  
  // Main site
  if (hostname.startsWith('www.') || hostname === 'prepskul.com') {
    // Block access to /admin routes on main domain
    if (request.nextUrl.pathname.startsWith('/admin')) {
      return NextResponse.redirect(new URL('/', request.url));
    }
  }
  
  return NextResponse.next();
}

export const config = {
  matcher: ['/((?!api|_next/static|_next/image|favicon.ico).*)'],
};
```

---

### **Step 4: Update Database Schema**

Add admin permissions to profiles:

```sql
-- PrepSkul_Web/supabase/admin_schema.sql

-- Add is_admin column to profiles
ALTER TABLE profiles 
ADD COLUMN is_admin BOOLEAN DEFAULT FALSE;

-- Add status columns to tutor_profiles
ALTER TABLE tutor_profiles 
ADD COLUMN IF NOT EXISTS status TEXT DEFAULT 'pending' 
  CHECK (status IN ('pending', 'approved', 'rejected'));

ADD COLUMN IF NOT EXISTS admin_review_notes TEXT;
ADD COLUMN IF NOT EXISTS reviewed_by UUID REFERENCES auth.users(id);
ADD COLUMN IF NOT EXISTS reviewed_at TIMESTAMPTZ;

-- Create admin_actions table for audit log
CREATE TABLE admin_actions (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  admin_id UUID REFERENCES auth.users(id) NOT NULL,
  action_type TEXT NOT NULL, -- 'approve_tutor', 'reject_tutor', 'ban_user'
  target_id UUID NOT NULL,
  target_type TEXT NOT NULL, -- 'tutor', 'user', 'session'
  details JSONB,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Create index
CREATE INDEX idx_admin_actions_admin ON admin_actions(admin_id);
CREATE INDEX idx_admin_actions_created ON admin_actions(created_at DESC);

-- Row Level Security
ALTER TABLE admin_actions ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Admins can view all actions"
ON admin_actions FOR SELECT
TO authenticated
USING (
  EXISTS (
    SELECT 1 FROM profiles
    WHERE profiles.id = auth.uid()
    AND profiles.is_admin = TRUE
  )
);

CREATE POLICY "Admins can insert actions"
ON admin_actions FOR INSERT
TO authenticated
WITH CHECK (
  EXISTS (
    SELECT 1 FROM profiles
    WHERE profiles.id = auth.uid()
    AND profiles.is_admin = TRUE
  )
);
```

---

### **Step 5: Deploy to Vercel**

#### **A. Connect Your Project to Vercel**

1. Go to [vercel.com](https://vercel.com)
2. Sign in with GitHub
3. Import your `PrepSkul_Web` repository
4. Configure:
   - Framework: Next.js
   - Root Directory: `PrepSkul_Web`
   - Build Command: `pnpm build`
   - Output Directory: `.next`

#### **B. Add Environment Variables**

In Vercel dashboard → Settings → Environment Variables:

```env
NEXT_PUBLIC_SUPABASE_URL=https://cpzaxdfxbamdsshdgjyg.supabase.co
NEXT_PUBLIC_SUPABASE_ANON_KEY=eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...
```

#### **C. Configure Domains**

In Vercel dashboard → Settings → Domains:

1. **Main domain:**
   - Add: `prepskul.com`
   - Add: `www.prepskul.com` (redirects to prepskul.com)

2. **Admin subdomain:**
   - Add: `admin.prepskul.com`

Vercel will automatically provide SSL certificates! 🔒

---

### **Step 6: Configure DNS (Your Domain Registrar)**

Go to your domain registrar (where you bought prepskul.com):

**Add these DNS records:**

```
Type    Name    Value                       TTL
A       @       76.76.21.21                3600  (Vercel IP)
A       www     76.76.21.21                3600
CNAME   admin   cname.vercel-dns.com.      3600
```

**Note:** The exact IPs/CNAME will be provided by Vercel when you add the domains.

---

## 🔒 **SECURITY CONSIDERATIONS**

### **1. Admin Authentication**

```typescript
// PrepSkul_Web/lib/admin-auth.ts
import { supabase } from './supabase';

export async function isAdmin(userId: string): Promise<boolean> {
  const { data } = await supabase
    .from('profiles')
    .select('is_admin')
    .eq('id', userId)
    .single();
  
  return data?.is_admin === true;
}

export async function requireAdmin(userId: string) {
  const admin = await isAdmin(userId);
  if (!admin) {
    throw new Error('Unauthorized: Admin access required');
  }
}
```

### **2. Separate Admin Users**

Create admin accounts manually in Supabase:

```sql
-- Make a user admin
UPDATE profiles 
SET is_admin = TRUE 
WHERE email = 'admin@prepskul.com';
```

### **3. Two-Factor Authentication** (Optional V2)

Add 2FA for admin accounts using Supabase Auth.

---

## 📊 **ADMIN DASHBOARD FEATURES (Week 1)**

### **Phase 1: Tutor Management**

```typescript
// PrepSkul_Web/app/admin/tutors/pending/page.tsx

- View all pending tutor applications
- See complete profile:
  - Personal info
  - Academic background
  - Experience
  - Uploaded documents
  - ID verification
  - Video intro
- Approve/Reject with notes
- Send email/SMS notification
```

### **Phase 2: User Management**

```typescript
// PrepSkul_Web/app/admin/users/page.tsx

- View all users (tutors, students, parents)
- Search/filter by role, status, date
- View user details
- Ban/suspend users
- View activity logs
```

### **Phase 3: Analytics**

```typescript
// PrepSkul_Web/app/admin/analytics/page.tsx

- Total users (by role)
- Active sessions
- Revenue (total, this month)
- Growth charts
- Top tutors
```

---

## 🎨 **ADMIN UI DESIGN**

Use a clean, professional admin template:

### **Option 1: Build from Scratch** ⭐

Use shadcn/ui (you already have it!):

```bash
cd PrepSkul_Web

# Install additional components
npx shadcn-ui@latest add table
npx shadcn-ui@latest add badge
npx shadcn-ui@latest add data-table
npx shadcn-ui@latest add form
```

### **Option 2: Use Admin Template**

Free templates:
- [shadcn/ui Admin](https://github.com/shadcn-ui/ui/tree/main/apps/www/app/examples)
- [Next Admin](https://github.com/salimi-my/next-admin)

---

## 📦 **FOLDER STRUCTURE**

```
PrepSkul_Web/
├── app/
│   ├── [locale]/              # Main website
│   │   ├── layout.tsx
│   │   ├── page.tsx
│   │   ├── about/
│   │   └── ...
│   │
│   └── admin/                 # Admin dashboard ⭐
│       ├── layout.tsx         # Admin layout (sidebar, nav)
│       ├── page.tsx           # Dashboard home
│       │
│       ├── login/
│       │   └── page.tsx       # Admin login
│       │
│       ├── tutors/
│       │   ├── page.tsx       # All tutors
│       │   ├── pending/       # Pending approval
│       │   ├── approved/      # Approved tutors
│       │   └── rejected/      # Rejected tutors
│       │
│       ├── users/
│       │   ├── page.tsx       # All users
│       │   ├── students/
│       │   └── parents/
│       │
│       ├── sessions/
│       │   ├── page.tsx       # All sessions
│       │   ├── scheduled/
│       │   ├── completed/
│       │   └── cancelled/
│       │
│       ├── transactions/
│       │   └── page.tsx       # Payment history
│       │
│       └── analytics/
│           └── page.tsx       # Charts & stats
│
├── components/
│   ├── admin/                 # Admin-only components ⭐
│   │   ├── admin-sidebar.tsx
│   │   ├── admin-header.tsx
│   │   ├── tutor-review-card.tsx
│   │   ├── stats-card.tsx
│   │   └── ...
│   │
│   └── ...                    # Shared components
│
├── lib/
│   ├── supabase.ts            # Supabase client
│   ├── supabase-server.ts     # Server-side client
│   ├── admin-auth.ts          # Admin authentication
│   └── ...
│
└── middleware.ts              # Domain routing
```

---

## 🚀 **DEPLOYMENT CHECKLIST**

### **Before Launch:**
- [ ] Test admin authentication
- [ ] Test tutor approval flow
- [ ] Test email/SMS notifications
- [ ] Test on mobile (responsive)
- [ ] Setup proper error handling
- [ ] Add loading states
- [ ] Test with real data
- [ ] Security audit (RLS policies)
- [ ] Performance testing
- [ ] SSL certificate (automatic with Vercel)

### **After Launch:**
- [ ] Monitor logs
- [ ] Track admin actions
- [ ] User feedback
- [ ] Performance monitoring
- [ ] Regular backups

---

## 💡 **TIPS & BEST PRACTICES**

### **1. Keep Admin Separate**
- Use `/admin` route prefix
- Separate layout and design
- Different authentication flow

### **2. Use Server Components**
- Fetch data on the server
- Better performance
- More secure

### **3. Audit Logging**
- Log all admin actions
- Who approved/rejected what
- Timestamp everything

### **4. Rate Limiting**
- Prevent brute force attacks
- Use Vercel Edge Config or Upstash

### **5. Backup Plan**
- Regular database backups
- Export critical data
- Have rollback plan

---

## 📝 **NEXT STEPS**

1. ✅ **Review this guide**
2. ✅ **Confirm architecture (Option A recommended)**
3. ✅ **Install dependencies:**
   ```bash
   cd PrepSkul_Web
   pnpm add @supabase/supabase-js @supabase/ssr
   ```
4. ✅ **Create admin routes** (`app/admin/...`)
5. ✅ **Setup Supabase client**
6. ✅ **Update database schema** (add `is_admin`)
7. ✅ **Build tutor review UI**
8. ✅ **Deploy to Vercel**
9. ✅ **Configure DNS**
10. ✅ **Test end-to-end**

---

## ❓ **FAQ**

**Q: Do I need to buy a new domain?**  
A: No! Subdomains are free with your existing domain.

**Q: Will this affect my main website?**  
A: No! They're completely separate routes.

**Q: Can I use a different database for admin?**  
A: You can, but it's better to share the same Supabase database.

**Q: How much does Vercel cost?**  
A: FREE for hobby projects. $20/month for Pro (only if needed).

**Q: Can I deploy to my own server?**  
A: Yes, but Vercel is easier and handles SSL, CDN, etc.

**Q: How do I create the first admin user?**  
A: Manually in Supabase:
```sql
UPDATE profiles SET is_admin = TRUE WHERE email = 'your@email.com';
```

**Q: Is it secure?**  
A: Yes, if you follow the authentication and RLS policies correctly.

---

## 🎯 **COST SUMMARY**

| Item | Cost |
|------|------|
| Subdomain (admin.prepskul.com) | **FREE** ✅ |
| Vercel Hosting (Hobby) | **FREE** ✅ |
| Vercel Hosting (Pro) | $20/month (optional) |
| Supabase (Free tier) | **FREE** ✅ |
| Supabase (Pro) | $25/month (when you grow) |
| Domain (already owned) | Already paid |
| **Total for V1:** | **$0** 🎉 |

---

## 📞 **READY TO BUILD?**

Let me know when you're ready, and I'll help you:
1. Create the admin routes
2. Setup authentication
3. Build the tutor review interface
4. Deploy to Vercel

**Let's do this! 🚀**

