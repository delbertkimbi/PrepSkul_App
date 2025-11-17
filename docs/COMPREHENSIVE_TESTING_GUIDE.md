# 🧪 Comprehensive Testing Guide - PrepSkul MVP

**Purpose:** Manual testing checklist for critical MVP features  
**Who:** You (the developer) will test on real devices/browsers  
**When:** Before MVP launch

---

## 📋 **TESTING APPROACH**

### **What I Can Do:**
- ✅ Fix bugs you find
- ✅ Write integration tests (if needed)
- ✅ Verify code implementation
- ✅ Create testing checklists

### **What You Need to Do:**
- ✅ Test on real devices (iOS, Android)
- ✅ Test on web browsers
- ✅ Test payment flows with real/sandbox accounts
- ✅ Test Google Calendar OAuth
- ✅ Test push notifications on real devices
- ✅ Verify Meet links work
- ✅ Test Fathom integration

---

## 🔴 **CRITICAL FEATURES TO TEST**

### **1. Push Notifications** 🔴 HIGH PRIORITY

#### **Setup Required:**
- [ ] Firebase project configured
- [ ] iOS: APNS certificate/key uploaded to Firebase
- [ ] Android: FCM server key configured
- [ ] `.env` file has Firebase config

#### **Test Checklist:**
- [ ] **iOS Device:**
  - [ ] Install app on real iOS device (not simulator)
  - [ ] Grant notification permission when prompted
  - [ ] Verify FCM token is stored in database
  - [ ] Send test notification from admin dashboard
  - [ ] Verify notification appears on device
  - [ ] Tap notification → verify app opens to correct screen
  - [ ] Test background notifications (app closed)
  - [ ] Test foreground notifications (app open)

- [ ] **Android Device:**
  - [ ] Install app on real Android device
  - [ ] Grant notification permission
  - [ ] Verify FCM token is stored
  - [ ] Send test notification
  - [ ] Verify notification appears
  - [ ] Test background/foreground notifications

- [ ] **Web:**
  - [ ] Open app in browser
  - [ ] Grant notification permission
  - [ ] Verify notifications work (may require service worker)

#### **Known Issues to Watch For:**
- ⚠️ iOS simulator: APNS token may not be available (expected)
- ⚠️ Web: May require service worker configuration
- ⚠️ Token refresh: Verify token updates when refreshed

#### **Files to Check:**
- `lib/core/services/push_notification_service.dart`
- Firebase Console → Cloud Messaging
- Supabase `fcm_tokens` table

---

### **2. Payments (Fapshi)** 🔴 HIGH PRIORITY

#### **Setup Required:**
- [ ] Fapshi account created
- [ ] Sandbox API credentials in `.env`
- [ ] Production API credentials (when ready)
- [ ] Webhook URL configured in Fapshi dashboard

#### **Test Checklist:**
- [ ] **Trial Session Payment:**
  - [ ] Book a trial session
  - [ ] Enter phone number
  - [ ] Verify payment request sent to Fapshi
  - [ ] Complete payment on mobile device
  - [ ] Verify payment status updates in app
  - [ ] Verify trial session status → `scheduled`
  - [ ] Verify Meet link generated after payment
  - [ ] Check webhook received in Next.js logs

- [ ] **Regular Session Payment:**
  - [ ] Book regular session
  - [ ] Complete payment
  - [ ] Verify payment status updates
  - [ ] Verify session created

- [ ] **Payment History:**
  - [ ] View payment history as student
  - [ ] View payment history as parent
  - [ ] Verify all payments show correctly
  - [ ] Verify no false error messages

- [ ] **Payment Failures:**
  - [ ] Test payment cancellation
  - [ ] Test payment timeout
  - [ ] Verify error handling
  - [ ] Verify retry mechanism

#### **Webhook Testing:**
- [ ] Use Fapshi sandbox to send test webhook
- [ ] Verify webhook received at `/api/webhooks/fapshi`
- [ ] Verify database updated correctly
- [ ] Check Next.js logs for errors

#### **Files to Check:**
- `lib/features/payment/services/fapshi_service.dart`
- `PrepSkul_Web/app/api/webhooks/fapshi/route.ts`
- Fapshi Dashboard → Transactions

---

### **3. Sessions & Booking Tracking** 🔴 HIGH PRIORITY

#### **Test Checklist:**
- [ ] **Trial Session Booking:**
  - [ ] Select tutor
  - [ ] Select subject & duration
  - [ ] Select date & time
  - [ ] Verify blocked time slots shown
  - [ ] Complete booking
  - [ ] Verify trial session created in database
  - [ ] Verify tutor receives notification
  - [ ] Verify payment flow works

- [ ] **Regular Session Booking:**
  - [ ] Book recurring session
  - [ ] Select frequency (1x, 2x, 3x, 4x per week)
  - [ ] Select days & times
  - [ ] Select location
  - [ ] Complete booking
  - [ ] Verify recurring session created
  - [ ] Verify individual sessions generated (8 weeks ahead)
  - [ ] Verify tutor receives notification

- [ ] **Session Lifecycle:**
  - [ ] **Start Session:**
    - [ ] Tutor clicks "Start Session"
    - [ ] Verify status → `in_progress`
    - [ ] Verify `session_started_at` timestamp
    - [ ] Verify student receives notification
    - [ ] Verify Meet link accessible (if online)
  
  - [ ] **End Session:**
    - [ ] Tutor clicks "End Session"
    - [ ] Verify status → `completed`
    - [ ] Verify `session_ended_at` timestamp
    - [ ] Verify duration calculated correctly
    - [ ] Verify earnings calculated (85% of fee)
    - [ ] Verify student receives notification

- [ ] **Session Cancellation:**
  - [ ] Cancel pending session
  - [ ] Cancel approved session (with reason)
  - [ ] Verify notifications sent
  - [ ] Verify refund handling (if applicable)

- [ ] **Session Tracking:**
  - [ ] View "My Sessions" as student
  - [ ] View "My Sessions" as tutor
  - [ ] Verify upcoming sessions show correctly
  - [ ] Verify past sessions show correctly
  - [ ] Verify session status updates correctly

#### **Files to Check:**
- `lib/features/booking/services/trial_session_service.dart`
- `lib/features/booking/services/session_lifecycle_service.dart`
- `lib/features/booking/services/individual_session_service.dart`
- Supabase `trial_sessions`, `recurring_sessions`, `individual_sessions` tables

---

### **4. Google Meet Links & Calendar** 🔴 HIGH PRIORITY

#### **Setup Required:**
- [ ] Google Cloud Project created
- [ ] Google Calendar API enabled
- [ ] OAuth 2.0 credentials configured
- [ ] PrepSkul VA email created (`prepskul-va@prepskul.com` or similar)
- [ ] PrepSkul VA email added to Fathom account
- [ ] `.env` has `PREPSKUL_VA_EMAIL`

#### **Test Checklist:**
- [ ] **Google Calendar OAuth:**
  - [ ] First-time user: Prompt for Google Calendar access
  - [ ] Grant permission
  - [ ] Verify OAuth token stored
  - [ ] Test re-authentication if token expires

- [ ] **Meet Link Generation:**
  - [ ] Book trial session
  - [ ] Complete payment
  - [ ] Verify Meet link generated
  - [ ] Verify Meet link stored in database
  - [ ] Verify calendar event created
  - [ ] Check PrepSkul VA email calendar → verify event exists
  - [ ] Verify Meet link works (can join meeting)

- [ ] **Calendar Event Details:**
  - [ ] Verify event title: "Trial Session: [Subject]"
  - [ ] Verify start/end times correct
  - [ ] Verify attendees: Tutor, Student, PrepSkul VA
  - [ ] Verify timezone: Africa/Douala

- [ ] **Recurring Sessions:**
  - [ ] Book recurring session
  - [ ] Verify Meet link generated
  - [ ] Verify calendar event created
  - [ ] Verify same Meet link used for all sessions

- [ ] **Meet Link Access:**
  - [ ] Verify Meet link only accessible after payment
  - [ ] Test access control (payment gate)
  - [ ] Verify link works for both tutor and student

#### **Known Issues to Watch For:**
- ⚠️ OAuth token expiration (needs refresh)
- ⚠️ Calendar API quota limits
- ⚠️ Meet link generation may fail if API not initialized

#### **Files to Check:**
- `lib/core/services/google_calendar_service.dart`
- `lib/core/services/google_calendar_auth_service.dart`
- `lib/features/sessions/services/meet_service.dart`
- Google Cloud Console → APIs & Services → Credentials

---

### **5. Fathom AI Integration (PrepSkul VA)** 🟡 MEDIUM PRIORITY

#### **Setup Required:**
- [ ] Fathom account created
- [ ] Fathom API key obtained
- [ ] PrepSkul VA email connected to Fathom
- [ ] Fathom webhook configured
- [ ] `.env` has `FATHOM_API_KEY`
- [ ] Webhook URL: `https://app.prepskul.com/api/webhooks/fathom`

#### **Test Checklist:**
- [ ] **Calendar Auto-Join:**
  - [ ] Create calendar event with PrepSkul VA as attendee
  - [ ] Verify Fathom detects event in calendar
  - [ ] Start meeting at scheduled time
  - [ ] Verify Fathom auto-joins meeting
  - [ ] Verify Fathom starts recording

- [ ] **Recording & Transcription:**
  - [ ] Conduct test session (5-10 minutes)
  - [ ] Verify Fathom records session
  - [ ] Verify transcription generated
  - [ ] Verify summary generated

- [ ] **Webhook Processing:**
  - [ ] Wait for Fathom webhook (`new_meeting_content_ready`)
  - [ ] Verify webhook received at `/api/webhooks/fathom`
  - [ ] Verify transcript stored in database
  - [ ] Verify summary stored
  - [ ] Verify notifications sent to tutor/student

- [ ] **Summary Distribution:**
  - [ ] Verify tutor receives summary email
  - [ ] Verify student receives summary email
  - [ ] Verify summary accessible in app
  - [ ] Verify action items extracted

#### **Known Issues to Watch For:**
- ⚠️ Fathom app may be unverified (users see warning)
- ⚠️ Auto-join may take 1-2 minutes after meeting starts
- ⚠️ Transcription may take 5-10 minutes after meeting ends

#### **Files to Check:**
- `lib/features/sessions/services/fathom_service.dart`
- `lib/features/sessions/services/fathom_summary_service.dart`
- `PrepSkul_Web/app/api/webhooks/fathom/route.ts`
- Fathom Dashboard → Meetings

---

## 🟡 **SECONDARY FEATURES TO TEST**

### **6. Custom Tutor Requests**
- [ ] Submit custom request
- [ ] Verify education level auto-selected from survey
- [ ] Verify subjects highlighted
- [ ] Verify validation works
- [ ] Verify WhatsApp notification sent
- [ ] Verify request appears in admin dashboard

### **7. Tutor Booking Requests**
- [ ] Submit booking request as student
- [ ] Submit booking request as parent
- [ ] Verify tutor sees request
- [ ] Verify tutor can approve/reject
- [ ] Verify notifications work

### **8. Survey Submissions**
- [ ] Complete student survey
- [ ] Complete parent survey
- [ ] Complete tutor onboarding
- [ ] Verify confetti shows on completion
- [ ] Verify no duplicate key errors
- [ ] Verify data saved correctly

### **9. Trial Session Cancellation**
- [ ] Cancel pending trial (should delete)
- [ ] Cancel approved trial (should require reason)
- [ ] Verify tutor receives notification
- [ ] Verify cancellation reason stored

---

## 🐛 **COMMON ISSUES & FIXES**

### **Push Notifications Not Working:**
1. Check Firebase configuration
2. Verify FCM token stored in database
3. Check device notification permissions
4. Test on real device (not simulator)
5. Check Firebase Console → Cloud Messaging

### **Payments Not Processing:**
1. Verify Fapshi credentials correct
2. Check webhook URL configured
3. Verify phone number format
4. Check Fapshi dashboard for transaction status
5. Review Next.js webhook logs

### **Meet Links Not Generating:**
1. Verify Google Calendar OAuth completed
2. Check Google Calendar API enabled
3. Verify PrepSkul VA email in attendees
4. Check API quota limits
5. Review error logs

### **Fathom Not Joining:**
1. Verify PrepSkul VA email in calendar event
2. Check Fathom account connected to calendar
3. Verify meeting started at scheduled time
4. Check Fathom dashboard for auto-join status

---

## 📝 **TESTING LOG TEMPLATE**

For each test, document:

```
Test: [Feature Name]
Date: [Date]
Device: [iOS/Android/Web]
Result: [Pass/Fail]
Issues Found: [Description]
Screenshots: [If applicable]
```

---

## ✅ **SIGN-OFF CHECKLIST**

Before MVP launch, verify:

- [ ] All push notifications work on iOS
- [ ] All push notifications work on Android
- [ ] All payment flows work (trial & regular)
- [ ] All webhooks process correctly
- [ ] All Meet links generate correctly
- [ ] All calendar events create correctly
- [ ] Fathom auto-joins meetings
- [ ] Fathom records and transcribes
- [ ] Session lifecycle works (start/end/cancel)
- [ ] Session tracking accurate
- [ ] No critical bugs found
- [ ] Performance acceptable
- [ ] Error handling robust

---

## 🚀 **NEXT STEPS AFTER TESTING**

1. **Document all bugs found**
2. **Prioritize fixes** (Critical → High → Medium → Low)
3. **Fix bugs** (I can help with this)
4. **Re-test fixed features**
5. **Sign off for MVP launch**

---

## 📞 **SUPPORT**

If you find bugs or issues:
1. Document the issue clearly
2. Include steps to reproduce
3. Include error messages/logs
4. Include device/browser info
5. Share with me for fixing

**I'll fix the bugs, you test the fixes!** 🎯
