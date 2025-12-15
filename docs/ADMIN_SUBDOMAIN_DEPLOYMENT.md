# Admin Subdomain Deployment Guide

## How It Works

### **1. Subdomain Detection (Already Implemented)**
The middleware automatically detects which domain is being accessed:
- `www.prepskul.com` → Main site with localization
- `admin.prepskul.com` → Admin dashboard only

### **2. Automatic Routing**
```
admin.prepskul.com/           → Redirects to /admin
admin.prepskul.com/admin      → Admin dashboard
admin.prepskul.com/login      → Redirects to /admin/login
www.prepskul.com/admin        → Can be blocked (optional)
```

---

## Deployment Steps

### **Step 1: Deploy to Vercel**
```bash
cd /Users/user/Desktop/PrepSkul/PrepSkul_Web
vercel --prod
```

### **Step 2: Add Admin Subdomain in Vercel**
1. Go to https://vercel.com/dashboard
2. Select your project (PrepSkul_Web)
3. Go to **Settings** → **Domains**
4. Click **Add Domain**
5. Enter: `admin.prepskul.com`
6. Click **Add**
7. Vercel will show you a CNAME record (example: `cname.vercel-dns.com`)

### **Step 3: Configure DNS**
Go to your domain registrar (where you bought prepskul.com) and add:

```
Type:  CNAME
Name:  admin
Value: cname.vercel-dns.com  (use the value Vercel gave you)
TTL:   Auto or 3600
```

### **Step 4: Wait for DNS Propagation**
- Usually takes 5-30 minutes
- Check status: https://dnschecker.org/#CNAME/admin.prepskul.com

### **Step 5: Test**
```
https://admin.prepskul.com       → Should redirect to /admin
https://admin.prepskul.com/admin → Admin dashboard
https://www.prepskul.com         → Main site
```

---

## SEO & Security (Hiding Admin from Search)

### **3. Hide Admin from Search Engines**

#### **Option 1: robots.txt (Recommended)**
Create or update `/Users/user/Desktop/PrepSkul/PrepSkul_Web/public/robots.txt`:

```txt
# Allow main site
User-agent: *
Allow: /
Disallow: /admin
Disallow: /api/admin

# Admin subdomain - block everything
User-agent: *
Disallow: /
Host: admin.prepskul.com
```

#### **Option 2: Meta Tags (Added to Admin Pages)**
Already implemented in admin pages, but we can add to layout:

```tsx
// In /app/admin/layout.tsx
export const metadata = {
  robots: {
    index: false,
    follow: false,
    googleBot: {
      index: false,
      follow: false,
    },
  },
}
```

#### **Option 3: X-Robots-Tag Header**
Add to `next.config.js`:

```js
async headers() {
  return [
    {
      source: '/admin/:path*',
      headers: [
        {
          key: 'X-Robots-Tag',
          value: 'noindex, nofollow',
        },
      ],
    },
  ]
}
```

---

## Security Best Practices

### **4. Additional Security Measures**

#### **Block /admin on Main Domain (Optional)**
Uncomment this line in `middleware.ts`:
```typescript
// To block admin access from main domain:
if (!isAdminSubdomain && pathname.startsWith('/admin')) {
  return NextResponse.redirect(new URL('/', request.url))
}
```

#### **Rate Limiting for Admin Login**
Add to `/app/admin/login/page.tsx` or use Vercel Edge Config:
```typescript
// Implement rate limiting (3 attempts per 15 minutes)
// Use Vercel KV or Upstash Redis
```

#### **IP Allowlist (Optional - Enterprise)**
For extra security, restrict admin access to specific IPs in Vercel:
- Settings → Firewall → IP Allowlist

#### **2FA (Future Enhancement)**
Add two-factor authentication using:
- Supabase Auth MFA
- Google Authenticator
- SMS OTP

---

## Testing Locally with Subdomain

To test subdomain behavior locally:

### **Option 1: Edit /etc/hosts**
```bash
sudo nano /etc/hosts
```
Add:
```
127.0.0.1 admin.prepskul.local
127.0.0.1 www.prepskul.local
```

Then access:
- `http://admin.prepskul.local:3003`
- `http://www.prepskul.local:3003`

### **Option 2: Use ngrok**
```bash
ngrok http 3003 --subdomain=admin-prepskul
```

---

## Summary

### **What Happens After Deployment:**

✅ `admin.prepskul.com` → Admin dashboard only  
✅ `www.prepskul.com` → Main site  
✅ Admin pages hidden from Google (robots.txt + meta tags)  
✅ Authentication required for all admin pages  
✅ Subdomain detection automatic  
✅ No `/en/admin` or `/fr/admin` interference  

### **Cost:**
- **$0** - Subdomains are free on Vercel
- Same deployment, same project
- No extra infrastructure needed

### **Maintenance:**
- One codebase
- One deployment
- Easy updates

---

## Quick Checklist

- [ ] Deploy to Vercel (`vercel --prod`)
- [ ] Add `admin.prepskul.com` in Vercel domains
- [ ] Add CNAME record in DNS
- [ ] Wait for DNS propagation (5-30 min)
- [ ] Test admin login at `https://admin.prepskul.com`
- [ ] Verify robots.txt is blocking admin routes
- [ ] Test main site still works at `https://www.prepskul.com`
- [ ] Check Google Search Console (no admin pages indexed)

---

## Need Help?

- Vercel Docs: https://vercel.com/docs/concepts/projects/domains
- DNS Check: https://dnschecker.org
- Robots.txt Tester: https://www.google.com/webmasters/tools/robots-testing-tool

