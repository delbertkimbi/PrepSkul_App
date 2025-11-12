# 🎓 Tutor Flow - Remaining Tasks

**Last Updated:** January 2025

## ✅ **What's Complete**

### 1. **Tutor Onboarding** ✅
- ✅ Multi-step onboarding form (11 steps)
- ✅ Profile data collection (academic, experience, availability, pricing)
- ✅ Document uploads (ID, certificates)
- ✅ Video introduction
- ✅ Profile submission and status tracking

### 2. **Profile Management** ✅
- ✅ Edit profile (name, phone, email, photo)
- ✅ View profile with neumorphic design
- ✅ Admin feedback system (improvement, rejection, block, hide)
- ✅ Unblock/unhide request system
- ✅ Profile picture loading and display

### 3. **Home Screen** ✅
- ✅ Welcome message with first name
- ✅ Approval status cards (pending, approved, rejected, needs improvement)
- ✅ PrepSkul Wallet placeholder (shows after approval card dismissed)
- ✅ Quick stats (Students, Sessions - placeholder)
- ✅ Notification bell

### 4. **Navigation** ✅
- ✅ Bottom navigation (Home, Requests, Students, Profile)
- ✅ All screens accessible

### 5. **Admin Integration** ✅
- ✅ Admin can view tutor profiles
- ✅ Admin can approve/reject/request improvements
- ✅ Email notifications to tutors
- ✅ In-app notifications

---

## ⏳ **What's Missing (Tutor-Specific)**

### 1. **Tutor Requests Screen** ⏳
**Current Status:** Empty placeholder screen

**What's Needed:**
- [ ] Fetch booking requests from `booking_requests` table
- [ ] Display incoming requests with:
  - Student name and info
  - Subject and education level
  - Requested schedule (days, times)
  - Location preference
  - Session frequency
  - Payment plan
- [ ] Approve/Reject buttons
- [ ] Request details view
- [ ] Filter by status (pending, approved, rejected)
- [ ] Real-time updates when new requests arrive

**Priority:** HIGH (Core feature)

---

### 2. **Tutor Students Screen** ⏳
**Current Status:** Empty placeholder screen

**What's Needed:**
- [ ] Fetch active students from `bookings` table (where status = 'active')
- [ ] Display student list with:
  - Student name and photo
  - Subject(s) being taught
  - Session schedule
  - Next session date/time
  - Total sessions completed
- [ ] Student detail view:
  - Full profile
  - Session history
  - Payment status
  - Notes/feedback
- [ ] Search/filter functionality

**Priority:** HIGH (Core feature)

---

### 3. **Sessions Screen** ⏳
**Current Status:** Not implemented (no screen exists)

**What's Needed:**
- [ ] Create `tutor_sessions_screen.dart`
- [ ] Fetch upcoming sessions from `bookings` table
- [ ] Display calendar/list view:
  - Upcoming sessions (next 7 days)
  - Past sessions
  - Session details (student, subject, time, location)
- [ ] Session actions:
  - Start session (mark as started)
  - End session (mark as completed)
  - Reschedule request
  - Cancel session
- [ ] Session reminders (24h, 1h before)
- [ ] Google Meet link generation (for online sessions)

**Priority:** HIGH (Core feature)

---

### 4. **Wallet/Earnings System** ⏳
**Current Status:** Placeholder card on home screen

**What's Needed:**
- [ ] Database tables:
  - `tutor_earnings` (track per-session earnings)
  - `tutor_wallet` (active balance, pending balance)
  - `payout_requests` (withdrawal requests)
- [ ] Earnings calculation:
  - 15% platform fee deduction
  - Active balance (available for withdrawal)
  - Pending balance (awaiting session completion)
- [ ] Wallet screen:
  - Current balances
  - Transaction history
  - Payout request functionality
- [ ] Integration with payment system (Fapshi)
- [ ] Admin payout processing

**Priority:** MEDIUM (Can be done after sessions work)

---

### 5. **Reviews & Ratings** ⏳
**Current Status:** Not implemented

**What's Needed:**
- [ ] Display reviews on tutor profile
- [ ] Review detail view
- [ ] Average rating calculation
- [ ] Response to reviews functionality
- [ ] Review analytics (rating trends)

**Priority:** MEDIUM (Can be done after sessions work)

---

## 🔄 **Integration Points Needed**

### 1. **Booking System Integration**
- [ ] Connect `TutorRequestsScreen` to `booking_requests` table
- [ ] Implement approve/reject logic
- [ ] Create recurring sessions upon approval
- [ ] Send notifications to students

### 2. **Session Management Integration**
- [ ] Connect sessions to `bookings` table
- [ ] Implement start/end session tracking
- [ ] Google Meet link generation
- [ ] Fathom AI integration for session monitoring

### 3. **Payment Integration**
- [ ] Track payments per session
- [ ] Calculate tutor earnings (85% of session fee)
- [ ] Update wallet balances
- [ ] Handle pending → active balance transitions

---

## 📋 **Quick Wins (Can Do Now)**

1. **Implement Tutor Requests Screen** (2-3 hours)
   - Fetch and display booking requests
   - Add approve/reject functionality
   - Connect to existing booking service

2. **Implement Tutor Students Screen** (2-3 hours)
   - Fetch active students
   - Display student list
   - Add basic student detail view

3. **Create Sessions Screen** (3-4 hours)
   - Basic upcoming sessions list
   - Session detail view
   - Start/end session buttons

---

## 🎯 **Recommended Order**

1. **Tutor Requests Screen** → Core functionality for tutors to accept bookings
2. **Sessions Screen** → Manage and track sessions
3. **Tutor Students Screen** → View active students
4. **Wallet System** → Earnings and payouts
5. **Reviews & Ratings** → Feedback system

---

## 📝 **Notes**

- All screens have navigation set up
- Database schema supports all features
- Booking system is already implemented (student side)
- Need to connect tutor-facing screens to existing data
- Most work is UI + data fetching, not new backend logic





**Last Updated:** January 2025

## ✅ **What's Complete**

### 1. **Tutor Onboarding** ✅
- ✅ Multi-step onboarding form (11 steps)
- ✅ Profile data collection (academic, experience, availability, pricing)
- ✅ Document uploads (ID, certificates)
- ✅ Video introduction
- ✅ Profile submission and status tracking

### 2. **Profile Management** ✅
- ✅ Edit profile (name, phone, email, photo)
- ✅ View profile with neumorphic design
- ✅ Admin feedback system (improvement, rejection, block, hide)
- ✅ Unblock/unhide request system
- ✅ Profile picture loading and display

### 3. **Home Screen** ✅
- ✅ Welcome message with first name
- ✅ Approval status cards (pending, approved, rejected, needs improvement)
- ✅ PrepSkul Wallet placeholder (shows after approval card dismissed)
- ✅ Quick stats (Students, Sessions - placeholder)
- ✅ Notification bell

### 4. **Navigation** ✅
- ✅ Bottom navigation (Home, Requests, Students, Profile)
- ✅ All screens accessible

### 5. **Admin Integration** ✅
- ✅ Admin can view tutor profiles
- ✅ Admin can approve/reject/request improvements
- ✅ Email notifications to tutors
- ✅ In-app notifications

---

## ⏳ **What's Missing (Tutor-Specific)**

### 1. **Tutor Requests Screen** ⏳
**Current Status:** Empty placeholder screen

**What's Needed:**
- [ ] Fetch booking requests from `booking_requests` table
- [ ] Display incoming requests with:
  - Student name and info
  - Subject and education level
  - Requested schedule (days, times)
  - Location preference
  - Session frequency
  - Payment plan
- [ ] Approve/Reject buttons
- [ ] Request details view
- [ ] Filter by status (pending, approved, rejected)
- [ ] Real-time updates when new requests arrive

**Priority:** HIGH (Core feature)

---

### 2. **Tutor Students Screen** ⏳
**Current Status:** Empty placeholder screen

**What's Needed:**
- [ ] Fetch active students from `bookings` table (where status = 'active')
- [ ] Display student list with:
  - Student name and photo
  - Subject(s) being taught
  - Session schedule
  - Next session date/time
  - Total sessions completed
- [ ] Student detail view:
  - Full profile
  - Session history
  - Payment status
  - Notes/feedback
- [ ] Search/filter functionality

**Priority:** HIGH (Core feature)

---

### 3. **Sessions Screen** ⏳
**Current Status:** Not implemented (no screen exists)

**What's Needed:**
- [ ] Create `tutor_sessions_screen.dart`
- [ ] Fetch upcoming sessions from `bookings` table
- [ ] Display calendar/list view:
  - Upcoming sessions (next 7 days)
  - Past sessions
  - Session details (student, subject, time, location)
- [ ] Session actions:
  - Start session (mark as started)
  - End session (mark as completed)
  - Reschedule request
  - Cancel session
- [ ] Session reminders (24h, 1h before)
- [ ] Google Meet link generation (for online sessions)

**Priority:** HIGH (Core feature)

---

### 4. **Wallet/Earnings System** ⏳
**Current Status:** Placeholder card on home screen

**What's Needed:**
- [ ] Database tables:
  - `tutor_earnings` (track per-session earnings)
  - `tutor_wallet` (active balance, pending balance)
  - `payout_requests` (withdrawal requests)
- [ ] Earnings calculation:
  - 15% platform fee deduction
  - Active balance (available for withdrawal)
  - Pending balance (awaiting session completion)
- [ ] Wallet screen:
  - Current balances
  - Transaction history
  - Payout request functionality
- [ ] Integration with payment system (Fapshi)
- [ ] Admin payout processing

**Priority:** MEDIUM (Can be done after sessions work)

---

### 5. **Reviews & Ratings** ⏳
**Current Status:** Not implemented

**What's Needed:**
- [ ] Display reviews on tutor profile
- [ ] Review detail view
- [ ] Average rating calculation
- [ ] Response to reviews functionality
- [ ] Review analytics (rating trends)

**Priority:** MEDIUM (Can be done after sessions work)

---

## 🔄 **Integration Points Needed**

### 1. **Booking System Integration**
- [ ] Connect `TutorRequestsScreen` to `booking_requests` table
- [ ] Implement approve/reject logic
- [ ] Create recurring sessions upon approval
- [ ] Send notifications to students

### 2. **Session Management Integration**
- [ ] Connect sessions to `bookings` table
- [ ] Implement start/end session tracking
- [ ] Google Meet link generation
- [ ] Fathom AI integration for session monitoring

### 3. **Payment Integration**
- [ ] Track payments per session
- [ ] Calculate tutor earnings (85% of session fee)
- [ ] Update wallet balances
- [ ] Handle pending → active balance transitions

---

## 📋 **Quick Wins (Can Do Now)**

1. **Implement Tutor Requests Screen** (2-3 hours)
   - Fetch and display booking requests
   - Add approve/reject functionality
   - Connect to existing booking service

2. **Implement Tutor Students Screen** (2-3 hours)
   - Fetch active students
   - Display student list
   - Add basic student detail view

3. **Create Sessions Screen** (3-4 hours)
   - Basic upcoming sessions list
   - Session detail view
   - Start/end session buttons

---

## 🎯 **Recommended Order**

1. **Tutor Requests Screen** → Core functionality for tutors to accept bookings
2. **Sessions Screen** → Manage and track sessions
3. **Tutor Students Screen** → View active students
4. **Wallet System** → Earnings and payouts
5. **Reviews & Ratings** → Feedback system

---

## 📝 **Notes**

- All screens have navigation set up
- Database schema supports all features
- Booking system is already implemented (student side)
- Need to connect tutor-facing screens to existing data
- Most work is UI + data fetching, not new backend logic



# 🎓 Tutor Flow - Remaining Tasks

**Last Updated:** January 2025

## ✅ **What's Complete**

### 1. **Tutor Onboarding** ✅
- ✅ Multi-step onboarding form (11 steps)
- ✅ Profile data collection (academic, experience, availability, pricing)
- ✅ Document uploads (ID, certificates)
- ✅ Video introduction
- ✅ Profile submission and status tracking

### 2. **Profile Management** ✅
- ✅ Edit profile (name, phone, email, photo)
- ✅ View profile with neumorphic design
- ✅ Admin feedback system (improvement, rejection, block, hide)
- ✅ Unblock/unhide request system
- ✅ Profile picture loading and display

### 3. **Home Screen** ✅
- ✅ Welcome message with first name
- ✅ Approval status cards (pending, approved, rejected, needs improvement)
- ✅ PrepSkul Wallet placeholder (shows after approval card dismissed)
- ✅ Quick stats (Students, Sessions - placeholder)
- ✅ Notification bell

### 4. **Navigation** ✅
- ✅ Bottom navigation (Home, Requests, Students, Profile)
- ✅ All screens accessible

### 5. **Admin Integration** ✅
- ✅ Admin can view tutor profiles
- ✅ Admin can approve/reject/request improvements
- ✅ Email notifications to tutors
- ✅ In-app notifications

---

## ⏳ **What's Missing (Tutor-Specific)**

### 1. **Tutor Requests Screen** ⏳
**Current Status:** Empty placeholder screen

**What's Needed:**
- [ ] Fetch booking requests from `booking_requests` table
- [ ] Display incoming requests with:
  - Student name and info
  - Subject and education level
  - Requested schedule (days, times)
  - Location preference
  - Session frequency
  - Payment plan
- [ ] Approve/Reject buttons
- [ ] Request details view
- [ ] Filter by status (pending, approved, rejected)
- [ ] Real-time updates when new requests arrive

**Priority:** HIGH (Core feature)

---

### 2. **Tutor Students Screen** ⏳
**Current Status:** Empty placeholder screen

**What's Needed:**
- [ ] Fetch active students from `bookings` table (where status = 'active')
- [ ] Display student list with:
  - Student name and photo
  - Subject(s) being taught
  - Session schedule
  - Next session date/time
  - Total sessions completed
- [ ] Student detail view:
  - Full profile
  - Session history
  - Payment status
  - Notes/feedback
- [ ] Search/filter functionality

**Priority:** HIGH (Core feature)

---

### 3. **Sessions Screen** ⏳
**Current Status:** Not implemented (no screen exists)

**What's Needed:**
- [ ] Create `tutor_sessions_screen.dart`
- [ ] Fetch upcoming sessions from `bookings` table
- [ ] Display calendar/list view:
  - Upcoming sessions (next 7 days)
  - Past sessions
  - Session details (student, subject, time, location)
- [ ] Session actions:
  - Start session (mark as started)
  - End session (mark as completed)
  - Reschedule request
  - Cancel session
- [ ] Session reminders (24h, 1h before)
- [ ] Google Meet link generation (for online sessions)

**Priority:** HIGH (Core feature)

---

### 4. **Wallet/Earnings System** ⏳
**Current Status:** Placeholder card on home screen

**What's Needed:**
- [ ] Database tables:
  - `tutor_earnings` (track per-session earnings)
  - `tutor_wallet` (active balance, pending balance)
  - `payout_requests` (withdrawal requests)
- [ ] Earnings calculation:
  - 15% platform fee deduction
  - Active balance (available for withdrawal)
  - Pending balance (awaiting session completion)
- [ ] Wallet screen:
  - Current balances
  - Transaction history
  - Payout request functionality
- [ ] Integration with payment system (Fapshi)
- [ ] Admin payout processing

**Priority:** MEDIUM (Can be done after sessions work)

---

### 5. **Reviews & Ratings** ⏳
**Current Status:** Not implemented

**What's Needed:**
- [ ] Display reviews on tutor profile
- [ ] Review detail view
- [ ] Average rating calculation
- [ ] Response to reviews functionality
- [ ] Review analytics (rating trends)

**Priority:** MEDIUM (Can be done after sessions work)

---

## 🔄 **Integration Points Needed**

### 1. **Booking System Integration**
- [ ] Connect `TutorRequestsScreen` to `booking_requests` table
- [ ] Implement approve/reject logic
- [ ] Create recurring sessions upon approval
- [ ] Send notifications to students

### 2. **Session Management Integration**
- [ ] Connect sessions to `bookings` table
- [ ] Implement start/end session tracking
- [ ] Google Meet link generation
- [ ] Fathom AI integration for session monitoring

### 3. **Payment Integration**
- [ ] Track payments per session
- [ ] Calculate tutor earnings (85% of session fee)
- [ ] Update wallet balances
- [ ] Handle pending → active balance transitions

---

## 📋 **Quick Wins (Can Do Now)**

1. **Implement Tutor Requests Screen** (2-3 hours)
   - Fetch and display booking requests
   - Add approve/reject functionality
   - Connect to existing booking service

2. **Implement Tutor Students Screen** (2-3 hours)
   - Fetch active students
   - Display student list
   - Add basic student detail view

3. **Create Sessions Screen** (3-4 hours)
   - Basic upcoming sessions list
   - Session detail view
   - Start/end session buttons

---

## 🎯 **Recommended Order**

1. **Tutor Requests Screen** → Core functionality for tutors to accept bookings
2. **Sessions Screen** → Manage and track sessions
3. **Tutor Students Screen** → View active students
4. **Wallet System** → Earnings and payouts
5. **Reviews & Ratings** → Feedback system

---

## 📝 **Notes**

- All screens have navigation set up
- Database schema supports all features
- Booking system is already implemented (student side)
- Need to connect tutor-facing screens to existing data
- Most work is UI + data fetching, not new backend logic





