 # 📚 Complete Booking Flows Explained

**Last Updated:** January 2025

> **📱 Notification Types:** All notifications are sent in three ways:
> - **In-App:** ✅ Always sent (Supabase notifications table)
> - **Push:** ✅ Sent via API (Firebase Cloud Messaging)
> - **Email:** ✅ Sent via API (Resend)
> 
> See [NOTIFICATION_STRATEGY.md](./NOTIFICATION_STRATEGY.md) for complete details.

---

## 💰 **TUTOR WALLET SYSTEM: PENDING vs ACTIVE BALANCE**

### **Balance Types Explained:**

#### **1. Pending Balance** ⏳
- **What it is:** Earnings that are **awaiting quality assurance and feedback processing**
- **When it's created:** 
  - When a session completes and payment record is created
  - Tutor earnings (85% of session fee) are added to pending balance
- **Status:** `earnings_status = 'pending'` in `tutor_earnings` table
- **Duration:** 24-48 hours (quality assurance period)
- **Purpose:** Hold period to ensure session quality through:
  - **Student/Parent feedback collection** (24 hours after session)
  - **Quality assurance checks** (attendance, punctuality, session quality)
  - **Issue detection** (recurrent late coming, poor feedback, complaints)
  - **Fine calculation** (if issues detected):
    - Late arrival fines
    - No-show penalties
    - Poor feedback deductions
    - Other quality-related fines
  - **Refund processing** (worst case scenario):
    - If severe issues or complaints
    - Refund to parent's PrepSkul account (points system)
    - Or refund back to parent's mobile money (Momo)
  - **Points system integration:**
    - Payments give points based on tutor pricing
    - Points stored in parent/student account
    - Points can be used for future sessions
- **Cannot be withdrawn:** Pending balance is not available for payout until quality assurance period passes

#### **2. Active Balance** ✅
- **What it is:** Earnings that are **quality-assured and available for withdrawal**
- **When it's created:**
  - After 24-48 hour quality assurance period passes
  - After feedback is collected and processed
  - After any fines are deducted (if applicable)
  - After refunds are processed (if needed)
  - Earnings automatically move from `pending` → `active` status
- **Status:** `earnings_status = 'active'` in `tutor_earnings` table
- **Purpose:** Available funds that tutor can request for payout
- **Can be withdrawn:** Active balance can be requested for payout
- **Automatic Movement:** System automatically moves earnings from pending to active after:
  - Quality assurance period (24-48h) completes
  - No issues detected OR issues resolved
  - Feedback processed (or feedback period expired)

### **Balance Flow:**
```
Session Completes
    ↓
Payment Record Created
    ↓
Tutor Earnings Added to PENDING Balance
    ↓
24-48 Hour Quality Assurance Period
    ↓
[Feedback Collection]
[Quality Checks]
[Issue Detection]
    ↓
If Issues Found:
  - Fines Deducted
  - Or Refund Processed (worst case)
    ↓
After 24-48 Hours (Auto):
Earnings Move to ACTIVE Balance
    ↓
Tutor Can Request Payout
```

### **Example:**
- **Session Fee:** 10,000 XAF
- **Platform Fee (15%):** 1,500 XAF
- **Tutor Earnings (85%):** 8,500 XAF
- **Initially:** 8,500 XAF in **Pending Balance**
- **After Payment Confirmed:** 8,500 XAF moves to **Active Balance**
- **Tutor Wallet:**
  - Pending: 0 XAF
  - Active: 8,500 XAF
  - Total: 8,500 XAF

---

## 🎯 **TRIAL SESSION BOOKING (Online)**

### **What Happens When Someone Books a Trial Session Online:**

#### **Step 1: Student/Parent Initiates Booking**
1. Student clicks "Book Trial Session" on tutor profile
2. **3-Step Wizard:**
   - **Step 1:** Select subject & duration (30 min = 2,000 XAF, 60 min = 3,500 XAF)
   - **Step 2:** Select date & time from calendar
   - **Step 3:** Enter trial goal & challenges (optional)

#### **Step 2: Trial Request Created**
- ✅ Trial session record created in `trial_sessions` table
- ✅ Status: `pending`
- ✅ Payment status: `unpaid`
- ✅ Location: `Online` (default)
- ✅ **Notifications sent to tutor** (In-app ✅ Always, Push ✅ Via API, Email ✅ Via API) about new trial request

#### **Step 3: Tutor Approval/Rejection**
- **If Tutor Approves:**
  - Status changes to `approved`
  - Student can now proceed to payment
  - **Notifications sent to student** (In-app ✅ Always, Push ✅ Via API, Email ✅ Via API)
  
- **If Tutor Rejects:**
  - Status changes to `rejected`
  - Rejection reason stored
  - **Notifications sent to student** (In-app ✅ Always, Push ✅ Via API, Email ✅ Via API) with reason

#### **Step 4: Payment (After Approval)**
1. Student enters phone number
2. **Payment initiated via Fapshi:**
   - Fapshi payment request sent to student's phone
   - Transaction ID stored in `trial_sessions.fapshi_trans_id`
   - Payment status: `pending`
3. **Payment polling** (every 3 seconds, max 2 minutes):
   - System checks payment status
   - When payment succeeds → proceeds to Step 5

#### **Step 5: Meet Link Generation (After Payment)**
- ✅ Payment status updated to `paid`
- ✅ **Google Calendar event created automatically:**
  - Title: "Trial Session: [Subject]"
  - Date/Time: Scheduled date & time
  - Duration: Session duration
  - Attendees:
    - Tutor email
    - Student/Parent email
    - `prepskul-va@prepskul.com` (PrepSkul Virtual Assistant)
- ✅ **Google Meet link auto-generated** by Calendar API
- ✅ Meet link stored in `trial_sessions.meet_link`
- ✅ Calendar event ID stored
- ✅ **Notifications sent** to both tutor and student (In-app ✅ Always, Push ✅ Via API, Email ✅ Via API) with Meet link

#### **Step 6: Session Day (Automated)**
- ✅ **Fathom AI automatically:**
  - Monitors PrepSkul VA's Google Calendar
  - Detects meeting time
  - **Auto-joins Google Meet** as participant
  - **Starts recording** when meeting begins
  - **Transcribes in real-time**
  - **Generates summary** after meeting ends
  - **Extracts action items**
  - Flags admin for any irregularities

#### **Step 7: Post-Session**
- ✅ Session can be marked as `completed`
- ✅ Student can convert to regular booking (optional)
- ✅ Fathom summary sent to both parties

---

## 🎓 **REGULAR TUTOR BOOKING (Online/Onsite/Hybrid)**

### **What Happens When Someone Books a Tutor:**

#### **Step 1: Student/Parent Initiates Booking**
1. Student clicks "Book This Tutor" on tutor profile
2. **5-Step Wizard:**
   - **Step 1:** Session Frequency (1x, 2x, 3x, 4x per week)
   - **Step 2:** Days Selection (Monday, Wednesday, etc.)
   - **Step 3:** Time Selection (specific times for each day)
   - **Step 4:** Location Preference:
     - **Online:** No address needed
     - **Onsite:** Requires address & location description
     - **Hybrid:** Mix of online and onsite days
   - **Step 5:** Review & Payment Plan (Monthly, Bi-weekly, Weekly)

#### **Step 2: Booking Request Created**
- ✅ Booking request created in `booking_requests` table
- ✅ Status: `pending`
- ✅ Includes:
  - Frequency, days, times
  - Location preference (online/onsite/hybrid)
  - Address (if onsite/hybrid)
  - Payment plan
  - Monthly total calculated
- ✅ **Notifications sent to tutor** (In-app ✅ Always, Push ✅ Via API, Email ✅ Via API) about new booking request

#### **Step 3: Tutor Approval/Rejection**

**When Tutor Approves:**

1. **Booking Request Updated:**
   - Status changes to `approved`
   - `responded_at` timestamp set
   - Optional `tutor_response` message stored
   - Conflict check performed (if schedule overlaps)

2. **Recurring Session Created:**
   - New record in `recurring_sessions` table
   - Status: `active`
   - Start date: Next occurrence of first selected day
   - End date: `null` (ongoing)
   - Payment plan stored: `monthly`, `bi-weekly`, or `weekly`
   - Monthly total stored for calculations

3. **Individual Sessions Generated:**
   - Creates sessions for next **8 weeks ahead**
   - Each session in `individual_sessions` table
   - Status: `scheduled`
   - For **online sessions:** Meet links will be generated when session starts
   - For **onsite sessions:** Address stored for each session
   - For **hybrid sessions:** Each session knows its location type

4. **Payment Requests Created (Based on Payment Plan):**
   
   **SMART CALCULATION & PAYMENT REQUEST LAUNCH:**
   
   The system calculates and creates payment requests based on the student's selected payment plan:
   
   **A. Monthly Payment Plan:**
   - **Calculation:** `monthly_total` (from booking request)
   - **Payment Amount:** Full monthly total (e.g., 40,000 XAF)
   - **Payment Request Created:** 
     - One payment request for the full month
     - Due date: Start date of recurring session
     - Payment screen launched for student
   - **Frequency:** Once per month
   
   **B. Bi-Weekly Payment Plan:**
   - **Calculation:** `monthly_total / 2`
   - **Payment Amount:** Half of monthly total (e.g., 20,000 XAF)
   - **Payment Requests Created:**
     - First payment: Due on start date
     - Second payment: Due 2 weeks later
     - Payment screen launched for first payment
   - **Frequency:** Every 2 weeks
   
   **C. Weekly Payment Plan:**
   - **Calculation:** `monthly_total / 4` (assuming 4 weeks per month)
   - **Payment Amount:** Quarter of monthly total (e.g., 10,000 XAF)
   - **Payment Requests Created:**
     - First payment: Due on start date
     - Subsequent payments: Every week
     - Payment screen launched for first payment
   - **Frequency:** Every week
   
   **Payment Request Details:**
   - Payment record created in `recurring_payments` or similar table
   - Amount calculated based on plan
   - Due date set based on plan
   - Status: `pending`
   - **Student receives notifications** (In-app ✅ Always, Push ✅ Via API, Email ✅ Via API) with payment request
   - **Payment screen automatically launched** for student to pay
   - Student can pay via Fapshi (phone number)

5. **Notifications Sent:**
   - **To Student:** Booking approved notification + Payment request notification
   - **Types:** In-app ✅ Always, Push ✅ Via API, Email ✅ Via API
   - **To Tutor:** Confirmation that recurring session was created

6. **Sessions Appear:**
   - Sessions visible in both tutor and student dashboards
   - Upcoming sessions listed
   - Payment status visible

**When Tutor Rejects:**
- Status changes to `rejected`
- `responded_at` timestamp set
- `rejection_reason` required and stored
- **Notifications sent to student** (In-app ✅ Always, Push ✅ Via API, Email ✅ Via API) with rejection reason
- No sessions created
- No payment requests created

#### **Step 4: Session Lifecycle (For Each Individual Session)**

**For Online Sessions:**

**When Session Starts:**
1. **Tutor Action:**
   - Tutor clicks "Start Session" button in their dashboard
   - System calls `SessionLifecycleService.startSession(sessionId)`

2. **System Actions:**
   - **Status Update:** `scheduled` → `in_progress`
   - **Timestamps:**
     - `session_started_at` = current time
     - `updated_at` = current time
   
3. **Google Meet Link Generation:**
   - System calls `IndividualSessionService.getOrGenerateMeetLink()`
   - If link doesn't exist:
     - Google Calendar event created
     - Google Meet link auto-generated by Calendar API
     - Link stored in `individual_sessions.meet_link`
     - Calendar event ID stored
   - If link exists: Retrieved from database
   
4. **Fathom AI Integration:**
   - Fathom monitors PrepSkul VA's calendar
   - Detects meeting start time
   - **Auto-joins Google Meet** as participant
   - **Starts recording** when meeting begins
   - **Real-time transcription** begins
   
5. **Attendance Tracking:**
   - Attendance record created in `session_attendance` table
   - Tutor marked as `present` with `joined_at` timestamp
   - Student attendance tracked when they join
   
6. **Notifications:**
   - **To Student:** "Session has started! Join the meeting."
   - **To Tutor:** Confirmation that session started
   - Both receive Meet link

**When Session Ends:**
1. **Tutor Action:**
   - Tutor clicks "End Session" button
   - System shows dialog to collect:
     - Session notes
     - Progress notes
     - Homework assigned
     - Next focus areas
     - Student engagement rating (1-5)
   - Tutor submits end session form

2. **System Actions:**
   - **Status Update:** `in_progress` → `completed`
   - **Timestamps:**
     - `session_ended_at` = current time
     - `actual_duration_minutes` = calculated from start/end times
     - `updated_at` = current time
   
3. **Fathom Processing:**
   - Fathom recording stops
   - **Transcript generated** (full conversation text)
   - **Summary generated** (key points, topics covered)
   - **Action items extracted** (homework, next steps)
   - **Admin flags** (if any irregularities detected)
   - Summary sent to both tutor and student
   
4. **Payment Processing:**
   - **Payment Record Created:**
     - `SessionPaymentService.createSessionPayment(sessionId)` called
     - Record created in `session_payments` table
     - **Calculation:**
       - `session_fee` = `monthly_total / (frequency * 4)`
       - `platform_fee` = `session_fee * 0.15` (15%)
       - `tutor_earnings` = `session_fee * 0.85` (85%)
     - Payment status: `unpaid`
   
   - **Tutor Earnings Record Created:**
     - Record created in `tutor_earnings` table
     - `earnings_status` = `pending`
     - `tutor_earnings` = 85% of session fee
     - Linked to `session_payment_id`
   
   - **Pending Balance Updated:**
     - Tutor's pending balance increased by `tutor_earnings`
     - `added_to_pending_balance` = `true`
     - `pending_balance_added_at` = current time
   
   - **Payment Initiation:**
     - **If payment plan is per-session:**
       - Payment request sent to student via Fapshi
       - Student receives notification
       - Payment screen launched
       - Student pays via phone number
     - **If payment plan is monthly/bi-weekly/weekly:**
       - Payment already handled via recurring payment requests
       - This session's payment linked to existing payment request
   
5. **Recurring Session Totals Updated:**
   - `total_sessions_completed` incremented
   - `total_revenue` increased by session fee
   - `last_session_date` updated
   
6. **Feedback Request Scheduled:**
   - Feedback request scheduled for 24 hours after session end
   - Notification will be sent to student
   
7. **Notifications:**
   - **To Student:** "Session completed! Please provide feedback."
   - **To Tutor:** "Session completed. Earnings added to pending balance."

**For Onsite Sessions:**
- ✅ **Location details displayed:**
  - Full address shown
  - Map integration (if available)
  - Directions link
- ✅ **Check-in available:**
  - Tutor/student can check in when they arrive
  - Manual attendance tracking
- ✅ **When session starts/ends:**
  - Similar to online, but no Meet link
  - Payment and feedback flow same as online

**For Hybrid Sessions:**
- ✅ **Each session knows its location:**
  - Some sessions online (with Meet links)
  - Some sessions onsite (with address)
  - Determined by the booking configuration

#### **Step 5: Payment Processing & Balance Updates**

**Payment Flow (Per Session or Per Payment Plan):**

**A. Per-Session Payment (If applicable):**
1. **Payment Initiation:**
   - After session completes, payment record exists with status `unpaid`
   - Student receives payment request notification
   - Payment screen launched automatically
   - Student enters phone number
   - `SessionPaymentService.initiatePayment()` called
   - Fapshi payment request sent to student's phone
   - Transaction ID stored in `session_payments.fapshi_trans_id`
   - Payment status: `unpaid` → `pending`

2. **Payment Polling:**
   - System polls Fapshi for payment status (every 3 seconds, max 2 minutes)
   - Student completes payment on their phone
   - Payment status detected

3. **Payment Confirmation (via Fapshi Webhook):**
   - Fapshi sends webhook to `/api/webhooks/fapshi/route.ts`
   - Webhook handler calls `SessionPaymentService.handlePaymentWebhook()`
   - Payment status updated: `pending` → `paid`
   - `payment_confirmed_at` timestamp set

4. **Balance Movement (PENDING → ACTIVE):**
   - **Tutor Earnings Status Updated:**
     - `earnings_status`: `pending` → `active`
     - `active_balance_added_at` = current time
     - `added_to_active_balance` = `true`
   
   - **Pending Balance Decreased:**
     - Amount removed from pending balance
   
   - **Active Balance Increased:**
     - Amount added to active balance
     - Tutor can now request payout
   
   - **Wallet Status Updated:**
     - `earnings_added_to_wallet` = `true`
     - `wallet_updated_at` = current time

5. **Notifications:**
   - **To Student:** "Payment confirmed! Thank you."
   - **To Tutor:** "Payment received! Earnings moved to active balance (8,500 XAF)."

**B. Recurring Payment Plan (Monthly/Bi-Weekly/Weekly):**
1. **Payment Request Created (When Tutor Approves):**
   - Based on payment plan, payment requests created upfront
   - First payment due on session start date
   - Subsequent payments scheduled based on plan

2. **Payment Screen Launch:**
   - When tutor approves, student automatically sees payment screen
   - Shows payment amount based on plan
   - Student can pay immediately or later (before due date)

3. **Payment Processing:**
   - Same flow as per-session payment
   - Payment linked to multiple sessions (for that payment period)
   - When payment confirmed, all sessions in that period are marked as paid

4. **Balance Updates:**
   - Same pending → active flow
   - Earnings distributed across sessions in the payment period

**C. Payment Failure Handling:**
- If payment fails:
  - Payment status: `pending` → `failed`
  - `payment_failed_at` timestamp set
  - Student receives notification to retry payment
  - Tutor earnings remain in `pending` status
  - No movement to active balance
  - Student can retry payment

**D. Refund Processing:**
- If refund is needed:
  - `SessionPaymentService.processRefund()` called
  - Payment status: `paid` → `refunded`
  - `refunded_at` timestamp set
  - `refund_reason` stored
  - Tutor earnings status: `active` → `cancelled`
  - Amount removed from active balance
  - Refund processed via Fapshi (if available)

#### **Step 6: Feedback & Reviews**
- ✅ **24 hours after session:**
  - Student receives feedback request
  - Can rate (1-5 stars) and write review
  - Feedback stored in `session_feedback`
  - **Tutor rating updated:**
    - If tutor has < 3 reviews: Uses `admin_approved_rating`
    - If tutor has ≥ 3 reviews: Calculates from student feedback
  - Review displayed on tutor profile

---

## 🔄 **KEY DIFFERENCES**

| Feature | Trial Session | Regular Booking |
|---------|--------------|-----------------|
| **Type** | One-time | Recurring (ongoing) |
| **Payment** | Upfront (before session) | Per session (after completion) |
| **Meet Link** | Generated after payment | Generated when session starts |
| **Location** | Online only (default) | Online, Onsite, or Hybrid |
| **Sessions Created** | 1 session | Multiple sessions (8 weeks ahead) |
| **Approval Required** | Yes (tutor must approve) | Yes (tutor must approve) |
| **Conversion** | Can convert to regular booking | N/A |

---

## 📊 **DATABASE TABLES INVOLVED**

### **Trial Sessions:**
- `trial_sessions` - Main trial session records
  - Fields: `tutor_id`, `learner_id`, `subject`, `scheduled_date`, `scheduled_time`, `duration_minutes`, `location`, `status`, `trial_fee`, `payment_status`, `fapshi_trans_id`, `meet_link`, `calendar_event_id`
- `notifications` - Trial request notifications
- `profiles` - User profile data (for student/tutor names)

### **Regular Bookings:**
- `booking_requests` - Initial booking requests
  - Fields: `student_id`, `tutor_id`, `frequency`, `days`, `times`, `location`, `address`, `payment_plan`, `monthly_total`, `status`, `tutor_response`, `rejection_reason`
- `recurring_sessions` - Parent recurring session records
  - Fields: `request_id`, `student_id`, `tutor_id`, `frequency`, `days`, `times`, `location`, `payment_plan`, `monthly_total`, `start_date`, `status`, `total_sessions_completed`, `total_revenue`
- `individual_sessions` - Individual session instances
  - Fields: `recurring_session_id`, `tutor_id`, `learner_id`, `scheduled_date`, `scheduled_time`, `duration_minutes`, `location`, `status`, `meet_link`, `payment_id`, `session_started_at`, `session_ended_at`
- `session_payments` - Payment records per session
  - Fields: `session_id`, `session_fee`, `platform_fee`, `tutor_earnings`, `payment_status`, `fapshi_trans_id`, `payment_confirmed_at`, `earnings_added_to_wallet`
- `tutor_earnings` - Tutor earnings tracking
  - Fields: `tutor_id`, `session_id`, `session_fee`, `platform_fee`, `tutor_earnings`, `earnings_status` (pending/active/paid_out/cancelled), `session_payment_id`, `added_to_pending_balance`, `added_to_active_balance`, `pending_balance_added_at`, `active_balance_added_at`
- `session_feedback` - Student feedback/reviews
  - Fields: `session_id`, `student_rating`, `student_review`, `tutor_notes`, `feedback_processed`, `tutor_rating_updated`
- `session_attendance` - Attendance tracking
  - Fields: `session_id`, `user_id`, `user_type`, `joined_at`, `left_at`, `attendance_status`
- `notifications` - Booking request notifications (In-app ✅ Always, Push ✅ Via API, Email ✅ Via API)
- `profiles` - User profile data (for student/tutor names, avatars)

---

## 🎯 **CURRENT STATUS**

### ✅ **What's Working:**
- Trial session booking flow (3-step wizard)
- Regular booking flow (5-step wizard)
- Tutor approval/rejection
- Payment initiation (Fapshi)
- Meet link generation (for trials after payment)
- Booking request notifications
- Recurring session creation from approved requests
- Individual session generation (8 weeks ahead)

### ⏳ **What's Missing (From Todos):**
- **Payment Request Creation on Approval:**
  - ⏳ Create payment requests when tutor approves (based on payment plan)
  - ⏳ Smart calculation for monthly/bi-weekly/weekly plans
  - ⏳ Automatic payment screen launch for student
  - ⏳ Recurring payment request scheduling
  
- **Session Lifecycle:**
  - ⏳ Meet link generation for regular sessions (when session starts)
  - ⏳ Session start/end lifecycle management (partially implemented)
  - ⏳ Attendance tracking UI
  
- **Fathom AI Integration:**
  - ⏳ Auto-join Google Meet
  - ⏳ Recording and transcription
  - ⏳ Summary generation
  - ⏳ Action items extraction
  
- **Onsite Sessions:**
  - ⏳ Location display & maps integration
  - ⏳ Check-in functionality
  - ⏳ Directions link
  
- **Payment Processing:**
  - ⏳ Complete Fapshi webhook integration
  - ⏳ Payment status tracking UI
  - ⏳ Recurring payment management
  
- **Feedback & Reviews:**
  - ⏳ Session feedback collection UI
  - ⏳ Review display on tutor profile
  
- **Other:**
  - ⏳ Session conflict detection improvements
  - ⏳ Tutor wallet payout requests

---

## 🚀 **NEXT STEPS**

Based on the todo list, priority items are:
1. **Online session handling** - Complete Fathom integration
2. **Onsite session handling** - Location display, maps, check-in
3. **Session lifecycle** - Start/end flow with proper state management
4. **Payment per session** - Complete Fapshi webhook integration
5. **Session feedback** - UI for collecting and displaying reviews

