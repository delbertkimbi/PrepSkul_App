# Google OAuth Verification Checklist

## ✅ **Status: Fix 2 - Scope Mismatch**

### **Fix 1: Privacy Policy** ✅ DONE
- Privacy policy updated with Google Calendar section
- Video uploaded to Google

### **Fix 2: Scope Mismatch** 🔄 IN PROGRESS

---

## 🔧 **What We Fixed**

### **Code Changes:**

1. **`google_calendar_auth_service.dart`**
   - ✅ Removed `calendar.events` scope (redundant)
   - ✅ Now uses only: `https://www.googleapis.com/auth/calendar`

2. **`auth_service.dart`**
   - ✅ Already using only `calendar` scope
   - ✅ No changes needed

---

## 📋 **Google Cloud Console Checklist**

### **Step 1: Verify OAuth Consent Screen Scopes**

1. Go to: https://console.cloud.google.com/
2. Select your project
3. Navigate to: **APIs & Services** → **OAuth consent screen**
4. Scroll to **"Scopes"** section

**Required Configuration:**
- ✅ Should have: `https://www.googleapis.com/auth/calendar`
- ❌ Should NOT have: `https://www.googleapis.com/auth/calendar.events` (remove if present)

**If `calendar.events` is listed:**
1. Click the trash icon next to it
2. Click "Save and Continue"
3. This removes the redundant scope

---

### **Step 2: Verify App Information**

Check these fields are filled correctly:

- ✅ **App name**: "PrepSkul"
- ✅ **User support email**: `prepskul@gmail.com` (or your support email)
- ✅ **App logo**: Uploaded
- ✅ **Application homepage**: `https://prepskul.com` or `https://app.prepskul.com`
- ✅ **Privacy policy link**: `https://prepskul.com/privacy-policy` (must be accessible)
- ✅ **Authorized domains**: 
  - `prepskul.com`
  - `app.prepskul.com`

---

### **Step 3: Verify Scopes Match Code**

**In OAuth Consent Screen:**
- Should show: `https://www.googleapis.com/auth/calendar`

**In Code:**
- `google_calendar_auth_service.dart`: `['https://www.googleapis.com/auth/calendar']`
- `auth_service.dart`: `'https://www.googleapis.com/auth/calendar'`

**✅ They should match exactly!**

---

## 🎯 **Next Steps**

### **After Fixing Scope Mismatch:**

1. **Save changes in Google Cloud Console**
2. **Wait 5-10 minutes** for changes to propagate
3. **Test OAuth flow** to verify warning is reduced
4. **Check verification status** in OAuth consent screen

### **If Verification is Still Pending:**

1. Check **"Verification progress"** section
2. Look for any remaining errors
3. Address any new issues Google flags
4. Resubmit if needed

---

## ⚠️ **Important Notes**

- **Scope changes take effect immediately** (no propagation delay usually)
- **Verification review takes 1-7 days** after submission
- **Users will still see warning** until verification is approved
- **Test users** (up to 100) won't see warning if added to test users list

---

## ✅ **Verification Status**

Once all fixes are complete:
- ✅ Privacy policy updated
- ✅ Video uploaded
- ✅ Scope mismatch fixed
- ✅ App information complete

**Status:** Ready for Google review (1-7 days)

---

## 📝 **What to Tell Users (Temporary)**

Since app is not public yet and you're telling tutors to use email:

**Message for tutors:**
> "We're currently verifying our Google Calendar integration with Google. For now, please use email for session coordination. Google Calendar integration will be available once verification is complete (expected 1-7 days)."

This sets proper expectations while verification is in progress.

