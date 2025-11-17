# 📱 Testing Push Notifications on Android

**Priority:** Critical  
**Status:** Ready for Testing  
**Device Required:** Real Android device (emulator works but real device recommended)

---

## ⚠️ **Important Notes**

1. **Android Emulator vs Real Device:**
   - ✅ Android Emulator CAN receive push notifications (unlike iOS Simulator)
   - ✅ Real device recommended for full testing
   - ✅ Both work for basic functionality testing

2. **Prerequisites:**
   - Android device or emulator (API 21+)
   - App built with proper signing key
   - Firebase project configured for Android
   - Google Services JSON file configured
   - Internet connection

3. **Android Permission Model:**
   - Android 13+ (API 33+): Requires explicit runtime permission
   - Android 12 and below: Auto-granted (no permission dialog)
   - Notification channels required for Android 8.0+ (API 26+)

---

## 🧪 **Test Checklist**

### **Phase 1: Initial Setup & Token Storage**

#### ✅ **Test 1.1: App Launch & Permission Request**
- [ ] Launch app on Android device/emulator
- [ ] Complete login/onboarding
- [ ] **Android 13+:** Verify permission dialog appears (after 2 seconds delay)
- [ ] **Android 13+:** Grant notification permission
- [ ] **Android 12 and below:** No permission dialog (auto-granted)
- [ ] Check console logs for:
  - `✅ FCM token obtained: [token]`
  - `✅ FCM token stored in database`
  - `✅ Push notification mobile initialization completed`

#### ✅ **Test 1.2: Verify Token in Database**
Run this SQL query in Supabase:
```sql
SELECT 
  id,
  user_id,
  platform,
  device_id,
  device_name,
  app_version,
  is_active,
  created_at,
  updated_at
FROM fcm_tokens
WHERE user_id = '[YOUR_USER_ID]'
  AND platform = 'android'
ORDER BY created_at DESC;
```

**Expected Results:**
- [ ] Token exists in database
- [ ] `platform` = 'android'
- [ ] `is_active` = true
- [ ] `device_id` is populated (Android ID)
- [ ] `device_name` shows device info (e.g., "Samsung Galaxy S21")
- [ ] `app_version` is populated

#### ✅ **Test 1.3: Notification Channel Creation**
- [ ] Check console logs for: `✅ Notification channel created: prepskul_notifications`
- [ ] Go to Android Settings → Apps → PrepSkul → Notifications
- [ ] Verify "PrepSkul Notifications" channel exists
- [ ] Verify channel settings:
  - [ ] Importance: High
  - [ ] Sound: Enabled
  - [ ] Vibration: Enabled

#### ✅ **Test 1.4: Token Refresh**
- [ ] Force close app
- [ ] Reopen app
- [ ] Check console logs for token refresh
- [ ] Verify token updated in database (same token or new one)

---

### **Phase 2: Foreground Notifications**

#### ✅ **Test 2.1: Receive Notification While App is Open**
1. Keep app open and in foreground
2. Send test notification from backend/Postman
3. Verify:
   - [ ] Local notification appears at top of screen
   - [ ] Notification shows title and body
   - [ ] Sound plays (if enabled)
   - [ ] Vibration occurs (if enabled)
   - [ ] Console shows: `📱 Foreground message received: [messageId]`

#### ✅ **Test 2.2: Notification Tap (Foreground)**
- [ ] Tap on notification while app is in foreground
- [ ] Verify navigation occurs (if configured)
- [ ] Check console logs for notification tap

#### ✅ **Test 2.3: Notification Icon**
- [ ] Verify notification shows app icon
- [ ] Icon should be `@mipmap/ic_launcher` (default) or custom icon

---

### **Phase 3: Background Notifications**

#### ✅ **Test 3.1: Receive Notification While App is in Background**
1. Put app in background (press home button or switch app)
2. Send test notification
3. Verify:
   - [ ] System notification appears in notification drawer
   - [ ] Notification shows title and body
   - [ ] Sound plays
   - [ ] Vibration occurs
   - [ ] Notification appears in status bar

#### ✅ **Test 3.2: Notification Tap (Background)**
- [ ] Tap notification from notification drawer
- [ ] Verify app opens (brings to foreground)
- [ ] Verify navigation to correct screen (if configured)
- [ ] Check console logs: `📱 Notification tapped: [messageId]`

#### ✅ **Test 3.3: Notification Swipe Actions**
- [ ] Swipe notification to dismiss
- [ ] Verify notification is dismissed
- [ ] Verify app state remains correct

---

### **Phase 4: Terminated State Notifications**

#### ✅ **Test 4.1: Receive Notification While App is Terminated**
1. Force close app completely (swipe away from recent apps)
2. Send test notification
3. Verify:
   - [ ] System notification appears
   - [ ] Notification shows title and body
   - [ ] Sound plays
   - [ ] Vibration occurs

#### ✅ **Test 4.2: Open App from Terminated State via Notification**
- [ ] Tap notification when app is terminated
- [ ] Verify app launches
- [ ] Verify navigation to correct screen
- [ ] Check console logs: `📱 App opened from terminated state via notification`

---

### **Phase 5: Notification Content & Data**

#### ✅ **Test 5.1: Notification with Custom Data**
Send notification with custom data payload:
```json
{
  "notification": {
    "title": "Test Notification",
    "body": "This is a test"
  },
  "data": {
    "type": "trial_approved",
    "trial_id": "123",
    "action_url": "/trials/123",
    "sound": "default",
    "vibrate": "true"
  }
}
```

Verify:
- [ ] Notification displays correctly
- [ ] Data payload is received
- [ ] Navigation works based on data
- [ ] Sound plays (if specified)
- [ ] Vibration occurs (if specified)

#### ✅ **Test 5.2: Notification Sound**
- [ ] Verify default sound plays
- [ ] Test with custom sound (if configured)
- [ ] Test with sound disabled (`sound: "false"`)

#### ✅ **Test 5.3: Notification Vibration**
- [ ] Verify vibration occurs by default
- [ ] Test with vibration disabled (`vibrate: "false"`)
- [ ] Verify vibration pattern works

#### ✅ **Test 5.4: Notification Priority**
Test different priority levels:
- [ ] `priority: "low"` - Notification appears but may be silent
- [ ] `priority: "normal"` - Standard notification
- [ ] `priority: "high"` - Heads-up notification (Android 5.0+)
- [ ] `priority: "urgent"` - Critical notification

---

### **Phase 6: Notification Channels (Android 8.0+)**

#### ✅ **Test 6.1: Channel Settings**
- [ ] Go to Android Settings → Apps → PrepSkul → Notifications
- [ ] Verify "PrepSkul Notifications" channel exists
- [ ] Test channel settings:
  - [ ] Enable/disable channel
  - [ ] Change importance level
  - [ ] Toggle sound
  - [ ] Toggle vibration
  - [ ] Toggle badge

#### ✅ **Test 6.2: Multiple Channels (Future Enhancement)**
- [ ] If multiple channels are implemented, verify each works independently
- [ ] Test channel-specific settings

---

### **Phase 7: Edge Cases**

#### ✅ **Test 7.1: Permission Denied (Android 13+)**
1. Deny notification permission initially
2. Verify:
   - [ ] App continues to work
   - [ ] No crashes
   - [ ] User can enable in Settings → Apps → PrepSkul → Notifications

#### ✅ **Test 7.2: Multiple Devices**
- [ ] Login on multiple Android devices
- [ ] Verify each device gets its own token
- [ ] Send notification to user
- [ ] Verify all devices receive notification

#### ✅ **Test 7.3: Logout & Token Deactivation**
- [ ] Logout from app
- [ ] Verify console shows: `✅ All FCM tokens deactivated for user`
- [ ] Verify token `is_active` = false in database
- [ ] Verify no notifications received after logout

#### ✅ **Test 7.4: App Uninstall & Reinstall**
- [ ] Uninstall app
- [ ] Reinstall app
- [ ] Login again
- [ ] Verify new token is generated
- [ ] Verify old token is not used

#### ✅ **Test 7.5: Do Not Disturb Mode**
- [ ] Enable Do Not Disturb mode
- [ ] Send notification
- [ ] Verify notification behavior (may be silent or delayed)

#### ✅ **Test 7.6: Battery Optimization**
- [ ] Check if app is battery optimized
- [ ] Test notifications with battery optimization enabled/disabled
- [ ] Verify notifications work in both cases

---

## 🔍 **Debugging Commands**

### **Check Console Logs**
Look for these key log messages:
- `✅ PushNotificationService initialized`
- `✅ FCM token obtained`
- `✅ FCM token stored in database`
- `✅ Notification channel created: prepskul_notifications`
- `✅ Push notification mobile initialization completed`
- `📱 Foreground message received`
- `📱 Notification tapped`
- `📱 App opened from terminated state via notification`

### **Check Database**
```sql
-- Get all Android tokens for a user
SELECT * FROM fcm_tokens 
WHERE user_id = '[USER_ID]' AND platform = 'android';

-- Check if token is active
SELECT COUNT(*) FROM fcm_tokens 
WHERE user_id = '[USER_ID]' 
  AND platform = 'android' 
  AND is_active = true;

-- Get latest Android token
SELECT * FROM fcm_tokens 
WHERE user_id = '[USER_ID]' 
  AND platform = 'android'
ORDER BY updated_at DESC 
LIMIT 1;
```

### **Check Notification Channel (Android 8.0+)**
1. Go to Android Settings
2. Apps → PrepSkul → Notifications
3. Verify "PrepSkul Notifications" channel exists
4. Check channel settings (importance, sound, vibration)

### **Check Permission Status**
In the app, you can check permission status via:
```dart
final status = await PushNotificationService().getPermissionStatus();
print('Permission status: $status');
```

### **Android ADB Commands**
```bash
# Check if app has notification permission
adb shell dumpsys package com.prepskul.app | grep notification

# Check notification channels
adb shell dumpsys notification | grep -A 10 "prepskul"

# Clear app data (for testing)
adb shell pm clear com.prepskul.app

# View app logs
adb logcat | grep -i "prepskul\|fcm\|notification"
```

---

## 🧪 **Sending Test Notifications**

### **Method 1: Via API (Postman/cURL)**

**Endpoint:** `POST https://app.prepskul.com/api/notifications/send`

**Request Body:**
```json
{
  "userId": "YOUR_USER_ID_HERE",
  "type": "test_notification",
  "title": "Test Push Notification",
  "message": "This is a test notification to verify push notifications work on Android",
  "priority": "high",
  "sendEmail": false,
  "sendPush": true,
  "actionUrl": "/notifications",
  "actionText": "View Notifications",
  "metadata": {
    "sound": "default",
    "vibrate": "true"
  }
}
```

**cURL Command:**
```bash
curl -X POST https://app.prepskul.com/api/notifications/send \
  -H "Content-Type: application/json" \
  -d '{
    "userId": "YOUR_USER_ID_HERE",
    "type": "test_notification",
    "title": "Test Push Notification",
    "message": "This is a test notification",
    "priority": "high",
    "sendEmail": false,
    "sendPush": true,
    "metadata": {
      "sound": "default",
      "vibrate": "true"
    }
  }'
```

### **Method 2: Via Firebase Console**

1. Go to Firebase Console → Cloud Messaging
2. Click "Send test message"
3. Enter FCM token (from database query above)
4. Enter notification title and body
5. Add custom data (optional):
   ```json
   {
     "sound": "default",
     "vibrate": "true"
   }
   ```
6. Click "Test"

### **Method 3: Via Admin Dashboard**

1. Go to `https://admin.prepskul.com/admin/notifications/send`
2. Enter user ID
3. Fill in notification details
4. Click "Send Notification"

### **Get Your User ID**

Run this query in Supabase to get your user ID:
```sql
SELECT id, full_name, phone_number, email 
FROM profiles 
WHERE phone_number = 'YOUR_PHONE_NUMBER';
```

Or check the app logs after login - it should print the user ID.

---

## 🐛 **Common Issues & Solutions**

### **Issue 1: No FCM Token Generated**
**Symptoms:**
- Console shows: `⚠️ FCM token is null`
- No token in database

**Solutions:**
1. ✅ Verify Google Services JSON file is in `android/app/`
2. ✅ Check Firebase Console → Project Settings → Cloud Messaging → Server Key
3. ✅ Verify app is built with proper signing key
4. ✅ Check internet connection
5. ✅ Verify Firebase is initialized correctly
6. ✅ Check console for error messages

### **Issue 2: Token Not Stored in Database**
**Symptoms:**
- Token obtained but not in database
- Console shows: `⚠️ User not authenticated, cannot store FCM token`

**Solutions:**
1. ✅ Verify user is logged in before token is obtained
2. ✅ Check Supabase connection
3. ✅ Verify RLS policies allow token insertion
4. ✅ Check console for error messages

### **Issue 3: Notifications Not Received**
**Symptoms:**
- Token exists but notifications don't arrive

**Solutions:**
1. ✅ Verify token is active in database (`is_active = true`)
2. ✅ Check Firebase Console → Cloud Messaging → Send test message
3. ✅ Verify notification payload format is correct
4. ✅ Check device internet connection
5. ✅ Verify app is not in "Do Not Disturb" mode
6. ✅ Check if app is battery optimized (may delay notifications)
7. ✅ Verify notification channel is enabled (Android 8.0+)
8. ✅ Check notification permission (Android 13+)

### **Issue 4: Notification Tap Doesn't Navigate**
**Symptoms:**
- Notification received but tap doesn't navigate

**Solutions:**
1. ✅ Check `onNotificationTap` callback is set
2. ✅ Verify navigation logic in callback
3. ✅ Check console logs for tap events
4. ✅ Verify data payload contains navigation info

### **Issue 5: No Sound or Vibration**
**Symptoms:**
- Notification appears but no sound/vibration

**Solutions:**
1. ✅ Check notification channel settings (Android 8.0+)
2. ✅ Verify device is not in silent/Do Not Disturb mode
3. ✅ Check notification payload includes `sound: "default"`
4. ✅ Verify vibration is enabled in channel settings
5. ✅ Check device volume settings

### **Issue 6: Notification Channel Not Created**
**Symptoms:**
- No notification channel in Settings
- Notifications don't appear

**Solutions:**
1. ✅ Check console logs for channel creation
2. ✅ Verify channel ID matches: `prepskul_notifications`
3. ✅ Check if app has notification permission (Android 13+)
4. ✅ Reinstall app to recreate channel

---

## 📊 **Success Criteria**

✅ **All tests pass when:**
1. FCM token is obtained and stored on Android device
2. Permission dialog appears (Android 13+) or auto-granted (Android 12-)
3. Notification channel is created and visible in Settings
4. Foreground notifications display correctly
5. Background notifications appear in notification drawer
6. Terminated state notifications work
7. Notification taps navigate correctly
8. Sound and vibration work as expected
9. Token is deactivated on logout
10. Multiple devices work independently

---

## 🚀 **Next Steps After Testing**

Once Android testing is complete:
1. ✅ Document any issues found
2. ✅ Fix any bugs discovered
3. ✅ Compare results with iOS testing
4. ✅ Test notification sending from backend
5. ✅ Move to next critical feature (Payments, Calendar, etc.)

---

## 📝 **Test Results Template**

```
Date: [DATE]
Device: [DEVICE MODEL, ANDROID VERSION, API LEVEL]
App Version: [VERSION]

Phase 1: Initial Setup
- [ ] Test 1.1: Pass/Fail
- [ ] Test 1.2: Pass/Fail
- [ ] Test 1.3: Pass/Fail
- [ ] Test 1.4: Pass/Fail

Phase 2: Foreground
- [ ] Test 2.1: Pass/Fail
- [ ] Test 2.2: Pass/Fail
- [ ] Test 2.3: Pass/Fail

Phase 3: Background
- [ ] Test 3.1: Pass/Fail
- [ ] Test 3.2: Pass/Fail
- [ ] Test 3.3: Pass/Fail

Phase 4: Terminated
- [ ] Test 4.1: Pass/Fail
- [ ] Test 4.2: Pass/Fail

Phase 5: Content
- [ ] Test 5.1: Pass/Fail
- [ ] Test 5.2: Pass/Fail
- [ ] Test 5.3: Pass/Fail
- [ ] Test 5.4: Pass/Fail

Phase 6: Channels
- [ ] Test 6.1: Pass/Fail
- [ ] Test 6.2: Pass/Fail

Phase 7: Edge Cases
- [ ] Test 7.1: Pass/Fail
- [ ] Test 7.2: Pass/Fail
- [ ] Test 7.3: Pass/Fail
- [ ] Test 7.4: Pass/Fail
- [ ] Test 7.5: Pass/Fail
- [ ] Test 7.6: Pass/Fail

Issues Found:
1. [ISSUE DESCRIPTION]
2. [ISSUE DESCRIPTION]

Overall Status: ✅ PASS / ❌ FAIL
```

---

## 🔄 **Android vs iOS Differences**

| Feature | Android | iOS |
|---------|---------|-----|
| **Emulator Support** | ✅ Works | ❌ Doesn't work |
| **Permission Model** | Runtime (API 33+) | Always required |
| **Notification Channels** | ✅ Required (API 26+) | N/A |
| **Sound Control** | Via channel | Via payload |
| **Vibration Control** | Via channel | Via payload |
| **Token Generation** | Immediate | Requires APNS first |

---

**Ready to test!** Follow the checklist above and document results. 🎯

