# Fix 2: Scope Mismatch - Google Cloud Console Steps

## 🎯 **Goal: Fix Scope Mismatch in OAuth Consent Screen**

Your code now uses only `https://www.googleapis.com/auth/calendar`.  
Make sure Google Cloud Console matches this exactly.

---

## 📋 **Step-by-Step Instructions**

### **Step 1: Open OAuth Consent Screen**

1. Go to: **https://console.cloud.google.com/**
2. Select your **PrepSkul project**
3. In the left menu: **APIs & Services** → **OAuth consent screen**
4. You should see your app configuration

---

### **Step 2: Check Current Scopes**

1. Scroll down to **"Scopes"** section
2. You'll see a list of scopes your app requests

**What you should see:**
- ✅ `https://www.googleapis.com/auth/calendar` (KEEP THIS)
- ❌ `https://www.googleapis.com/auth/calendar.events` (REMOVE THIS if present)

---

### **Step 3: Remove `calendar.events` Scope (If Present)**

**If you see `calendar.events` in the list:**

1. Find the scope: `https://www.googleapis.com/auth/calendar.events`
2. Click the **trash/delete icon** (🗑️) next to it
3. Confirm deletion
4. **Important:** Click **"Save and Continue"** at the bottom

**Why remove it?**
- `calendar` scope already includes `calendar.events`
- Having both causes scope mismatch error
- Google sees you requesting more than needed

---

### **Step 4: Verify Final Scope Configuration**

**After removing `calendar.events`, you should have:**

**Scopes section should show:**
```
✅ https://www.googleapis.com/auth/calendar
```

**That's it! Only one scope.**

---

### **Step 5: Verify App Information (Quick Check)**

While you're here, verify these are filled:

- ✅ **App name**: "PrepSkul"
- ✅ **User support email**: Your email (e.g., `prepskul@gmail.com`)
- ✅ **Application homepage**: `https://prepskul.com` or `https://app.prepskul.com`
- ✅ **Privacy policy link**: `https://prepskul.com/privacy-policy`
- ✅ **Authorized domains**: 
  - `prepskul.com`
  - `app.prepskul.com`

---

### **Step 6: Save Changes**

1. Scroll to bottom of page
2. Click **"Save and Continue"**
3. Wait for confirmation

---

### **Step 7: Verify Changes Took Effect**

1. Refresh the page
2. Go back to **"Scopes"** section
3. Verify only `calendar` scope is listed
4. No `calendar.events` should be present

---

## ✅ **Verification Checklist**

After completing these steps:

- [ ] Only `https://www.googleapis.com/auth/calendar` is in scopes
- [ ] `calendar.events` scope is removed (if it was there)
- [ ] Changes saved successfully
- [ ] App information is complete
- [ ] Privacy policy link is accessible

---

## 🔍 **How to Verify Scope Mismatch is Fixed**

### **Check Verification Status:**

1. In OAuth consent screen, look for **"Verification progress"** or **"Publishing status"**
2. Check if **"Request minimum scopes"** error is gone
3. If still showing, wait 5-10 minutes for changes to propagate

### **Test OAuth Flow:**

1. Try signing in with Google in your app
2. Check if the consent screen shows correct scopes
3. Verify no scope mismatch warnings

---

## ⚠️ **Important Notes**

1. **Changes are immediate** - Usually no delay, but can take up to 10 minutes
2. **Verification still pending** - Fixing scope mismatch doesn't auto-approve verification
3. **Google review needed** - Still need to wait 1-7 days for Google to review
4. **Users still see warning** - Until verification is approved

---

## 📝 **What's Next?**

After Fix 2 is complete:

1. ✅ **Fix 1**: Privacy policy - DONE
2. ✅ **Fix 2**: Scope mismatch - IN PROGRESS (this guide)
3. ⏳ **Verification**: Wait for Google review (1-7 days)

Once Google approves:
- ✅ No more warning screen
- ✅ Users see normal consent screen
- ✅ Production ready

---

## 🆘 **Troubleshooting**

### **Issue: Can't find "Scopes" section**
- Make sure you're in **OAuth consent screen** (not API credentials)
- Scroll down - it's below app information

### **Issue: Can't delete scope**
- Make sure you're in **Edit mode**
- Some scopes might be required - `calendar.events` is NOT required if you have `calendar`

### **Issue: Changes not saving**
- Check if you have proper permissions
- Try refreshing and trying again
- Make sure all required fields are filled

### **Issue: Still seeing scope mismatch error**
- Wait 5-10 minutes for changes to propagate
- Clear browser cache and refresh
- Check if you saved changes properly

---

## ✅ **Summary**

**What you're doing:**
- Removing redundant `calendar.events` scope
- Keeping only `calendar` scope (which includes events)
- Making scopes match your code exactly

**Result:**
- Scope mismatch error fixed
- Ready for Google verification review
- One step closer to production approval

**Time needed:** 5-10 minutes






