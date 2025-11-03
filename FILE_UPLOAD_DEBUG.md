# 🐛 File Upload Debugging Guide

## **Current Status:**
- ✅ File picker v8.0.0 installed
- ✅ Dependencies up to date
- ✅ Code handles XFile + Uint8List for web
- ⏳ **User reporting uploads not working**

---

## **Test Steps:**

### **1. Clean & Rebuild:**
```bash
cd /Users/user/Desktop/PrepSkul/prepskul_app
flutter clean
flutter pub get
flutter run -d chrome --web-port=3000
```

### **2. Navigate to:**
- Complete tutor signup/survey
- Go to "Verification & Credentials" step
- Try uploading a document

### **3. Watch Console:**
Look for these messages:
- `📝 Uploading ...`
- `✅ Document uploaded:`
- `❌ Error uploading document:`

---

## **Known Issues & Fixes:**

### **Issue 1: "Cannot find symbol" (Android Build)**
**Status:** ✅ FIXED
**Solution:** Updated `file_picker` from 6.1.1 → 8.0.0

### **Issue 2: "On web path is unavailable"**
**Status:** ✅ FIXED
**Solution:** Using `XFile.readAsBytes()` for web

### **Issue 3: Storage bucket not found**
**Possible Cause:** Bucket doesn't exist in Supabase
**Check:**
```bash
# Go to: https://app.supabase.com
# Storage → Verify these buckets exist:
# - profile-photos
# - documents
# - videos
```

### **Issue 4: Permission error**
**Possible Cause:** RLS policies blocking uploads
**Check:** Supabase Storage bucket policies

---

## **Next Steps:**

1. **If upload works:** ✅ Great! Proceed with testing
2. **If upload fails:** 
   - Copy full console error
   - Note which browser
   - Note file type/size
   - Share screenshot

---

**Last Updated:** Now  
**Waiting for:** User test results




## **Current Status:**
- ✅ File picker v8.0.0 installed
- ✅ Dependencies up to date
- ✅ Code handles XFile + Uint8List for web
- ⏳ **User reporting uploads not working**

---

## **Test Steps:**

### **1. Clean & Rebuild:**
```bash
cd /Users/user/Desktop/PrepSkul/prepskul_app
flutter clean
flutter pub get
flutter run -d chrome --web-port=3000
```

### **2. Navigate to:**
- Complete tutor signup/survey
- Go to "Verification & Credentials" step
- Try uploading a document

### **3. Watch Console:**
Look for these messages:
- `📝 Uploading ...`
- `✅ Document uploaded:`
- `❌ Error uploading document:`

---

## **Known Issues & Fixes:**

### **Issue 1: "Cannot find symbol" (Android Build)**
**Status:** ✅ FIXED
**Solution:** Updated `file_picker` from 6.1.1 → 8.0.0

### **Issue 2: "On web path is unavailable"**
**Status:** ✅ FIXED
**Solution:** Using `XFile.readAsBytes()` for web

### **Issue 3: Storage bucket not found**
**Possible Cause:** Bucket doesn't exist in Supabase
**Check:**
```bash
# Go to: https://app.supabase.com
# Storage → Verify these buckets exist:
# - profile-photos
# - documents
# - videos
```

### **Issue 4: Permission error**
**Possible Cause:** RLS policies blocking uploads
**Check:** Supabase Storage bucket policies

---

## **Next Steps:**

1. **If upload works:** ✅ Great! Proceed with testing
2. **If upload fails:** 
   - Copy full console error
   - Note which browser
   - Note file type/size
   - Share screenshot

---

**Last Updated:** Now  
**Waiting for:** User test results



