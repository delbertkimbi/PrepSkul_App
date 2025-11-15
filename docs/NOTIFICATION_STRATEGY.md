# 📱 Notification Strategy & Delivery Matrix

**Last Updated:** January 2025

---

## 🎯 **Core Principle**

**In-app notifications are ALWAYS sent.** They are the foundation of our notification system and work regardless of API availability.

Push and email notifications are sent via the Next.js API when available, but the app gracefully degrades to in-app only if the API is unavailable.

---

## 📊 **Notification Delivery Matrix**

### **Trial Session Notifications**

| Event | Recipient | In-App | Push | Email | Priority |
|-------|-----------|--------|------|-------|----------|
| **Trial Request Created** | Tutor | ✅ Always | ✅ Via API | ✅ Via API | High |
| **Trial Request Accepted** | Student/Parent | ✅ Always | ✅ Via API | ✅ Via API | High |
| **Trial Request Rejected** | Student/Parent | ✅ Always | ✅ Via API | ✅ Via API | Normal |
| **Trial Payment Required** | Student/Parent | ✅ Always | ✅ Via API | ✅ Via API | High |
| **Trial Payment Successful** | Student/Parent | ✅ Always | ✅ Via API | ✅ Via API | Normal |
| **Trial Payment Failed** | Student/Parent | ✅ Always | ✅ Via API | ✅ Via API | High |

### **Booking Request Notifications**

| Event | Recipient | In-App | Push | Email | Priority |
|-------|-----------|--------|------|-------|----------|
| **Booking Request Created** | Tutor | ✅ Always | ✅ Via API | ✅ Via API | High |
| **Booking Request Accepted** | Student/Parent | ✅ Always | ✅ Via API | ✅ Via API | High |
| **Booking Request Rejected** | Student/Parent | ✅ Always | ✅ Via API | ✅ Via API | Normal |
| **Payment Request Created** | Student/Parent | ✅ Always | ✅ Via API | ✅ Via API | High |
| **Payment Successful** | Student/Parent | ✅ Always | ✅ Via API | ✅ Via API | Normal |
| **Payment Failed** | Student/Parent | ✅ Always | ✅ Via API | ✅ Via API | High |

### **Session Notifications**

| Event | Recipient | In-App | Push | Email | Priority | Scheduled |
|-------|-----------|--------|------|-------|----------|-----------|
| **Session Reminder (24h)** | Both | ✅ Always | ✅ Via API | ✅ Via API | Normal | ✅ 24h before |
| **Session Reminder (30min)** | Both | ✅ Always | ✅ Via API | ✅ Via API | High | ✅ 30min before |
| **Session Starting** | Both | ✅ Always | ✅ Via API | ✅ Via API | High | At start time |
| **Session Completed** | Both | ✅ Always | ✅ Via API | ✅ Via API | Normal | At end time |
| **Review Request (24h after)** | Student | ✅ Always | ✅ Via API | ✅ Via API | Normal | ✅ 24h after |

### **Payment Notifications**

| Event | Recipient | In-App | Push | Email | Priority |
|-------|-----------|--------|------|-------|----------|
| **Payment Received** | Tutor | ✅ Always | ✅ Via API | ✅ Via API | Normal |
| **Payment Successful** | Student/Parent | ✅ Always | ✅ Via API | ✅ Via API | Normal |
| **Payment Failed** | Student/Parent | ✅ Always | ✅ Via API | ✅ Via API | High |
| **Refund Processed** | Student/Parent | ✅ Always | ✅ Via API | ✅ Via API | Normal |

### **Profile Notifications**

| Event | Recipient | In-App | Push | Email | Priority |
|-------|-----------|--------|------|-------|----------|
| **Profile Approved** | Tutor | ✅ Always | ✅ Via API | ✅ Via API | High |
| **Profile Rejected** | Tutor | ✅ Always | ✅ Via API | ✅ Via API | High |
| **Profile Needs Improvement** | Tutor | ✅ Always | ✅ Via API | ✅ Via API | High |

---

## 🔄 **Notification Flow**

```
┌─────────────────────────────────────────────────────────────┐
│                    NOTIFICATION FLOW                         │
└─────────────────────────────────────────────────────────────┘

1. EVENT OCCURS (Flutter App)
   └─> Trial request created
   └─> Booking request created
   └─> Payment received
   └─> Session starting soon

2. STEP 1: CREATE IN-APP NOTIFICATION (Always)
   └─> NotificationService.createNotification()
   └─> Inserts into Supabase notifications table
   └─> ✅ GUARANTEED - Works even if API is down

3. STEP 2: SEND VIA API (Optional - Push + Email)
   └─> POST /api/notifications/send
   └─> Next.js API receives request
   │
   ├─> PUSH NOTIFICATION (Firebase Admin SDK)
   │   └─> Gets FCM token from Supabase
   │   └─> Sends via Firebase Cloud Messaging
   │   └─> ✅ Delivered to device (Android/iOS/Web)
   │   └─> Shows system notification with sound
   │   └─> User taps → Opens app → Deep link navigation
   │
   └─> EMAIL NOTIFICATION (Resend API)
       └─> Sends branded HTML email
       └─> ✅ Delivered to user's email
       └─> Contains deep link to app content

4. USER RECEIVES NOTIFICATIONS
   ├─> ✅ In-App: Visible in notification bell (always)
   ├─> ✅ Push: System notification (if API available)
   └─> ✅ Email: In inbox (if API available & sendEmail=true)
```

---

## 📍 **Where Notifications Are Sent**

### **In-App Notifications**
- **Where:** Supabase `notifications` table
- **When:** Always, immediately when event occurs
- **Delivery:** Real-time via Supabase Realtime
- **Visibility:** Notification bell icon, notification list screen
- **Reliability:** ✅ 100% - Works even if API is down

### **Push Notifications**
- **Where:** User's device (Android/iOS/Web)
- **When:** Via Next.js API (Firebase Admin SDK)
- **Delivery:** Firebase Cloud Messaging (FCM)
- **Visibility:** System notification tray
- **Reliability:** ⚠️ Requires API to be deployed
- **Fallback:** If API unavailable, user still gets in-app notification

### **Email Notifications**
- **Where:** User's email inbox
- **When:** Via Next.js API (Resend)
- **Delivery:** Resend email service
- **Visibility:** Email client
- **Reliability:** ⚠️ Requires API to be deployed
- **Fallback:** If API unavailable, user still gets in-app notification
- **Control:** Can be disabled per user via `sendEmail` parameter

---

## 🔧 **Implementation Details**

### **Code Location**
- **Service:** `lib/core/services/notification_helper_service.dart`
- **Method:** `_sendNotificationViaAPI()`
- **In-App:** `NotificationService.createNotification()` (always called first)
- **API Endpoint:** `POST /api/notifications/send` (Next.js)

### **Parameters**
```dart
_sendNotificationViaAPI(
  userId: String,           // Required: User to notify
  type: String,             // Required: Notification type
  title: String,            // Required: Notification title
  message: String,          // Required: Notification message
  priority: String,         // Optional: 'low', 'normal', 'high', 'urgent'
  actionUrl: String?,       // Optional: Deep link URL
  actionText: String?,      // Optional: Action button text
  icon: String?,           // Optional: Emoji or icon name
  metadata: Map?,          // Optional: Additional data
  sendEmail: bool,         // Optional: Send email (default: true)
  sendPush: bool,          // Optional: Send push (default: true)
)
```

### **API Request Body**
```json
{
  "userId": "user-uuid",
  "type": "trial_request",
  "title": "🎯 New Trial Session Request",
  "message": "Student wants to book a trial session...",
  "priority": "high",
  "actionUrl": "/trials/123",
  "actionText": "Review Request",
  "icon": "🎯",
  "metadata": { "trial_id": "123", ... },
  "sendEmail": true,
  "sendPush": true
}
```

### **API Response**
- **200 OK:** Push + email sent successfully
- **Error:** Silent fail, in-app notification still created

---

## ✅ **Key Points**

1. **In-app notifications are ALWAYS sent** - This is the foundation
2. **Push notifications are sent via API** - Requires Next.js to be deployed
3. **Email notifications are sent via API** - Can be controlled per notification
4. **Graceful degradation** - If API fails, users still get in-app notifications
5. **No user action required** - All notifications are automatic
6. **Real-time updates** - In-app notifications update in real-time via Supabase Realtime

---

## 🚀 **Next.js API Responsibilities**

When the API receives a notification request, it:

1. **Creates in-app notification** (if not already created by Flutter)
2. **Sends push notification:**
   - Fetches FCM token from Supabase `user_fcm_tokens` table
   - Sends via Firebase Admin SDK
   - Handles platform-specific formatting (Android/iOS/Web)
3. **Sends email notification** (if `sendEmail: true`):
   - Uses Resend API
   - Sends branded HTML email template
   - Includes deep link to app content

---

## 📝 **Summary**

| Notification Type | Always Sent? | Delivery Method | Reliability |
|------------------|--------------|-----------------|-------------|
| **In-App** | ✅ Yes | Supabase (direct) | ✅ 100% |
| **Push** | ⚠️ Via API | Firebase (via Next.js) | ⚠️ Requires API |
| **Email** | ⚠️ Via API | Resend (via Next.js) | ⚠️ Requires API |

**Result:** Users are always notified via in-app notifications, and get push/email when the API is available.





