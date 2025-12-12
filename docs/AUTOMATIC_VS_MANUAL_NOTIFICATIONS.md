# 🔔 Automatic vs Manual Notifications

**Date:** January 2025

---

## ✅ **AUTOMATIC Notifications (Most Common)**

**These happen automatically when events occur - NO admin action needed!**

### **When They're Sent:**
- ✅ Booking request created → Tutor notified
- ✅ Booking accepted → Student notified
- ✅ Payment received → Tutor notified
- ✅ Session reminder → Both parties notified
- ✅ Profile approved → Tutor notified
- ✅ And many more...

### **How It Works:**
1. Event occurs in app (e.g., booking created)
2. Code automatically calls `NotificationHelperService`
3. Notification sent via API (in-app, email, push)
4. User receives notification

**Example:**
```dart
// When tutor approves booking
await NotificationHelperService.notifyBookingRequestAccepted(
  studentId: studentId,
  tutorId: tutorId,
  requestId: requestId,
  tutorName: tutorName,
  subject: subject,
);
// ↑ This is called AUTOMATICALLY - no manual action needed!
```

---

## 👤 **MANUAL Notifications (Admin Panel)**

**These are sent manually by admins for special messages.**

### **When to Use:**
- 📢 Announcements
- 📢 System updates
- 📢 Custom messages to users
- 📢 Important notifications

### **How to Send:**
1. Go to: `https://www.prepskul.com/admin/notifications/send`
2. Fill form:
   - User ID
   - Title
   - Message
   - Priority
3. Choose channels (in-app, email, push)
4. Click "Send"

---

## 📊 **Comparison**

| Feature | Automatic | Manual (Admin) |
|---------|-----------|---------------|
| **Trigger** | Events in app | Admin action |
| **Frequency** | Very common | Occasional |
| **Examples** | Booking, payment, session | Announcements, updates |
| **Channels** | All 3 (in-app, email, push) | All 3 (in-app, email, push) |
| **User Control** | Respects preferences | Respects preferences |

---

## 🎯 **Summary**

### **Most notifications are AUTOMATIC:**
- ✅ Booking events
- ✅ Payment events
- ✅ Session events
- ✅ Profile events

### **Some notifications are MANUAL:**
- ✅ Admin announcements
- ✅ Custom messages
- ✅ System updates

---

## ✅ **Both Use Same System**

Whether automatic or manual, all notifications:
- ✅ Use same API: `/api/notifications/send`
- ✅ Support all 3 channels (in-app, email, push)
- ✅ Respect user preferences
- ✅ Include deep links
- ✅ Show in notification bell

---

**Most are automatic! Admin panel is just for special cases.** 🚀


