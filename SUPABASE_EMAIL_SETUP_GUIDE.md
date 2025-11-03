# 📧 Supabase Email Branding Setup

## ✅ **What's Ready:**
- ✅ `SUPABASE_EMAIL_CONFIRMATION_TEMPLATE.html` - Branded email template
- ✅ Logo files copied to Next.js public folder
- ✅ URL ready: `https://prepskul.com/logo-white.png`

---

## 📋 **Setup Steps:**

### **1. Upload Logo to Public (If Not Already)**
The logo is already in Next.js public folder at:
- `/Users/user/Desktop/PrepSkul/PrepSkul_Web/public/logo-white.png`

**If deploying to production:**
- Upload to Vercel with your Next.js app
- Logo will be accessible at: `https://www.prepskul.com/logo-white.png`

---

### **2. Update Supabase Email Template**

1. **Go to Supabase Dashboard:**
   - https://app.supabase.com
   - Select your project
   - Go to: **Authentication** → **Email Templates**

2. **Select "Confirm signup" Template**

3. **Copy the Content:**
   - Open: `SUPABASE_EMAIL_CONFIRMATION_TEMPLATE.html`
   - Copy ALL content (Cmd+A, Cmd+C)

4. **Paste in Supabase:**
   - Delete existing template
   - Paste new content

5. **Save Template**

---

### **3. Test It**

1. Sign up a new user in your app
2. Check email inbox
3. Should see PrepSkul logo (white on blue header)!

---

## 🎨 **What Changed:**

### **Before:**
```html
<div class="logo">📚</div>
```

### **After:**
```html
<img src="https://prepskul.com/logo-white.png" alt="PrepSkul" class="logo" />
```

---

## 🔄 **For All Email Templates:**

You can also update:
- **Magic Link** template
- **Password Reset** template
- **Change Email** template

Just replace the book icon with:
```html
<img src="https://prepskul.com/logo-white.png" alt="PrepSkul" class="logo" />
```

---

## 📝 **Quick Reference:**

**Logo URLs:**
- White on blue: `https://prepskul.com/logo-white.png`
- Blue on white: `https://prepskul.com/logo-blue.png`

**Email Colors:**
- Primary: `#1B2C4F` (Deep blue)
- Secondary: `#4A6FBF` (Light blue)
- Text: `#1F2937` (Dark gray)
- Light text: `#6B7280` (Medium gray)

---

**That's it! Your Supabase emails are now branded! 🎉**




## ✅ **What's Ready:**
- ✅ `SUPABASE_EMAIL_CONFIRMATION_TEMPLATE.html` - Branded email template
- ✅ Logo files copied to Next.js public folder
- ✅ URL ready: `https://prepskul.com/logo-white.png`

---

## 📋 **Setup Steps:**

### **1. Upload Logo to Public (If Not Already)**
The logo is already in Next.js public folder at:
- `/Users/user/Desktop/PrepSkul/PrepSkul_Web/public/logo-white.png`

**If deploying to production:**
- Upload to Vercel with your Next.js app
- Logo will be accessible at: `https://www.prepskul.com/logo-white.png`

---

### **2. Update Supabase Email Template**

1. **Go to Supabase Dashboard:**
   - https://app.supabase.com
   - Select your project
   - Go to: **Authentication** → **Email Templates**

2. **Select "Confirm signup" Template**

3. **Copy the Content:**
   - Open: `SUPABASE_EMAIL_CONFIRMATION_TEMPLATE.html`
   - Copy ALL content (Cmd+A, Cmd+C)

4. **Paste in Supabase:**
   - Delete existing template
   - Paste new content

5. **Save Template**

---

### **3. Test It**

1. Sign up a new user in your app
2. Check email inbox
3. Should see PrepSkul logo (white on blue header)!

---

## 🎨 **What Changed:**

### **Before:**
```html
<div class="logo">📚</div>
```

### **After:**
```html
<img src="https://prepskul.com/logo-white.png" alt="PrepSkul" class="logo" />
```

---

## 🔄 **For All Email Templates:**

You can also update:
- **Magic Link** template
- **Password Reset** template
- **Change Email** template

Just replace the book icon with:
```html
<img src="https://prepskul.com/logo-white.png" alt="PrepSkul" class="logo" />
```

---

## 📝 **Quick Reference:**

**Logo URLs:**
- White on blue: `https://prepskul.com/logo-white.png`
- Blue on white: `https://prepskul.com/logo-blue.png`

**Email Colors:**
- Primary: `#1B2C4F` (Deep blue)
- Secondary: `#4A6FBF` (Light blue)
- Text: `#1F2937` (Dark gray)
- Light text: `#6B7280` (Medium gray)

---

**That's it! Your Supabase emails are now branded! 🎉**



