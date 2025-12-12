# ⚡ Quick Notification Answers

---

## ❓ **Q: Are notifications only from admin panel?**

### **NO!** Most notifications are **AUTOMATIC** ✅

**Automatic (90%):**
- ✅ Booking requests → Auto-sent
- ✅ Payments → Auto-sent
- ✅ Session reminders → Auto-sent
- ✅ Profile approvals → Auto-sent

**Manual (10% - Admin Panel):**
- ✅ Announcements
- ✅ Custom messages

---

## ❓ **Q: Are they not automatic?**

### **YES - They ARE automatic!** ✅

When events happen (booking, payment, etc.), notifications are **automatically sent**. No admin action needed!

---

## ❓ **Q: How to test push notifications?**

### **3 Steps:**

1. **Check FCM Token:**
   ```sql
   SELECT * FROM fcm_tokens WHERE user_id = 'your-id';
   ```

2. **Send via Admin Panel:**
   - Go to: `/admin/notifications/send`
   - Fill form, check "Send push notification"
   - Click "Send"

3. **Check Result:**
   - Toast shows: `Push: ✅ (1 device)` or `Push: ❌`
   - If ✅: Check device for notification
   - If ❌: Check FCM token exists

---

**See `NOTIFICATIONS_COMPLETE_GUIDE.md` for full details!** 📚


