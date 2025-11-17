# 📱 Testing Push Notifications on iOS

**Priority:** Critical  
**Status:** Ready for Testing  
**Device Required:** Real iOS device (not simulator)

---

## ⚠️ **Important Notes**

1. **iOS Simulator Limitations:**
   - APNS (Apple Push Notification Service) is NOT available on iOS Simulator
   - FCM tokens will NOT be generated on simulator
   - You MUST test on a real iOS device

2. **Prerequisites:**
   - Real iOS device (iPhone/iPad)
   - App built with proper provisioning profile
   - Firebase project configured for iOS
   - APNs certificate/key configured in Firebase Console

---

## 🧪 **Test Checklist**

### **Phase 1: Initial Setup & Token Storage**

#### ✅ **Test 1.1: App Launch & Permission Request**
- [ ] Launch app on real iOS device
- [ ] Complete login/onboarding
- [ ] Verify permission dialog appears (after 2 seconds delay)
- [ ] Grant notification permission
- [ ] Check console logs for:
  - `✅ APNS token obtained: [token]`
  - `✅ FCM token obtained: [token]`
  - `✅ FCM token stored in database`

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
ORDER BY created_at DESC;
```

**Expected Results:**
- [ ] Token exists in database
- [ ] `platform` = 'ios'
- [ ] `is_active` = true
- [ ] `device_id` is populated
- [ ] `device_name` shows device info
- [ ] `app_version` is populated

#### ✅ **Test 1.3: Token Refresh**
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
   - [ ] Console shows: `📱 Foreground message received: [messageId]`

#### ✅ **Test 2.2: Notification Tap (Foreground)**
- [ ] Tap on notification while app is in foreground
- [ ] Verify navigation occurs (if configured)
- [ ] Check console logs for notification tap

---

### **Phase 3: Background Notifications**

#### ✅ **Test 3.1: Receive Notification While App is in Background**
1. Put app in background (press home button)
2. Send test notification
3. Verify:
   - [ ] System notification appears in notification center
   - [ ] Notification shows title and body
   - [ ] Sound plays
   - [ ] Badge updates (if configured)

#### ✅ **Test 3.2: Notification Tap (Background)**
- [ ] Tap notification from notification center
- [ ] Verify app opens
- [ ] Verify navigation to correct screen (if configured)
- [ ] Check console logs: `📱 Notification tapped: [messageId]`

---

### **Phase 4: Terminated State Notifications**

#### ✅ **Test 4.1: Receive Notification While App is Terminated**
1. Force close app completely
2. Send test notification
3. Verify:
   - [ ] System notification appears
   - [ ] Notification shows title and body
   - [ ] Sound plays

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
    "action_url": "/trials/123"
  }
}
```

Verify:
- [ ] Notification displays correctly
- [ ] Data payload is received
- [ ] Navigation works based on data

#### ✅ **Test 5.2: Notification Sound**
- [ ] Verify default sound plays
- [ ] Test with custom sound (if configured)
- [ ] Test with sound disabled

---

### **Phase 6: Edge Cases**

#### ✅ **Test 6.1: Permission Denied**
1. Deny notification permission initially
2. Verify:
   - [ ] App continues to work
   - [ ] No crashes
   - [ ] User can enable in Settings later

#### ✅ **Test 6.2: Multiple Devices**
- [ ] Login on multiple iOS devices
- [ ] Verify each device gets its own token
- [ ] Send notification to user
- [ ] Verify all devices receive notification

#### ✅ **Test 6.3: Logout & Token Deactivation**
- [ ] Logout from app
- [ ] Verify console shows: `✅ All FCM tokens deactivated for user`
- [ ] Verify token `is_active` = false in database
- [ ] Verify no notifications received after logout

---

## 🔍 **Debugging Commands**

### **Check Console Logs**
Look for these key log messages:
- `✅ PushNotificationService initialized`
- `✅ APNS token obtained`
- `✅ FCM token obtained`
- `✅ FCM token stored in database`
- `📱 Foreground message received`
- `📱 Notification tapped`
- `📱 App opened from terminated state via notification`

### **Check Database**
```sql
-- Get all tokens for a user
SELECT * FROM fcm_tokens WHERE user_id = '[USER_ID]';

-- Check if token is active
SELECT COUNT(*) FROM fcm_tokens 
WHERE user_id = '[USER_ID]' AND is_active = true;

-- Get latest token
SELECT * FROM fcm_tokens 
WHERE user_id = '[USER_ID]' 
ORDER BY updated_at DESC 
LIMIT 1;
```

### **Check Permission Status**
In the app, you can check permission status via:
```dart
final status = await PushNotificationService().getPermissionStatus();
print('Permission status: $status');
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
  "message": "This is a test notification to verify push notifications work",
  "priority": "high",
  "sendEmail": false,
  "sendPush": true,
  "actionUrl": "/notifications",
  "actionText": "View Notifications"
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
    "sendPush": true
  }'
```

### **Method 2: Via Firebase Console**

1. Go to Firebase Console → Cloud Messaging
2. Click "Send test message"
3. Enter FCM token (from database query above)
4. Enter notification title and body
5. Click "Test"

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
- Console shows: `⚠️ APNS token not available yet`
- No token in database

**Solutions:**
1. ✅ Verify you're on a REAL device (not simulator)
2. ✅ Check Firebase Console → Project Settings → Cloud Messaging → APNs Authentication Key
3. ✅ Verify app is built with proper provisioning profile
4. ✅ Check that notification permission was granted
5. ✅ Wait a few seconds after permission grant (APNS token may take time)

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

### **Issue 4: Notification Tap Doesn't Navigate**
**Symptoms:**
- Notification received but tap doesn't navigate

**Solutions:**
1. ✅ Check `onNotificationTap` callback is set
2. ✅ Verify navigation logic in callback
3. ✅ Check console logs for tap events
4. ✅ Verify data payload contains navigation info

---

## 📊 **Success Criteria**

✅ **All tests pass when:**
1. FCM token is obtained and stored on real iOS device
2. Permission dialog appears and works correctly
3. Foreground notifications display correctly
4. Background notifications appear in notification center
5. Terminated state notifications work
6. Notification taps navigate correctly
7. Token is deactivated on logout
8. Multiple devices work independently

---

## 🚀 **Next Steps After Testing**

Once iOS testing is complete:
1. ✅ Document any issues found
2. ✅ Fix any bugs discovered
3. ✅ Move to Android testing (mvp-critical-2)
4. ✅ Test notification sending from backend

---

## 📝 **Test Results Template**

```
Date: [DATE]
Device: [DEVICE MODEL, iOS VERSION]
App Version: [VERSION]

Phase 1: Initial Setup
- [ ] Test 1.1: Pass/Fail
- [ ] Test 1.2: Pass/Fail
- [ ] Test 1.3: Pass/Fail

Phase 2: Foreground
- [ ] Test 2.1: Pass/Fail
- [ ] Test 2.2: Pass/Fail

Phase 3: Background
- [ ] Test 3.1: Pass/Fail
- [ ] Test 3.2: Pass/Fail

Phase 4: Terminated
- [ ] Test 4.1: Pass/Fail
- [ ] Test 4.2: Pass/Fail

Phase 5: Content
- [ ] Test 5.1: Pass/Fail
- [ ] Test 5.2: Pass/Fail

Phase 6: Edge Cases
- [ ] Test 6.1: Pass/Fail
- [ ] Test 6.2: Pass/Fail
- [ ] Test 6.3: Pass/Fail

Issues Found:
1. [ISSUE DESCRIPTION]
2. [ISSUE DESCRIPTION]

Overall Status: ✅ PASS / ❌ FAIL
```

---

**Ready to test!** Follow the checklist above and document results. 🎯

