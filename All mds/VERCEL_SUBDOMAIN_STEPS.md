# 🚀 Vercel Subdomain - Visual Step-by-Step

**Deploy admin.prepskul.com in 5 clicks**

---

## 📸 **VISUAL GUIDE**

### **Step 1: Go to Vercel Dashboard**

```
1. Visit: https://vercel.com/dashboard
2. Find your project (e.g., "prepskul-web")
3. Click on it
```

---

### **Step 2: Navigate to Domains**

```
Top Menu:
┌──────────────────────────────────────────┐
│ Overview  Analytics  Settings  Domains  │  ← Click "Domains"
└──────────────────────────────────────────┘
```

---

### **Step 3: Add New Domain**

```
┌─────────────────────────────────────────┐
│  Domains                                │
│                                         │
│  www.prepskul.com  ✅ Valid             │
│  prepskul.com      ✅ Valid             │
│                                         │
│  ┌────────────────────┐                │
│  │ Add Domain         │ ← Click this   │
│  └────────────────────┘                │
└─────────────────────────────────────────┘
```

---

### **Step 4: Enter Subdomain**

```
┌──────────────────────────────────────────┐
│  Add Domain                              │
│                                          │
│  Domain Name:                            │
│  ┌────────────────────────────────────┐  │
│  │ admin.prepskul.com                 │  │  ← Type this
│  └────────────────────────────────────┘  │
│                                          │
│         [Cancel]  [Add] ← Click         │
└──────────────────────────────────────────┘
```

---

### **Step 5: Vercel Shows DNS Instructions**

```
┌──────────────────────────────────────────────┐
│  Configure DNS for admin.prepskul.com       │
│                                              │
│  Add this record to your DNS provider:       │
│                                              │
│  Type:    CNAME                              │
│  Name:    admin                              │
│  Value:   cname.vercel-dns.com               │
│                                              │
│  ⚠️ DNS changes take 5-30 minutes            │
└──────────────────────────────────────────────┘
```

**Copy the CNAME value:** `cname.vercel-dns.com`

---

### **Step 6: Go to Your Domain Registrar**

Where you bought `prepskul.com` (e.g., Namecheap, GoDaddy, Google Domains, Cloudflare)

---

### **Step 7: Add DNS Record**

**Example (Namecheap):**

```
┌────────────────────────────────────────────────┐
│  DNS Records                                   │
│                                                │
│  Type     Host    Value                  TTL   │
│  ─────────────────────────────────────────────│
│  A         @       76.76.21.21          Auto  │
│  CNAME     www     prepskul.com         Auto  │
│  CNAME     admin   cname.vercel-dns.com Auto  │ ← Add this
│                                                │
│  [+ Add New Record]                            │
└────────────────────────────────────────────────┘
```

**Fill in:**
- Type: `CNAME`
- Host/Name: `admin`
- Value: `cname.vercel-dns.com`
- TTL: `Automatic` or `3600`

**Click Save!**

---

### **Step 8: Wait for DNS Propagation**

```
⏳ DNS propagating... (5-30 minutes)

Check status: https://dnschecker.org
Enter: admin.prepskul.com
```

---

### **Step 9: Verify in Vercel**

```
Back in Vercel → Domains:

┌─────────────────────────────────────────┐
│  Domains                                │
│                                         │
│  www.prepskul.com       ✅ Valid        │
│  prepskul.com           ✅ Valid        │
│  admin.prepskul.com     ⏳ Pending...  │ ← Wait for this
└─────────────────────────────────────────┘

After DNS propagates:

┌─────────────────────────────────────────┐
│  admin.prepskul.com     ✅ Valid        │
│  SSL Certificate:       ✅ Active       │
└─────────────────────────────────────────┘
```

---

### **Step 10: Visit Your Admin Site!**

```
🎉 Open browser:

https://admin.prepskul.com

You should see your admin dashboard!
```

---

## 🔧 **DOMAIN REGISTRAR GUIDES**

### **Namecheap:**

```
1. Login to Namecheap
2. Go to "Domain List"
3. Click "Manage" next to prepskul.com
4. Go to "Advanced DNS" tab
5. Click "Add New Record"
6. Select "CNAME Record"
7. Host: admin
8. Value: cname.vercel-dns.com
9. Click ✓ (checkmark) to save
```

---

### **GoDaddy:**

```
1. Login to GoDaddy
2. Go to "My Products"
3. Click "DNS" next to prepskul.com
4. Click "Add" button
5. Type: CNAME
6. Name: admin
7. Value: cname.vercel-dns.com
8. TTL: 1 hour
9. Click "Save"
```

---

### **Google Domains:**

```
1. Login to domains.google.com
2. Click prepskul.com
3. Go to "DNS" tab
4. Scroll to "Custom resource records"
5. Name: admin
6. Type: CNAME
7. Data: cname.vercel-dns.com
8. Click "Add"
```

---

### **Cloudflare:**

```
1. Login to Cloudflare
2. Select prepskul.com
3. Go to "DNS" tab
4. Click "Add record"
5. Type: CNAME
6. Name: admin
7. Target: cname.vercel-dns.com
8. Proxy status: DNS only (gray cloud)
9. Click "Save"
```

---

## ⚡ **QUICK TIPS**

### **Tip 1: Check DNS Propagation**

```bash
# Terminal command
dig admin.prepskul.com

# Or visit:
https://dnschecker.org
```

### **Tip 2: Force HTTPS**

Vercel automatically redirects HTTP → HTTPS.
No config needed! ✅

### **Tip 3: Multiple Subdomains**

You can add as many as you want:
- `admin.prepskul.com`
- `api.prepskul.com`
- `blog.prepskul.com`
- `app.prepskul.com`

All free! All with SSL! ✅

### **Tip 4: Remove www**

If you want just `admin.prepskul.com` (no www):
- Just add `admin.prepskul.com`
- Don't add `www.admin.prepskul.com`

Simple! ✅

---

## 🚨 **COMMON ISSUES**

### **Issue 1: "Domain is not configured"**

**Solution:** Wait longer. DNS takes time.

```
Check after:
- 5 minutes   ← Usually works
- 15 minutes  ← Should definitely work
- 30 minutes  ← Max wait time
```

---

### **Issue 2: "SSL Certificate Pending"**

**Solution:** Wait for DNS to fully propagate first.
Vercel auto-issues SSL after DNS is verified.

```
Vercel will show:
🔒 SSL Certificate: Provisioning...
       ↓ (wait 5 minutes)
✅ SSL Certificate: Active
```

---

### **Issue 3: "Cannot add domain - Already in use"**

**Solution:** Domain is used in another Vercel project.
- Remove it from old project first
- Or use a different subdomain

---

### **Issue 4: "404 Not Found"**

**Solution:** Your code isn't deployed.
- Make sure `app/admin/page.tsx` exists
- Push to GitHub
- Vercel auto-deploys
- Wait 1-2 minutes

---

## 📊 **DEPLOYMENT FLOW**

```
You write code
      ↓
Git commit & push
      ↓
GitHub receives push
      ↓
Vercel detects push (webhook)
      ↓
Vercel builds your app
      ↓
Vercel deploys to:
  ├─ prepskul-web.vercel.app (preview URL)
  ├─ www.prepskul.com
  └─ admin.prepskul.com
      ↓
✅ Live in 1-2 minutes!
```

**Automatic every time you push to main!** 🚀

---

## 🎯 **VERIFICATION CHECKLIST**

After adding subdomain:

- [ ] Domain shows in Vercel dashboard
- [ ] Status is ✅ "Valid Configuration"
- [ ] SSL shows ✅ "Active"
- [ ] Visit `https://admin.prepskul.com` works
- [ ] HTTPS (lock icon) shows in browser
- [ ] Content displays correctly

**All checked?** You're done! 🎉

---

## 💰 **COSTS REMINDER**

```
Vercel Hobby (Free):
✅ Unlimited domains
✅ Unlimited subdomains
✅ Automatic SSL
✅ Global CDN
✅ 100GB bandwidth/month
✅ 6,000 build minutes/month

Cost: $0 per month ✅
```

**When you need to upgrade:**
- 100+ GB bandwidth
- Password protection
- More team members
- Analytics

**Vercel Pro: $20/month**

But for V1, **free tier is perfect!** ✅

---

## ⏱️ **TIMELINE**

| Step | Time |
|------|------|
| Add domain in Vercel | 1 minute |
| Update DNS | 2 minutes |
| **Wait for DNS** | 5-30 minutes |
| SSL provisioning | Automatic (2 min) |
| **Total:** | **10-35 minutes** |

**Active work: 3 minutes**  
**Waiting: 7-32 minutes**

---

## 🚀 **NEXT STEPS**

Now that you understand how Vercel subdomains work:

1. **Create admin routes** in your Next.js project
2. **Push to GitHub** (Vercel auto-deploys)
3. **Add subdomain** in Vercel (3 clicks)
4. **Update DNS** (1 record)
5. **Wait & test** (5-30 min)

**Want me to help build the admin routes?** 💪

---

**Key Takeaway:**
> Vercel subdomains are **incredibly simple**. Just 3 clicks in Vercel + 1 DNS record = done! No server config, no SSL setup, no complications. It just works! 🎉

