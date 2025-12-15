# 🧪 Next Testing Priorities

**Date:** January 2025

---

## 🎯 **IMMEDIATE TESTING TASKS (Start Here)**

### **Priority 1: Recently Implemented Features** ⏳

#### **1. Test "Add to Calendar" Button** ⏳ **HIGH PRIORITY**
**Status:** ✅ Implemented | ⏳ Testing needed

**What to Test:**
- [ ] Create a session (without calendar event)
- [ ] Go to "My Sessions" screen
- [ ] Verify "Add to Calendar" button appears on session card
- [ ] Click button (first time) → Should show "Connect Google Calendar" dialog
- [ ] Connect Google Calendar → Should authenticate
- [ ] Add another session → Should NOT ask to connect again (button should say "Add to Calendar")
- [ ] Verify button text changes: "Connect & Add" → "Add to Calendar"
- [ ] Verify button icon changes: `calendar_today_outlined` → `calendar_today`
- [ ] After adding to calendar, button should disappear (session has `calendar_event_id`)

**Files:**
- `lib/features/booking/screens/my_sessions_screen.dart`

---

#### **2. Test Session Reminder Notifications** ⏳ **HIGH PRIORITY**
**Status:** ✅ Implemented | ⏳ Testing needed

**What to Test:**
- [ ] Create a session scheduled for tomorrow
- [ ] Verify reminders are scheduled (24h, 1h, 15min before)
- [ ] Check `scheduled_notifications` table in Supabase
- [ ] Wait for reminder times (or manually trigger)
- [ ] Verify both tutor and student receive reminders
- [ ] Check notification messages are personalized
- [ ] Verify reminders include correct metadata (session_id, action_url, etc.)

**Files:**
- `lib/core/services/notification_helper_service.dart`
- `PrepSkul_Web/app/api/notifications/schedule-session-reminders/route.ts`

---

#### **3. Test Push Notifications** ⏳ **HIGH PRIORITY**
**Status:** ✅ Backend ready | ⏳ Testing needed

**What to Test:**
- [ ] Check FCM token is stored in database:
  ```sql
  SELECT * FROM fcm_tokens WHERE user_id = 'your-id' AND is_active = true;
  ```
- [ ] Send test notification via admin panel:
  - Go to: `https://www.prepskul.com/admin/notifications/send`
  - Enter user ID, title, message
  - Check "Send push notification"
  - Click "Send"
- [ ] Verify toast shows: `Push: ✅ (1 device)` or `Push: ❌`
- [ ] If ✅: Check device for notification
- [ ] If ❌: Check FCM token exists, Next.js API deployed, Firebase configured
- [ ] Test automatic push notifications (booking, payment, session events)

**Files:**
- `PrepSkul_Web/lib/services/firebase-admin.ts`
- `PrepSkul_Web/app/api/notifications/send/route.ts`

---

#### **4. Test Notification Role Filtering** ⏳ **HIGH PRIORITY**
**Status:** ✅ Fixed | ⏳ Testing needed

**What to Test:**
- [ ] **As Student:**
  - Login as student account
  - Open notification list
  - Verify "Complete Your Profile to Get Verified" notification is NOT visible
  - Verify no tutor-specific notifications appear
  - Check unread count excludes tutor notifications
- [ ] **As Tutor:**
  - Login as tutor account
  - Open notification list
  - Verify tutor-specific notifications ARE visible
  - Verify "Complete Your Profile to Get Verified" appears (if profile not approved)
- [ ] **Real-time Updates:**
  - Open notification list
  - Have another user trigger a notification
  - Verify only role-appropriate notifications appear

**Files:**
- `lib/core/services/notification_service.dart`
- `lib/core/services/notification_helper_service.dart`

---

### **Priority 2: Core Features** ⏳

#### **5. Test Deep Linking from Notifications** ⏳
**Status:** ✅ Service created | ⏳ Testing needed

**What to Test:**
- [ ] Receive notification (booking, payment, session, etc.)
- [ ] Tap notification
- [ ] Verify app opens (if closed)
- [ ] Verify navigates to correct screen:
  - Booking notification → Booking details screen
  - Payment notification → Payment screen
  - Session notification → Session details screen
  - Profile notification → Profile screen
- [ ] Test with app in foreground, background, and terminated states

**Files:**
- `lib/core/services/notification_navigation_service.dart`

---

#### **6. Test Tutor Dashboard Status** ⏳
**Status:** ✅ Implemented | ⏳ Testing needed

**What to Test:**
- [ ] Login as tutor with pending profile
- [ ] Verify dashboard shows "Pending Approval" status
- [ ] Admin approves profile
- [ ] Verify dashboard updates to "Approved" status
- [ ] Admin rejects profile with notes
- [ ] Verify dashboard shows rejection notes
- [ ] Verify "Dismiss" button works for approval banner

**Files:**
- `lib/features/tutor/screens/tutor_home_screen.dart`

---

#### **7. Test Environment Switch** ⏳
**Status:** ✅ Implemented | ⏳ Testing needed

**What to Test:**
- [ ] Change `AppConfig.isProduction` to `true`
- [ ] Verify all services use production URLs:
  - Fapshi uses production API
  - Supabase uses production instance
  - APIs use production endpoints
- [ ] Change back to `false`
- [ ] Verify all services use sandbox/development URLs
- [ ] Test payment flow in both environments

**Files:**
- `lib/core/config/app_config.dart`

---

### **Priority 3: Integration Testing** ⏳

#### **8. Test Complete Booking Flow** ⏳
**What to Test:**
- [ ] Student creates booking request
- [ ] Tutor receives notification (in-app, email, push)
- [ ] Tutor approves booking
- [ ] Student receives notification
- [ ] Payment request created automatically
- [ ] Student pays
- [ ] Sessions created automatically
- [ ] Both parties receive session reminders

---

#### **9. Test Session Lifecycle** ⏳
**What to Test:**
- [ ] Session created (without calendar)
- [ ] Session appears in "Upcoming Sessions"
- [ ] User adds session to calendar
- [ ] Session reminders sent (24h, 1h, 15min)
- [ ] Session starts (tutor clicks "Start Session")
- [ ] Session ends (tutor clicks "End Session")
- [ ] Feedback reminder sent to student
- [ ] Student submits feedback
- [ ] Tutor rating updates

---

#### **10. Test Tutor Payout Flow** ⏳
**What to Test:**
- [ ] Tutor has earnings (from completed sessions)
- [ ] Tutor requests payout (via service - UI pending)
- [ ] Verify payout request created in database
- [ ] Verify earnings marked as `paid_out`
- [ ] Admin processes payout (via service - UI pending)
- [ ] Verify payout status updates
- [ ] Verify tutor receives notification

**Files:**
- `lib/features/payment/services/tutor_payout_service.dart`

---

## 📋 **TESTING CHECKLIST SUMMARY**

### **High Priority (Do First):**
1. ⏳ Test "Add to Calendar" button
2. ⏳ Test session reminder notifications
3. ⏳ Test push notifications
4. ⏳ Test notification role filtering

### **Medium Priority:**
5. ⏳ Test deep linking from notifications
6. ⏳ Test tutor dashboard status
7. ⏳ Test environment switch

### **Integration Testing:**
8. ⏳ Test complete booking flow
9. ⏳ Test session lifecycle
10. ⏳ Test tutor payout flow

---

## 🚀 **How to Start Testing**

### **Step 1: Run Automated Tests**
```bash
cd /Users/user/Desktop/PrepSkul/prepskul_app
flutter test
```
**Expected:** All 68 tests pass ✅

### **Step 2: Manual Testing**
1. Start with Priority 1 tasks (Add to Calendar, Reminders, Push, Role Filtering)
2. Test each feature end-to-end
3. Document any issues found
4. Move to Priority 2 and 3

### **Step 3: Integration Testing**
1. Test complete user flows
2. Test cross-feature interactions
3. Test edge cases
4. Test error handling

---

## 📝 **Testing Notes**

### **Test Environment:**
- Use sandbox environment (`AppConfig.isProduction = false`)
- Test with real user accounts (student, tutor, admin)
- Test on multiple devices (iOS, Android, Web)

### **Test Data:**
- Create test bookings
- Create test sessions
- Create test payments
- Use test FCM tokens

### **Documentation:**
- Document test results
- Note any bugs found
- Track test coverage
- Update test checklist

---

## ✅ **Success Criteria**

All tests pass when:
- ✅ All automated tests pass (68/68)
- ✅ All Priority 1 features work correctly
- ✅ No critical bugs found
- ✅ All notifications delivered correctly
- ✅ All navigation works correctly
- ✅ All integrations work correctly

---

**Start with Priority 1 tasks - they're the most recently implemented!** 🚀

