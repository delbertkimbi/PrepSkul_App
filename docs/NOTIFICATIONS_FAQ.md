# 🔔 Notifications FAQ

**Quick answers to common questions**

---

## ❓ **Q1: Are notifications only from admin panel?**

### **NO - Most notifications are AUTOMATIC!** ✅

**Automatic notifications (90% of notifications):**
- ✅ Booking requests → Automatically sent
- ✅ Payments → Automatically sent
- ✅ Session reminders → Automatically sent
- ✅ Profile approvals → Automatically sent

**Manual notifications (10% - admin panel only):**
- ✅ Announcements
- ✅ Custom messages
- ✅ System updates

---

## ❓ **Q2: Are they not automatic?**

### **YES - They ARE automatic!** ✅

**When events happen in the app, notifications are sent automatically:**

1. **Student creates booking** → Tutor automatically notified
2. **Tutor accepts booking** → Student automatically notified
3. **Payment received** → Tutor automatically notified
4. **Session reminder** → Both parties automatically notified

**No admin action needed!** It's all automatic. 🎉

---

## ❓ **Q3: How to test push notifications?**

### **Step-by-Step Testing:**

1. **Check FCM Token:**
   ```sql
   SELECT * FROM fcm_tokens 
   WHERE user_id = 'your-user-id' 
   AND is_active = true;
   ```

2. **Send via Admin Panel:**
   - Go to: `https://www.prepskul.com/admin/notifications/send`
   - Enter user ID, title, message
   - ✅ Check "Send push notification"
   - Click "Send"

3. **Check Result:**
   - Toast shows: `Push: ✅ (1 device)` or `Push: ❌`
   - If ✅: Notification should appear on device
   - If ❌: Check FCM token exists

4. **Verify on Device:**
   - Notification appears in system tray
   - Sound/vibration works
   - Tap opens app

---

## 📊 **Notification Types**

| Type | Trigger | Examples |
|------|---------|----------|
| **Automatic** | Events in app | Booking, payment, session |
| **Manual** | Admin action | Announcements, updates |

---

## ✅ **Summary**

- ✅ **Most notifications are automatic** (booking, payment, session events)
- ✅ **Admin panel is for manual/custom** notifications
- ✅ **Both use same system** (in-app, email, push)
- ✅ **Test push via admin panel** to verify it works

---

**See `NOTIFICATION_SYSTEM_EXPLAINED.md` for full details!** 📚


