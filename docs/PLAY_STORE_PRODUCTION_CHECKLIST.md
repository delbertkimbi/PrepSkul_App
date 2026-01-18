# Google Play Store Production Checklist

**Date:** January 2025  
**Status:** Code changes complete ✅

---

## ✅ Code Changes Completed

### 1. AndroidManifest.xml
- ✅ App label set to "PrepSkul" (was already correct)
- ✅ Google Maps API key removed (using Leaflet instead)

### 2. pubspec.yaml
- ✅ Description updated: "PrepSkul - Connect with verified tutors for personalized learning. Book trial sessions, schedule lessons, and track your progress."
- ✅ Version: 1.0.0+4

### 3. build.gradle.kts
- ✅ ABI splitting enabled (reduces APK size from 264MB to ~60-80MB per architecture)
- ✅ Minify enabled
- ✅ Resource shrinking enabled

---

## 📋 Play Console Requirements (Must Complete)

### 1. Privacy Policy (REQUIRED)
- [ ] Add privacy policy URL in Play Console: `https://www.prepskul.com/privacy-policy`
- [ ] Verify URL is publicly accessible
- [ ] Location: Play Console → App content → Privacy policy

### 2. Data Safety Section (REQUIRED)
Complete in Play Console → App content → Data safety:

**Data Collected:**
- [ ] **Personal info**: Name, Email, Phone
  - Purpose: App functionality
  - Data shared: No
  - Data encrypted: Yes
  - Deletion: Users can request deletion

- [ ] **Photos and videos**: Camera, Gallery
  - Purpose: App functionality (profile photos, document verification)
  - Data shared: No
  - Data encrypted: Yes
  - Deletion: Users can request deletion

- [ ] **Location**: Approximate location
  - Purpose: App functionality (find nearby tutors)
  - Data shared: No
  - Data encrypted: Yes
  - Deletion: Users can request deletion

- [ ] **Financial info**: Payment information
  - Purpose: App functionality (Fapshi payments)
  - Data shared: Yes (with Fapshi payment processor)
  - Data encrypted: Yes
  - Deletion: Users can request deletion

- [ ] **Device or other IDs**: Device ID
  - Purpose: Analytics, App functionality
  - Data shared: No
  - Data encrypted: Yes
  - Deletion: Users can request deletion

### 3. Sensitive Permissions Justification (REQUIRED)
In Play Console → App content → Sensitive permissions:

- [ ] **Location**: "To find nearby tutors and show location-based search results"
- [ ] **Camera**: "To upload profile photos and document verification for tutors"
- [ ] **Storage**: "To save and upload profile images and verification documents"

### 4. Store Listing (REQUIRED)
- [ ] **App name**: "PrepSkul" (max 50 chars)
- [ ] **Short description**: 80 chars max
  - Example: "Connect with verified tutors. Book sessions, track progress, learn better."
- [ ] **Full description**: 4000 chars max
  - Describe features, benefits, how it works
- [ ] **Screenshots**: At least 2 phone screenshots (1080x1920px)
  - Show: Tutor discovery, booking flow, session management
- [ ] **Feature graphic**: 1024x500px
- [ ] **App icon**: 512x512px (high-res)
- [ ] **Category**: Education

### 5. Content Rating (REQUIRED)
- [ ] Complete questionnaire in Play Console
- [ ] Age group: Likely "Everyone" or "Teen"
- [ ] Content: Educational content, no violence/adult content

### 6. Target Audience
- [ ] Set target audience: Students, parents, tutors
- [ ] Select target countries/regions

---

## 🏗️ Build App Bundle

### Before Building:
```bash
cd /Users/user/Desktop/PrepSkul/prepskul_app
flutter clean
flutter pub get
```

### Build App Bundle:
```bash
flutter build appbundle --release
```

### Output Location:
```
build/app/outputs/bundle/release/app-release.aab
```

**Expected size:** ~60-80MB per architecture (much smaller than 264MB universal APK)

---

## ✅ Pre-Submission Testing

- [ ] Test on Android 13+ device
- [ ] Test all core features:
  - [ ] Signup/Login
  - [ ] Tutor discovery
  - [ ] Booking flow
  - [ ] Payment flow (Fapshi)
  - [ ] Session management
- [ ] Test permission requests (Location, Camera, Storage)
- [ ] Test offline functionality
- [ ] Verify deep links work
- [ ] Test on multiple devices (if possible)
- [ ] Verify no crashes on startup
- [ ] Test payment flow end-to-end

---

## 📤 Submission Checklist

### Before Uploading:
- [ ] All code changes complete ✅
- [ ] App bundle built successfully
- [ ] Tested on real device
- [ ] No critical bugs

### In Play Console:
- [ ] Upload app bundle
- [ ] Complete store listing (all sections)
- [ ] Add privacy policy URL
- [ ] Complete data safety section
- [ ] Complete content rating questionnaire
- [ ] Justify sensitive permissions
- [ ] Add release notes
- [ ] Enable "App signing by Google Play"
- [ ] Test on internal/closed testing track first

### After Submission:
- [ ] Monitor for review status
- [ ] Respond to any rejection feedback promptly
- [ ] Address any policy violations
- [ ] Keep privacy policy updated

---

## 🚨 Common Rejection Reasons to Avoid

1. **Missing Privacy Policy**: Ensure URL is accessible
2. **Incomplete Data Safety**: Declare ALL data collection
3. **Misleading Metadata**: Description must match app functionality
4. **Insufficient Functionality**: Core features must work
5. **Permission Issues**: Request permissions at point of use, explain why
6. **API Level**: Ensure targetSdk is 33+ (Android 13+)

---

## 📝 Notes

- **ABI Splitting**: Creates separate APKs per architecture. Google Play will serve the correct one automatically.
- **App Bundle vs APK**: App Bundle (AAB) is required for Play Store. It's more efficient than APK.
- **Version Code**: Increment for each upload (currently at 4)
- **Privacy Policy**: Must be publicly accessible and cover all data collection

---

## 🎯 Next Steps

1. Complete all Play Console requirements above
2. Build app bundle: `flutter build appbundle --release`
3. Test thoroughly on real device
4. Upload to closed testing first
5. Fix any issues found in testing
6. Submit for production review

---

**Status:** Ready for app bundle build ✅  
**Last Updated:** January 2025


