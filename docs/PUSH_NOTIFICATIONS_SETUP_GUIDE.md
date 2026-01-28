# Push Notifications Setup Guide

**Status:** Service implemented, needs configuration and testing  
**Priority:** Critical for production

---

## Overview

Push notifications are implemented using Firebase Cloud Messaging (FCM). The service is complete but requires configuration and testing before production.

---

## What's Already Implemented

### Flutter App
- ✅ Push notification service (`lib/core/services/push_notification_service.dart`)
- ✅ FCM token storage in database
- ✅ Permission requests
- ✅ Foreground/background/terminated notification handling
- ✅ Local notifications for foreground messages

### Backend (Next.js)
- ✅ Firebase Admin service (`PrepSkul_Web/lib/services/firebase-admin.ts`)
- ✅ Push notification sending API (`/api/notifications/send`)
- ✅ FCM token management

### Database
- ✅ `fcm_tokens` table schema
- ✅ Token storage and retrieval

---

## Configuration Required

### 1. Firebase Service Account Key

**Location:** Next.js environment variables

1. Go to Firebase Console: https://console.firebase.google.com
2. Select your project
3. Go to **Project Settings** → **Service Accounts**
4. Click **Generate New Private Key**
5. Download the JSON file
6. Convert JSON to base64 string (or store as JSON string in env var)

**Add to Next.js `.env.local`:**
```env
FIREBASE_SERVICE_ACCOUNT_KEY='{"type":"service_account","project_id":"...","private_key_id":"...","private_key":"...","client_email":"...","client_id":"...","auth_uri":"...","token_uri":"...","auth_provider_x509_cert_url":"...","client_x509_cert_url":"..."}'
```

**Or use base64 encoding:**
```bash
# Convert JSON to base64
cat firebase-service-account.json | base64
```

Then in `.env.local`:
```env
FIREBASE_SERVICE_ACCOUNT_KEY_BASE64='<base64_string>'
```

**Note:** Update `PrepSkul_Web/lib/services/firebase-admin.ts` to handle base64 if using that method.

---

### 2. iOS APNS Configuration

**Required for iOS push notifications**

1. Go to Apple Developer Portal: https://developer.apple.com
2. Create APNs Key:
   - Certificates, Identifiers & Profiles → Keys
   - Click **+** to create new key
   - Enable **Apple Push Notifications service (APNs)**
   - Download the `.p8` key file
   - Note the **Key ID** and **Team ID**

2. Upload to Firebase:
   - Go to Firebase Console → Project Settings → Cloud Messaging
   - Under **Apple app configuration**, click **Upload**
   - Upload the `.p8` file
   - Enter **Key ID** and **Team ID**
   - Select your iOS app

**Alternative: APNs Certificate (older method)**
- Create APNs Certificate in Apple Developer Portal
- Upload `.p12` file to Firebase

---

### 3. Android Configuration

**Android is already configured** if you have:
- ✅ `google-services.json` in `android/app/`
- ✅ Firebase project linked to Android app

**Verify:**
- Check `android/app/build.gradle` has Firebase dependencies
- Check `android/app/google-services.json` exists

---

## Testing Checklist

### Android Testing

1. **Build and Install:**
   ```bash
   flutter build apk
   # Install on Android device
   ```

2. **Test Token Generation:**
   - Launch app
   - Grant notification permission
   - Check logs for: `✅ FCM token obtained: [token]`
   - Verify token in database:
     ```sql
     SELECT * FROM fcm_tokens WHERE platform = 'android' ORDER BY created_at DESC LIMIT 1;
     ```

3. **Test Notification Sending:**
   - Send test notification from backend:
     ```bash
     curl -X POST https://www.prepskul.com/api/notifications/send \
       -H "Content-Type: application/json" \
       -H "Authorization: Bearer YOUR_TOKEN" \
       -d '{
         "userId": "USER_ID",
         "title": "Test Notification",
         "body": "This is a test push notification"
       }'
     ```
   - Verify notification received on device

4. **Test Notification States:**
   - [ ] Foreground: Local notification appears
   - [ ] Background: Notification appears in system tray
   - [ ] Terminated: Notification appears when app is closed

---

### iOS Testing

**⚠️ IMPORTANT: iOS Simulator does NOT support push notifications. You MUST test on a real iOS device.**

1. **Build and Install:**
   ```bash
   flutter build ios
   # Install on iOS device via Xcode
   ```

2. **Test Token Generation:**
   - Launch app on real iOS device
   - Grant notification permission
   - Check logs for:
     - `✅ APNS token obtained: [token]`
     - `✅ FCM token obtained: [token]`
   - Verify token in database:
     ```sql
     SELECT * FROM fcm_tokens WHERE platform = 'ios' ORDER BY created_at DESC LIMIT 1;
     ```

3. **Test Notification Sending:**
   - Same as Android (use API endpoint)
   - Verify notification received on device

4. **Test Notification States:**
   - [ ] Foreground: Local notification appears
   - [ ] Background: Notification appears in notification center
   - [ ] Terminated: Notification appears when app is closed

---

## Troubleshooting

### Issue: FCM Token Not Generated

**Android:**
- Check `google-services.json` is in `android/app/`
- Verify Firebase project is linked
- Check app has internet permission

**iOS:**
- Verify APNs certificate/key uploaded to Firebase
- Check app is built with proper provisioning profile
- Ensure testing on real device (not simulator)

### Issue: Notifications Not Received

1. **Check Token in Database:**
   ```sql
   SELECT * FROM fcm_tokens WHERE user_id = 'USER_ID' AND is_active = true;
   ```

2. **Check Firebase Console:**
   - Go to Cloud Messaging → Test message
   - Send test notification with FCM token
   - Check if notification is delivered

3. **Check App Logs:**
   - Look for FCM errors
   - Check notification permission status

4. **Check Backend Logs:**
   - Verify Firebase Admin initialized
   - Check for errors in `/api/notifications/send`

### Issue: Notifications Work in Foreground but Not Background

- Check notification channel configuration (Android)
- Verify background message handler is registered
- Check app has background refresh enabled (iOS)

---

## Production Deployment

### Environment Variables

**Next.js (Vercel/Production):**
```env
FIREBASE_SERVICE_ACCOUNT_KEY='<json_string>'
# OR
FIREBASE_SERVICE_ACCOUNT_KEY_BASE64='<base64_string>'
```

**Flutter App:**
- No additional env vars needed
- Uses Firebase config from `firebase_options.dart`

### Verification Steps

1. ✅ Firebase service account key configured
2. ✅ APNs certificate/key uploaded (iOS)
3. ✅ Test notifications sent successfully
4. ✅ Notifications received in all app states
5. ✅ Deep linking from notifications works

---

## Next Steps

1. **Configure Firebase Service Account Key** (30 min)
2. **Upload APNs Certificate/Key** (15 min)
3. **Test on Android Device** (30 min)
4. **Test on iOS Device** (30 min)
5. **Verify Deep Linking** (15 min)

**Total Estimated Time:** 2 hours

---

## Files Reference

- Flutter Service: `prepskul_app/lib/core/services/push_notification_service.dart`
- Backend Service: `PrepSkul_Web/lib/services/firebase-admin.ts`
- API Endpoint: `PrepSkul_Web/app/api/notifications/send/route.ts`
- Database Schema: `prepskul_app/supabase/migrations/020_fcm_tokens.sql`

---

**Status:** Ready for configuration and testing

