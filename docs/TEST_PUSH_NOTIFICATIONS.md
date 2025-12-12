# 🧪 Test Push Notifications - Step by Step Guide

**Date:** January 2025

---

## 🎯 **Quick Test Steps**

### **Step 1: Verify FCM Token is Stored** ✅

1. **Open Flutter App:**
   ```bash
   flutter run
   ```

2. **Grant Notification Permission:**
   - App will request permission
   - Click "Allow"
   - Check console for: `✅ FCM token: ...`

3. **Check Database:**
   ```sql
   -- In Supabase SQL Editor
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
   - Should see your FCM token
   - `is_active` should be `true`

---

### **Step 2: Send Test Notification via Admin Panel** ✅

1. **Go to Admin Panel:**
   ```
   https://www.prepskul.com/admin/notifications/send
   ```

2. **Get Your User ID:**
   - Open Flutter app
   - Go to Profile
   - Copy your user UUID
   - Or check Supabase: `SELECT id FROM profiles WHERE email = 'your-email';`

3. **Fill Notification Form:**
   ```
   User ID: [paste your UUID]
   Type: admin_message
   Title: 🧪 Test Push Notification
   Message: This is a test push notification. If you see this, push notifications are working!
   Priority: normal
   ✅ Send email notification
   ✅ Send push notification (if checkbox available)
   ```

4. **Click "Send Notification"**

5. **Check Result Toast:**
   ```
   ✅ Success: Notification sent successfully!
   In-app: ✅ | Email: ✅ | Push: ✅ (1 device)
   ```
   
   **If Push shows ❌:**
   - Check FCM token exists in database
   - Check Next.js API is deployed
   - Check Firebase Admin SDK is configured

---

### **Step 3: Verify Push Notification Received** ✅

#### **On Device (Android/iOS):**
- ✅ **Notification appears** in system tray
- ✅ **Sound plays** (if enabled)
- ✅ **Vibration** (if enabled)
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

## 🔍 **Troubleshooting**

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

## 📊 **Test Automatic Notifications**

### **Test Booking Request Notification:**

1. **Create Booking Request:**
   - Student creates booking request
   - Tutor should automatically receive:
     - ✅ In-app notification
     - ✅ Email notification
     - ✅ Push notification

2. **Verify:**
   - Check tutor's notification bell
   - Check tutor's email
   - Check tutor's device for push notification

### **Test Session Reminder:**

1. **Create Session:**
   - Book a session for tomorrow
   - Session reminders automatically scheduled

2. **Wait for Reminder:**
   - 24 hours before: Reminder sent
   - 1 hour before: Reminder sent
   - 15 minutes before: Reminder sent

3. **Verify:**
   - Check notifications received
   - Check push notification appears

---

## ✅ **Success Criteria**

Push notifications are working if:
- ✅ FCM token stored in database
- ✅ Admin panel shows `Push: ✅ (1 device)`
- ✅ Notification appears on device
- ✅ Sound/vibration works
- ✅ Tap notification opens app
- ✅ Automatic notifications also work

---

## 📝 **Quick Reference**

**Admin Panel:** `https://www.prepskul.com/admin/notifications/send`

**API Endpoint:** `POST /api/notifications/send`

**FCM Tokens Table:** `fcm_tokens` in Supabase

**Check Token:**
```sql
SELECT * FROM fcm_tokens WHERE user_id = 'your-id';
```

---

**Test and verify push notifications are working!** 🚀


