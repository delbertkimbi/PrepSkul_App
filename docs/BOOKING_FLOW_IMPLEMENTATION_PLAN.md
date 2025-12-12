# 🎯 Complete Booking Flow Implementation Plan

**Date:** October 29, 2025  
**Feature:** Full Tutor Booking System (Regular Sessions)  
**Status:** Ready to Implement

---

## 📋 **WHAT WE'RE BUILDING**

A comprehensive booking flow that:
1. Lets students/parents book tutors for **regular recurring sessions** (not just trials)
2. Uses survey data to **pre-fill preferences** (days, times, frequency, location)
3. Shows **calendar-style time selection** (like trial booking)
4. Considers **tutor availability** and existing bookings
5. Calculates **monthly pricing** with payment plan options
6. Sends **booking requests** to tutors for approval
7. Displays **pending requests** in dashboards

---

## 🔄 **COMPLETE USER FLOW**

### **Student/Parent Journey:**

```
1. Browse Tutors (FindTutorsScreen)
   ↓
2. View Tutor Details (TutorDetailScreen)
   ↓ Watch video, read bio, see pricing
3. Click "Book This Tutor" button
   ↓
4. STEP 1: Session Frequency
   - "How many sessions per week?"
   - Options: 1x, 2x, 3x, 4x, Custom
   - Pre-filled from survey if available
   - Shows monthly estimate for each option
   ↓
5. STEP 2: Days Selection
   - "Which days work best?"
   - Calendar-style day picker
   - Shows tutor's available days
   - Pre-filled from survey
   - Highlights unavailable days (grayed out)
   ↓
6. STEP 3: Time Selection (per day)
   - Beautiful time grid (like trial booking)
   - Shows tutor's available slots
   - User picks time for each selected day
   - Considers existing bookings
   - Shows conflicts (e.g., "Tutor has another student")
   ↓
7. STEP 4: Location Preference
   - Online, Onsite, or Hybrid
   - If onsite: Collect address
   - Pre-filled from survey
   - Shows which days online/onsite (if hybrid)
   ↓
8. STEP 5: Review & Payment Plan
   - Summary of all selections
   - Monthly pricing breakdown
   - Payment options:
     • Monthly (10% discount)
     • Bi-weekly (5% discount)
     • Weekly (no discount)
   - Terms & conditions
   ↓
9. Send Request to Tutor
   - Request saved to database
   - Notification sent to tutor
   - Shows "Pending" in student dashboard
```

### **Tutor Journey:**

```
1. Tutor receives notification
   ↓
2. Views request in dashboard
   - Student/parent info
   - Requested schedule
   - Session details
   - Survey data (goals, challenges, level)
   ↓
3. Reviews availability
   - Checks calendar
   - Sees potential conflicts
   - Views student's background
   ↓
4. Takes action:
   Option A: ✅ Approve
   Option B: ❌ Reject (with reason)
   Option C: 📝 Propose Modification (different times)
   ↓
5. Student/parent receives notification
   - If approved: Session confirmed
   - If rejected: Reason displayed
   - If modified: Review proposed changes
```

---

## 🎨 **UI DESIGN SPECIFICATIONS**

### **Step 1: Session Frequency**

```
┌──────────────────────────────────────┐
│ [Back]  Book Regular Sessions        │
│─────────────────────────────────────│
│                                      │
│ How many sessions per week?          │
│                                      │
│ ┌──────────────────────────────────┐ │
│ │ ⚪ 1x per week                   │ │
│ │    4 sessions/month              │ │
│ │    Est. 40,000 XAF/month         │ │
│ └──────────────────────────────────┘ │
│                                      │
│ ┌──────────────────────────────────┐ │
│ │ 🔵 2x per week  ← Pre-filled    │ │
│ │    8 sessions/month              │ │
│ │    Est. 80,000 XAF/month         │ │
│ └──────────────────────────────────┘ │
│                                      │
│ ┌──────────────────────────────────┐ │
│ │ ⚪ 3x per week                   │ │
│ │    12 sessions/month             │ │
│ │    Est. 120,000 XAF/month        │ │
│ └──────────────────────────────────┘ │
│                                      │
│ ┌──────────────────────────────────┐ │
│ │ ⚪ Custom schedule                │ │
│ └──────────────────────────────────┘ │
│                                      │
│             [Continue]               │
└──────────────────────────────────────┘
```

### **Step 2: Days Selection**

```
┌──────────────────────────────────────┐
│ [Back]  Select Days (2/6)            │
│─────────────────────────────────────│
│                                      │
│ Which days work best for you?        │
│                                      │
│ Tutor's Available Days:              │
│ Mon, Tue, Wed, Fri, Sat             │
│                                      │
│ ┌──────────────────────────────────┐ │
│ │  Mon   Tue   Wed   Thu   Fri    │ │
│ │  [✓]   [ ]   [✓]   [X]   [ ]    │ │
│ │        Pre-filled     Not         │ │
│ │                    available      │ │
│ │                                  │ │
│ │  Sat   Sun                       │ │
│ │  [ ]   [X]                       │ │
│ └──────────────────────────────────┘ │
│                                      │
│ ✅ 2 days selected                   │
│                                      │
│             [Continue]               │
└──────────────────────────────────────┘
```

### **Step 3: Time Selection (Beautiful Calendar Grid)**

```
┌──────────────────────────────────────┐
│ [Back]  Select Times (3/6)           │
│─────────────────────────────────────│
│                                      │
│ Monday Sessions                      │
│                                      │
│ Afternoon (12 PM - 6 PM)            │
│ ┌────────────────────────────────┐  │
│ │ [12:00] [12:30] [1:00] [1:30] │  │
│ │ [2:00]  [2:30]  [3:00] [3:30] │  │
│ │ [4:00]  [4:30]  [5:00] [5:30] │  │
│ └────────────────────────────────┘  │
│                                      │
│ Evening (6 PM - 10 PM)              │
│ ┌────────────────────────────────┐  │
│ │ [6:00]  [6:30]  [7:00] [7:30] │  │
│ │ [8:00]  [8:30]  [9:00] [9:30] │  │
│ └────────────────────────────────┘  │
│                                      │
│ ✅ Selected: Monday 3:00 PM          │
│                                      │
│ ⚠️ Note: Tutor has another student  │
│    Mon 4:00-5:00 PM                 │
│                                      │
│             [Next Day]               │
└──────────────────────────────────────┘
```

### **Step 4: Location Preference**

```
┌──────────────────────────────────────┐
│ [Back]  Location (4/6)               │
│─────────────────────────────────────│
│                                      │
│ Where should sessions happen?        │
│                                      │
│ ┌──────────────────────────────────┐ │
│ │ 🔵 Online Sessions                │ │
│ │    Via Google Meet or Zoom       │ │
│ └──────────────────────────────────┘ │
│                                      │
│ ┌──────────────────────────────────┐ │
│ │ ⚪ Onsite Sessions                │ │
│ │    At learner's location         │ │
│ └──────────────────────────────────┘ │
│                                      │
│ ┌──────────────────────────────────┐ │
│ │ ⚪ Hybrid                         │ │
│ │    Some online, some onsite      │ │
│ └──────────────────────────────────┘ │
│                                      │
│ [If Onsite selected:]                │
│ ┌──────────────────────────────────┐ │
│ │ Address                          │ │
│ │ [Yaoundé, Bastos]    ← From survey│ │
│ │                                  │ │
│ │ Specific Location                │ │
│ │ [Quarter, landmark, etc.]        │ │
│ └──────────────────────────────────┘ │
│                                      │
│             [Continue]               │
└──────────────────────────────────────┘
```

### **Step 5: Review & Payment Plan**

```
┌──────────────────────────────────────┐
│ [Back]  Review & Confirm (5/6)       │
│─────────────────────────────────────│
│                                      │
│ 📋 Booking Summary                   │
│                                      │
│ Tutor: Dr. Marie Ngono               │
│ Subject: Mathematics                 │
│                                      │
│ 📅 Schedule:                         │
│ • Monday 3:00 PM (Online)            │
│ • Wednesday 3:00 PM (Online)         │
│                                      │
│ Frequency: 2 sessions/week           │
│ Location: Online                     │
│                                      │
│ ─────────────────────────────────── │
│                                      │
│ 💰 Pricing Breakdown                 │
│                                      │
│ Per Session:    10,000 XAF          │
│ × 8 sessions:   80,000 XAF/month    │
│                                      │
│ ─────────────────────────────────── │
│                                      │
│ 💳 Choose Payment Plan               │
│                                      │
│ ┌──────────────────────────────────┐ │
│ │ ⚪ Pay Monthly (Save 10%)        │ │
│ │    72,000 XAF/month              │ │
│ │    + Free PrepSkul supplies      │ │
│ └──────────────────────────────────┘ │
│                                      │
│ ┌──────────────────────────────────┐ │
│ │ 🔵 Pay Bi-weekly (Save 5%)       │ │
│ │    38,000 XAF × 2                │ │
│ └──────────────────────────────────┘ │
│                                      │
│ ┌──────────────────────────────────┐ │
│ │ ⚪ Pay Weekly                     │ │
│ │    20,000 XAF × 4                │ │
│ └──────────────────────────────────┘ │
│                                      │
│ ℹ️ Payments add credits to account  │
│    Credits deducted per session     │
│                                      │
│      [Send Request to Tutor]         │
└──────────────────────────────────────┘
```

### **Step 6: Request Sent**

```
┌──────────────────────────────────────┐
│           Request Sent! ✅           │
│─────────────────────────────────────│
│                                      │
│          [Checkmark Icon]            │
│                                      │
│ Your booking request has been        │
│ sent to Dr. Marie Ngono!            │
│                                      │
│ ⏰ What happens next?                │
│                                      │
│ 1. Tutor reviews your request        │
│ 2. You'll receive notification       │
│ 3. If approved, payment required     │
│ 4. Sessions start as scheduled       │
│                                      │
│ You can track this request in        │
│ your dashboard.                      │
│                                      │
│    [View My Requests]  [Go Home]     │
└──────────────────────────────────────┘
```

---

## 📱 **DASHBOARD DISPLAYS**

### **Student/Parent Dashboard - Pending Requests**

```
┌──────────────────────────────────────┐
│ My Booking Requests                  │
│─────────────────────────────────────│
│                                      │
│ ┌──────────────────────────────────┐ │
│ │ 👤 Dr. Marie Ngono               │ │
│ │ Mathematics                       │ │
│ │                                  │ │
│ │ 🕒 Pending Approval               │ │
│ │ Mon & Wed, 3:00 PM               │ │
│ │ Requested: Oct 29, 2025          │ │
│ │                                  │ │
│ │        [View Details] [Cancel]   │ │
│ └──────────────────────────────────┘ │
│                                      │
│ ┌──────────────────────────────────┐ │
│ │ 👤 Njoku Emmanuel                │ │
│ │ Python Programming               │ │
│ │                                  │ │
│ │ ✅ Approved!                      │ │
│ │ Tue & Thu, 5:00 PM               │ │
│ │                                  │ │
│ │    [Make Payment] [View Details] │ │
│ └──────────────────────────────────┘ │
│                                      │
└──────────────────────────────────────┘
```

### **Tutor Dashboard - Pending Requests**

```
┌──────────────────────────────────────┐
│ Booking Requests (3 new)             │
│─────────────────────────────────────│
│                                      │
│ ┌──────────────────────────────────┐ │
│ │ 👤 Amina Hassan (Student)        │ │
│ │ Grade 12 - Mathematics           │ │
│ │                                  │ │
│ │ 📅 Requested Schedule:            │ │
│ │ Mon & Wed, 3:00-4:00 PM (Online) │ │
│ │                                  │ │
│ │ 💰 Monthly: 80,000 XAF            │ │
│ │                                  │ │
│ │ 📝 Student Goals:                 │ │
│ │ "Improve GCE A-Level prep..."    │ │
│ │                                  │ │
│ │ ⚠️ Conflicts:                     │ │
│ │ • Mon 3-4 PM: Another student    │ │
│ │                                  │ │
│ │ [✅ Approve] [❌ Reject]           │ │
│ │ [📝 Suggest Different Times]      │ │
│ └──────────────────────────────────┘ │
│                                      │
└──────────────────────────────────────┘
```

---

## 🗂️ **FILES TO CREATE**

### **1. Booking Flow Screens**
- ✅ `lib/features/booking/screens/book_tutor_flow_screen.dart` (Main wizard)
- ✅ `lib/features/booking/widgets/frequency_selector.dart`
- ✅ `lib/features/booking/widgets/days_selector.dart`
- ✅ `lib/features/booking/widgets/time_grid_selector.dart`
- ✅ `lib/features/booking/widgets/location_selector.dart`
- ✅ `lib/features/booking/widgets/booking_review.dart`
- ✅ `lib/features/booking/widgets/payment_plan_selector.dart`

### **2. Dashboard Screens**
- ✅ `lib/features/student/screens/my_requests_screen.dart`
- ✅ `lib/features/tutor/screens/pending_requests_screen.dart`
- ✅ `lib/features/tutor/screens/request_detail_screen.dart`

### **3. Models**
- ✅ `lib/models/booking_request.dart`
- ✅ `lib/models/recurring_session.dart`

### **4. Services**
- ✅ `lib/core/services/booking_service.dart`
- ✅ `lib/core/services/availability_service.dart`

---

## 📋 **TODO TASKS (Step-by-Step)**

### **PHASE 1: Core Booking Flow (Days 1-3)**

**Day 1: Setup & Step 1**
1. ✅ Create folder structure (`lib/features/booking/`)
2. ✅ Create `BookTutorFlowScreen` (main wizard with PageView)
3. ✅ Build **Step 1: Frequency Selector**
   - Radio buttons for 1x, 2x, 3x, 4x, custom
   - Show monthly estimate for each option
   - Pre-fill from survey data (if available)
   - Calculate pricing dynamically

**Day 2: Steps 2 & 3**
4. ✅ Build **Step 2: Days Selector**
   - Grid of day buttons (Mon-Sun)
   - Mark tutor's available days
   - Disable unavailable days
   - Pre-fill from survey
   - Visual feedback (checkmarks)
5. ✅ Build **Step 3: Time Grid Selector**
   - Calendar-style time grid (like trial booking)
   - Group by Afternoon/Evening
   - Show per day (for each selected day)
   - Mark unavailable slots
   - Show conflicts (other students)

**Day 3: Steps 4 & 5**
6. ✅ Build **Step 4: Location Selector**
   - Radio buttons: Online, Onsite, Hybrid
   - Address input (if onsite)
   - Pre-fill from survey
7. ✅ Build **Step 5: Booking Review**
   - Summary card with all selections
   - Pricing breakdown
   - Payment plan options
   - Final CTA button

### **PHASE 2: Request Management (Days 4-5)**

**Day 4: Student/Parent Side**
8. ✅ Create `MyRequestsScreen`
   - List of pending/approved/rejected requests
   - Request cards with status badges
   - View details button
   - Cancel request option
9. ✅ Create request detail view
   - Full request information
   - Status timeline
   - Action buttons (cancel, modify)

**Day 5: Tutor Side**
10. ✅ Create `PendingRequestsScreen`
    - List of pending booking requests
    - Request cards with student info
    - Priority indicators (urgent, conflicts)
11. ✅ Create `RequestDetailScreen` (tutor view)
    - Full request details
    - Student survey data
    - Availability conflict warnings
    - Action buttons: Approve, Reject, Modify

### **PHASE 3: Backend Integration (Days 6-7)**

**Day 6: Services & Models**
12. ✅ Create `booking_request.dart` model
    - All request fields
    - Status enum
    - JSON serialization
13. ✅ Create `BookingService`
    - `createRequest()`
    - `fetchRequests()` (student/tutor)
    - `approveRequest()`
    - `rejectRequest()`
    - `modifyRequest()`
14. ✅ Create `AvailabilityService`
    - `checkTutorAvailability()`
    - `detectConflicts()`
    - `getSuggestedTimes()`

**Day 7: Integration & Testing**
15. ✅ Connect booking flow to Supabase
16. ✅ Implement real-time updates
17. ✅ Add notifications (push/email)
18. ✅ Test complete flow end-to-end

---

## 🎯 **SMART PREFILLING LOGIC**

### **From Survey Data:**

```dart
// Example: Load survey data and prefill booking
final surveyData = await getSurveyData(userId);

// Frequency (from survey question)
if (surveyData['preferred_session_frequency'] != null) {
  _selectedFrequency = surveyData['preferred_session_frequency'];
}

// Days (from survey schedule preferences)
if (surveyData['preferred_schedule'] != null) {
  final schedule = surveyData['preferred_schedule'] as Map;
  _selectedDays = schedule['days'] ?? [];
  _preferredTimes = schedule['times'] ?? {};
}

// Location (from survey)
if (surveyData['preferred_location'] != null) {
  _selectedLocation = surveyData['preferred_location']; // online/onsite/hybrid
}

// Address (if parent/student provided)
if (surveyData['city'] != null) {
  _address = '${surveyData['city']}, ${surveyData['quarter']}';
}
```

---

## ✅ **ACCEPTANCE CRITERIA**

### **Booking Flow:**
- [ ] User can complete 5-step booking wizard
- [ ] All steps have clear navigation (back/continue)
- [ ] Survey data pre-fills automatically
- [ ] Time slots match tutor availability
- [ ] Conflicts are detected and shown
- [ ] Monthly pricing calculates correctly
- [ ] Payment plan discounts apply
- [ ] Request saves to database

### **Dashboard:**
- [ ] Student sees pending/approved/rejected requests
- [ ] Tutor sees all pending requests
- [ ] Status badges display correctly
- [ ] Conflict warnings show for tutors
- [ ] Action buttons work (approve/reject/modify)
- [ ] Notifications sent on status change

### **UX:**
- [ ] Clean, modern UI (consistent with app theme)
- [ ] Calendar-style time grid (beautiful, intuitive)
- [ ] Smooth animations between steps
- [ ] Loading states during saves
- [ ] Error handling (network, validation)
- [ ] Responsive design (works on all screens)

---

## 🚀 **NEXT IMMEDIATE STEPS**

1. **Create TODO tasks** in the system
2. **Start with Day 1** (Frequency Selector)
3. **Build incrementally** (one step at a time)
4. **Test as we go** (validate each step before moving on)
5. **Commit frequently** (Git commits after each component)

---

**Ready to start building?** Let me know and I'll create the TODO tasks and begin with Day 1! 🎉

