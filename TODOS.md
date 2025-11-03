# 📋 PrepSkul Development TODOs

**Last Updated:** January 2025

---

## ✅ **COMPLETED**

### Tutor Onboarding
- ✅ Availability validation - Must select 1 trial + 1 weekly slot
- ✅ Removed visual "required" indicators (asterisks & text)
- ✅ All fields validated - toggles default to false = "no"
- ✅ Media links & video separated into dedicated page
- ✅ Added "Last Official Certificate" document tab
- ✅ Document upload blocker - Cannot proceed without all docs
- ✅ Fixed web uploads (XFile → Uint8List for web)
- ✅ Added specializations tabbed UI for better organization

### Auth & Navigation
- ✅ Email and phone authentication
- ✅ Email confirmation flow with deep links
- ✅ Forgot password functionality
- ✅ Bottom navigation by role
- ✅ Profile screens

### Discovery & Booking
- ✅ Tutor discovery with filters
- ✅ Booking flow (trial & regular)
- ✅ Request management for tutors
- ✅ WhatsApp integration

### Admin
- ✅ Admin dashboard (Next.js)
- ✅ Tutor approval/rejection workflow
- ✅ Real-time metrics

---

## 🚧 **IN PROGRESS**

- **Specialization tabs** - Implemented, needs testing
- **Web uploads** - Fixed, needs testing on fresh browser

---

## 📅 **PENDING**

### **WEEK 1: Admin & Verification**

#### 🔴 Priority: Critical
- [ ] Email/SMS notifications for tutor approval/rejection
  - Setup SendGrid/Resend for emails
  - Setup Twilio for SMS
  - Email templates (approved/rejected)
  - SMS templates

- [ ] Update tutor dashboard to show approval status
  - "Approved" badge/status
  - Enable tutor features after approval
  - Show rejection reason if rejected
  - Hide "Pending" banner on approval

---

### **WEEK 2: Discovery & Matching**

#### 🔴 Priority: Critical  
- [ ] Ticket #4 (Tutor Discovery) - Verify integration
  - Test search functionality
  - Test filters (subject, price, rating, location)
  - Test tutor profile pages
  - Test booking buttons

---

### **WEEK 3: Booking & Sessions**

#### 🔴 Priority: Critical
- [ ] Session request flow for students/parents
  - Select tutor availability
  - Session details form
  - Send request to tutor
  - Database integration

- [ ] Tutor request management (accept/reject)
  - View incoming requests
  - Accept/reject with notes
  - Alternative time proposals
  - Notification system

- [ ] Confirmed sessions tracking
  - Session calendar view
  - Countdown timers
  - Session status updates
  - Join session buttons (placeholder)

---

### **WEEK 4: Payments**

#### 🔴 Priority: Critical
- [ ] Fapshi Payment Integration
  - Mobile Money payments (MTN/Orange)
  - Escrow system
  - Transaction tracking
  - Payment confirmation flow

- [ ] Credit System
  - Buy credits functionality
  - Deduct credits for sessions
  - View credit balance
  - Purchase history
  - Refund logic

---

### **WEEK 5: Session Management**

#### 🔴 Priority: Critical
- [ ] Session Tracking
  - Start/end times
  - Attendance confirmation
  - No-show handling
  - Auto-complete after duration

- [ ] Post-Session Feedback
  - Rating system (1-5 stars)
  - Written reviews
  - Tags/attributes
  - Display on profiles

- [ ] Messaging System
  - In-app chat
  - Read receipts
  - Message history
  - Notification badges

---

### **WEEK 6: Polish & Launch**

#### 🔴 Priority: Critical
- [ ] Push Notifications
  - Firebase Cloud Messaging setup
  - Session request notifications
  - Approval notifications
  - Session reminders

- [ ] Tutor Earnings & Payouts
  - View earnings by session
  - Request payout
  - Payout via Fapshi
  - Transaction history

- [ ] End-to-end Testing
  - Complete user flows
  - Bug fixes
  - Performance optimization
  - Security audit

- [ ] Analytics & Monitoring
  - Firebase Analytics
  - Crashlytics
  - Performance monitoring
  - User behavior tracking

---

## 🎯 **NEXT IMMEDIATE ACTIONS**

Based on current progress:

1. **Test web uploads** - Verify fix works in fresh browser session
2. **Test specialization tabs** - Hot reload and verify UI
3. **Choose next priority**:
   - Week 1 tasks (Admin notifications)
   - Week 2 verification (Discovery integration)
   - Or custom feature you want

---

**Last Updated:** January 2025  
**Current Phase:** Week 1-2 features


