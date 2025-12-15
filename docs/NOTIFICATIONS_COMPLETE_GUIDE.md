# 🔔 Complete Notification Guide

**Date:** January 2025

---

## ✅ **Answer: Notifications are BOTH Automatic AND Manual**

### **🤖 AUTOMATIC Notifications (90% of all notifications)**

**These are sent automatically when events occur - NO manual action needed!**

#### **Automatic Triggers:**

1. **Booking Events:**
   - ✅ Student creates booking → Tutor automatically notified
   - ✅ Tutor accepts booking → Student automatically notified
   - ✅ Tutor rejects booking → Student automatically notified

2. **Payment Events:**
   - ✅ Payment received → Tutor automatically notified
   - ✅ Payment successful → Student automatically notified
   - ✅ Payment failed → Student automatically notified

3. **Session Events:**
   - ✅ Session reminders (24h, 1h, 15min) → Both parties automatically notified
   - ✅ Session completed → Both parties automatically notified
   - ✅ Feedback reminders → Student automatically notified

4. **Profile Events:**
   - ✅ Profile approved → Tutor automatically notified
   - ✅ Profile rejected → Tutor automatically notified
   - ✅ Profile needs improvement → Tutor automatically notified

**How Automatic Notifications Work:**
```dart
// Example: When tutor approves booking
await NotificationHelperService.notifyBookingRequestAccepted(
  studentId: studentId,
  tutorId: tutorId,
  requestId: requestId,
  tutorName: tutorName,
  subject: subject,
);
// ↑ This is called AUTOMATICALLY in the code
// No admin needs to do anything!
```

---

### **👤 MANUAL Notifications (Admin Panel - 10% of notifications)**

**These are sent manually by admins for special messages.**

#### **When to Use:**
- 📢 Announcements to all users
- 📢 System updates
- 📢 Custom messages to specific users
- 📢 Important notifications

#### **How to Send:**
1. **Go to Admin Panel:**
   ```
   https://www.prepskul.com/admin/notifications/send
   ```

2. **Fill the Form:**
   - **User ID:** User's UUID (get from Supabase or app)
   - **Type:** Notification type (admin_message, etc.)
   - **Title:** Notification title
   - **Message:** Notification message
   - **Priority:** low/normal/high/urgent
   - **Action URL:** Deep link (optional)
   - **Action Text:** Button text (optional)
   - ✅ **Send email notification** (checkbox)
   - ✅ **Send push notification** (checkbox)

3. **Click "Send Notification"**

4. **Check Result:**
   - Toast shows: `In-app: ✅ | Email: ✅ | Push: ✅ (1 device)`
   - If push shows `❌`, check FCM token exists

---

## 🧪 **How to Test Push Notifications**

### **Step 1: Verify FCM Token is Stored**

**In Supabase SQL Editor:**
```sql
SELECT 
  user_id,
  token,
  device_type,
  is_active,
  created_at
FROM fcm_tokens
WHERE user_id = 'your-user-id'
ORDER BY created_at DESC;
```

**Expected Result:**
- Should see at least one row
- `is_active` should be `true`
- `token` should be a long string

**If Empty:**
- Open Flutter app
- Grant notification permission
- Check console for FCM token
- Token should be stored automatically

---

### **Step 2: Send Test Notification via Admin Panel**

1. **Get Your User ID:**
   ```sql
   SELECT id FROM profiles WHERE email = 'your-email@example.com';
   ```

2. **Go to Admin Panel:**
   ```
   https://www.prepskul.com/admin/notifications/send
   ```

3. **Fill Form:**
   ```
   User ID: [paste your UUID]
   Type: admin_message
   Title: 🧪 Test Push Notification
   Message: This is a test push notification. If you see this on your device, push notifications are working!
   Priority: normal
   ✅ Send email notification
   ✅ Send push notification
   ```

4. **Click "Send Notification"**

5. **Check Toast Message:**
   ```
   ✅ Success: Notification sent successfully!
   In-app: ✅ | Email: ✅ | Push: ✅ (1 device)
   ```
   
   **If Push shows `❌`:**
   - FCM token not found in database
   - Next.js API not deployed
   - Firebase Admin SDK not configured

---

### **Step 3: Verify Push Notification Received**

#### **On Device:**
- ✅ **Notification appears** in system notification tray
- ✅ **Sound plays** (if enabled)
- ✅ **Vibration** (if enabled on Android)
- ✅ **Badge** shows on app icon

#### **Tap Notification:**
- ✅ **App opens** (if closed)
- ✅ **Navigates** to correct screen
- ✅ **Deep link** works

#### **In App (if open):**
- ✅ **Notification appears** in notification bell
- ✅ **Badge** shows unread count
- ✅ **Real-time update** (if app is open)

---

## 📊 **Notification Channels**

All notifications (automatic AND manual) are sent via **3 channels**:

| Channel | Status | Automatic? | Manual? |
|---------|--------|------------|---------|
| **In-App** | ✅ Always Works | ✅ Yes | ✅ Yes |
| **Email** | ✅ Always Works | ✅ Yes | ✅ Yes |
| **Push** | ✅ Works (when API deployed) | ✅ Yes | ✅ Yes |

---

## 🔍 **Troubleshooting Push Notifications**

### **Push Notification Not Received?**

1. **Check FCM Token:**
   ```sql
   SELECT * FROM fcm_tokens 
   WHERE user_id = 'your-user-id' 
   AND is_active = true;
   ```
   - If empty → Token not registered
   - Fix: Grant notification permission in app

2. **Check API Response:**
   - Admin panel toast shows push status
   - If `Push: ❌`, check:
     - Next.js API deployed?
     - Firebase Admin SDK configured?
     - FCM token valid?

3. **Check Device:**
   - Notification permission granted?
   - Device connected to internet?
   - App not force-stopped?

4. **Check Firebase Console:**
   - Go to Firebase Console → Cloud Messaging
   - Check if messages are being sent
   - Check delivery reports

---

## 📋 **Quick Reference**

### **Admin Panel:**
```
https://www.prepskul.com/admin/notifications/send
```

### **API Endpoint:**
```
POST /api/notifications/send
```

### **Check FCM Token:**
```sql
SELECT * FROM fcm_tokens WHERE user_id = 'your-id';
```

### **Test Automatic Notification:**
- Create a booking request
- Tutor should automatically receive notification
- Check all 3 channels (in-app, email, push)

---

## ✅ **Summary**

1. **Most notifications are AUTOMATIC** (booking, payment, session events)
2. **Admin panel is for MANUAL** notifications (announcements, custom messages)
3. **Both use same system** (in-app, email, push)
4. **Test push via admin panel** to verify it works

---

**See `TEST_PUSH_NOTIFICATIONS.md` for detailed testing steps!** 🚀


