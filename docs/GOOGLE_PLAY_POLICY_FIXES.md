# Google Play Policy Fixes - Implementation Guide

**Date:** January 2026  
**Status:** Code changes complete ✅ | Play Console actions required ⚠️

---

## ✅ Code Changes Completed

### 1. AndroidManifest.xml - Photo/Video Permissions Removed
- ✅ Removed `READ_MEDIA_IMAGES` permission
- ✅ Removed `READ_MEDIA_VIDEO` permission
- ✅ Kept `CAMERA` permission (still needed for taking photos)
- ✅ Kept `READ_EXTERNAL_STORAGE` with `maxSdkVersion="32"` (for Android 12 and below)
- ✅ Added comments explaining the change

**What this means:**
- Android 13+ devices will automatically use Android Photo Picker (no permission needed)
- Android 12 and below will use the existing storage permissions
- Camera permission remains for taking photos directly
- The `image_picker` package will automatically use Photo Picker when permissions aren't declared

---

## 📋 Play Console Actions Required

### Issue 1: Privacy Policy URL

**Problem:** Privacy policy link doesn't meet Google Play requirements.

**Correct Privacy Policy URL:**
- `https://www.prepskul.com/en/privacy-policy` ✅ (Confirmed by user)

**Steps to Fix:**

1. **Verify Privacy Policy Page:**
   - URL: `https://www.prepskul.com/en/privacy-policy`
   - Ensure the page is:
     - ✅ HTML page (not PDF)
     - ✅ Publicly accessible (no login required)
     - ✅ Not password protected
     - ✅ Doesn't auto-download files
     - ✅ Accessible from anywhere in the world

2. **Update Privacy Policy URL in Play Console:**
   - Go to: **Play Console → Your App → Policy → App content → Privacy policy**
   - Enter: `https://www.prepskul.com/en/privacy-policy`
   - Click **Save**
   - Verify the URL is accessible by clicking "Test link" if available
   - Click **Save**
   - Verify the URL is accessible by clicking "Test link" if available

3. **If Privacy Policy Page Doesn't Exist:**
   - The page exists at: `PrepSkul_Web/app/[locale]/privacy-policy/page.tsx`
   - Ensure it's deployed and accessible at one of the URLs above
   - If using Next.js, make sure the route is properly configured

---

### Issue 2: Demo Account Credentials

**Problem:** Missing demo/guest account details for app review.

**Steps to Fix:**

1. **Create Demo Account:**
   - Create a test account in your app:
     - **Email:** `demo@prepskul.com` (or `review@prepskul.com`)
     - **Phone:** Use a test phone number (e.g., `+237612345678`)
     - **Role:** Tutor (to access all features)
     - **Full Name:** "Demo Tutor" or "Review Account"
   
2. **Complete Tutor Onboarding:**
   - Sign up as tutor with the demo account
   - Complete all onboarding steps:
     - Contact information
     - Academic background
     - Location
     - Teaching focus
     - Experience
     - Teaching style
     - Digital readiness
     - Availability
     - Payment
     - Verification documents (upload test documents)
     - Review and submit

3. **Approve Demo Account:**
   - Go to Admin Dashboard: `https://admin.prepskul.com/admin/tutors`
   - Find the demo tutor account
   - Approve the account (set status to "approved")
   - This ensures reviewers can access all features

4. **Add Credentials in Play Console:**
   - Go to: **Play Console → Your App → Policy → App content → App access**
   - Click **"Manage"** or **"Add credentials"**
   - Fill in:
     - **Email:** `demo@prepskul.com` (or your demo email)
     - **Password:** [The password you created]
   
5. **Add Instructions:**
   In the "Instructions" field, add:
   ```
   Demo Account Credentials:
   Email: demo@prepskul.com
   Password: [your password]
   
   Account Status: Pre-approved tutor account
   
   This account has full access to:
   - Tutor profile and dashboard
   - Student booking features
   - Session management
   - Video calls (Agora)
   - All app features
   
   The account is ready for review and has completed all onboarding steps.
   ```

6. **Alternative (If You Can't Create Demo Account):**
   If you prefer not to create a demo account, provide signup instructions:
   ```
   To review the app:
   1. Open the app and select "Sign Up"
   2. Choose "Tutor" as user type
   3. Sign up with phone number: +237612345678
   4. Complete OTP verification
   5. Complete tutor onboarding (all steps)
   6. Submit for approval
   
   Note: Account approval may take time. For faster review, please contact us at support@prepskul.com for a pre-approved test account.
   ```

---

### Issue 3: Camera Permission Justification (If Required)

**Note:** This may not be required if removing photo/video permissions resolves the issue, but prepare it just in case.

**Steps (if Google asks for justification):**

1. Go to: **Play Console → Your App → Policy → App content → Sensitive permissions and APIs**
2. Find **Camera** permission
3. Click **"Manage"** or **"Add justification"**
4. Fill in:

   **Permission:** Camera
   
   **Purpose:** Profile photos and document verification
   
   **Justification:**
   ```
   PrepSkul requires camera access for tutors to take profile photos and upload verification documents (ID cards, certificates) during the onboarding process. This is essential for tutor verification and trust-building with students. The camera is only used when the user explicitly chooses to take a photo, not for continuous access.
   ```

---

## 🚀 Next Steps

### 1. Build New App Bundle

After making the code changes, build a new app bundle:

```bash
cd prepskul_app
flutter clean
flutter pub get
flutter build appbundle --release
```

The new AAB will be at: `prepskul_app/build/app/outputs/bundle/release/app-release.aab`

### 2. Upload to Play Console

1. Go to: **Play Console → Your App → Production → Create new release** (or **Testing → Internal/Closed testing**)
2. Upload the new AAB file
3. In **Release notes**, add:
   ```
   Policy Compliance Update:
   - Removed photo/video permissions, now using Android Photo Picker
   - Updated privacy policy URL
   - Added demo account credentials for review
   - Fixed all policy violations
   ```

### 3. Submit for Review

1. Go to: **Play Console → Publishing overview**
2. Review all changes
3. Click **"Send changes to Google for review"**
4. Wait for review (typically 1-3 days)

---

## ✅ Verification Checklist

Before submitting, verify:

- [ ] AndroidManifest.xml updated (READ_MEDIA_IMAGES and READ_MEDIA_VIDEO removed)
- [ ] Privacy policy URL is accessible and correct in Play Console
- [ ] Demo account created and approved
- [ ] Demo account credentials added in Play Console → App access
- [ ] New app bundle built successfully
- [ ] App bundle uploaded to Play Console
- [ ] Release notes added
- [ ] Submitted for review

---

## 📝 Notes

### Why We Removed Photo/Video Permissions

Google Play's policy states that apps requiring **one-time or infrequent access** to photos/videos should use **Android Photo Picker** instead of declaring permissions. Since PrepSkul only needs photos for:
- Profile pictures (one-time upload)
- Document verification (one-time upload)
- SkulMate photo uploads (one-time upload)

We qualify for Photo Picker, which doesn't require permissions. The `image_picker` package automatically uses Photo Picker on Android 13+ when permissions aren't declared.

### Camera Permission

We kept the `CAMERA` permission because:
- It's required for taking photos directly (not just selecting from gallery)
- Tutors need to take photos of their ID cards and certificates
- This is a legitimate use case that requires camera access
- Google Play allows camera permission for this purpose

### Testing After Changes

After uploading the new build, test on:
- Android 13+ device: Should use Photo Picker (no permission prompt)
- Android 12 device: Should use storage permission (permission prompt)
- Camera functionality: Should still work with camera permission

---

## 🆘 If Issues Persist

If Google Play still rejects after these fixes:

1. **Check Play Console Messages:**
   - Go to **Policy → Policy status**
   - Read the detailed rejection reasons
   - Check if there are additional requirements

2. **Contact Google Play Support:**
   - Go to **Policy → Policy status → Issue details**
   - Click **"Submit an appeal"** (5-8 days wait time)
   - OR use **"Ask the Play Help Community"**

3. **Review Policy Requirements:**
   - Read: [Google Play Developer Program policies](https://play.google.com/about/developer-content-policy/)
   - Read: [Photo and Video Permissions policy](https://support.google.com/googleplay/android-developer/answer/9888170)

---

## 📞 Support

If you need help with any of these steps, refer to:
- Google Play Console Help: https://support.google.com/googleplay/android-developer
- Play Console Requirements: https://support.google.com/googleplay/android-developer/answer/9888170

---

**Last Updated:** January 2026  
**Status:** Ready for Play Console actions

