# PrepSkul: Notifications, Activity & Flow (Detailed)

This document maps **who receives what notifications**, **when**, and **what action triggers them**, from onboarding through booking, payment, and attending sessions. It covers **Admin**, **Tutors**, and **Students/Parents**.

---

## How notifications are delivered

| Channel | When used | Notes |
|--------|-----------|--------|
| **In-app** | Always | Stored in Supabase `notifications`; visible in app bell and notification list. Real-time via Supabase Realtime. |
| **Push (FCM)** | When API available | Sent via Next.js API (Firebase Admin SDK). Android/iOS/Web. |
| **Email** | When API available | Sent via Next.js API (Resend). Controlled per notification by `sendEmail`. |

Flow: **In-app is always created first**; then API is called for push + email (fails silently if API is down).

---

## 1. ONBOARDING & SIGNUP

### 1.1 New user signup (any role)

| Recipient | Type | Title | Message (example) | Trigger | Channels |
|-----------|------|--------|-------------------|---------|----------|
| **All admins** | `user_signup` | 👤 New User Signup | `{name} (Student/Parent/Tutor) has just signed up. Email: {email}` | User completes signup (e.g. OTP verification) | In-app, Push, Email |

**Trigger:** `otp_verification_screen.dart` → `NotificationHelperService.notifyAdminsAboutNewUserSignup` after successful verification.

---

### 1.2 Tutor onboarding

| Recipient | Type | Title | Message (example) | Trigger | Channels |
|-----------|------|--------|-------------------|---------|----------|
| **Tutor** | `onboarding_reminder` | (varies) | Reminder to complete profile | Tutor skips onboarding or tutor home detects incomplete onboarding | In-app, Push, Email |

**Trigger:**  
- `tutor_onboarding_choice_screen.dart` when tutor skips onboarding.  
- `tutor_home_screen.dart` when incomplete onboarding is detected.

**Action URL:** `/tutor-onboarding`, **Action text:** "Complete Profile".

---

### 1.3 Survey completion (student/parent)

| Recipient | Type | Title | Message (example) | Trigger | Channels |
|-----------|------|--------|-------------------|---------|----------|
| **All admins** | `survey_completed` | 📝 New Survey Completed | `{name} (Student/Parent) has completed their survey. Learning Path: …` (+ subjects, skills, exam type, location, budget) | Student or parent submits survey | In-app, Push, Email |

**Trigger:**  
- `student_survey.dart` → `NotificationHelperService.notifyAdminsAboutSurveyCompletion`.  
- `parent_survey.dart` → same.

---

### 1.4 Tutor profile (admin actions)

| Recipient | Type | Title | Message (example) | Trigger | Channels |
|-----------|------|--------|-------------------|---------|----------|
| **Tutor** | `profile_approved` | Profile Approved 🎉 | Congratulations! Your tutor profile has been approved and is now live. Students can now book sessions with you! | Admin approves tutor profile | In-app only |
| **Tutor** | `profile_improvement` | 📝 Profile Needs Improvement | Your tutor profile needs some updates. Please review the feedback and update your profile. | Admin requests profile improvements | In-app, Push, Email |
| **Tutor** | `profile_rejected` | ⚠️ Profile Rejected | Your tutor profile application was not approved. Reason: {reason}. You can update your profile and re-apply. | Admin rejects tutor profile | In-app, Push, Email |

**Trigger:** Admin dashboard (profile approval/rejection/improvement).  
**Action URLs:** `/tutor/profile` or `/tutor/profile/edit`.

---

## 2. BOOKING REQUESTS (RECURRING SESSIONS)

### 2.1 Student/parent requests a tutor (recurring booking)

| Recipient | Type | Title | Message (example) | Trigger | Channels |
|-----------|------|--------|-------------------|---------|----------|
| **Tutor** | `booking_request` | 🎓 New Booking Request | `{studentName} wants to book sessions for {subject}. Review and respond to the request.` | Student/parent submits recurring booking request | In-app, Push, Email |

**Trigger:** `booking_service.dart` → `NotificationHelperService.notifyBookingRequestCreated` after creating the booking request.  
**Action URL:** `/bookings/requests/{requestId}`, **Action text:** "View Request".

---

### 2.2 Tutor accepts recurring booking

| Recipient | Type | Title | Message (example) | Trigger | Channels |
|-----------|------|--------|-------------------|---------|----------|
| **Student/parent** | `booking_approved` | Booking Approved | `{tutorName} has accepted your booking request for {subject}. Please proceed to payment.` (+ optional tutor message) | Tutor accepts booking | In-app, Push, Email |

**Trigger:** `booking_service.dart` → `NotificationHelperService.notifyBookingRequestAccepted` (or `notifyMultiLearnerBookingAccepted` for multi-learner).  
**Action URL:** `/payments/{paymentRequestId}` (Pay Now) or `/bookings/{requestId}`.  
**Content:** Includes `payment_request_id` when payment request is created so the app can open payment screen.

---

### 2.3 Tutor rejects recurring booking

| Recipient | Type | Title | Message (example) | Trigger | Channels |
|-----------|------|--------|-------------------|---------|----------|
| **Student/parent** | `booking_rejected` | ⚠️ Booking Declined | `{tutorName} has declined your booking request.` (+ optional reason) | Tutor rejects booking | In-app, Push, Email |

**Trigger:** `booking_service.dart` → `NotificationHelperService.notifyBookingRequestRejected` (or `notifyMultiLearnerBookingRejected`).  
**Action URL:** `/bookings/requests`, **Action text:** "Find Another Tutor".

---

## 3. TRIAL SESSIONS

### 3.1 Student/parent requests trial

| Recipient | Type | Title | Message (example) | Trigger | Channels |
|-----------|------|--------|-------------------|---------|----------|
| **Tutor** | `trial_request` | 🎯 New Trial Session Request | `{studentName} wants to book a trial session for {subject} on {date} at {time}.` | Student/parent submits trial request | In-app, Push, Email |

Variants:  
- Reschedule: "🔄 Reschedule Request for Missed Trial Session" + message about new time.  
- Group: "🎯 New Trial Request (N learners)" for multi-learner trial.

**Trigger:** `trial_session_service.dart` → `NotificationHelperService.notifyTrialRequestCreated` when creating or rescheduling a trial request.  
**Action URL:** `/trials/{trialId}`, **Action text:** "Review Request".

---

### 3.2 Tutor accepts trial

| Recipient | Type | Title | Message (example) | Trigger | Channels |
|-----------|------|--------|-------------------|---------|----------|
| **Student/parent** | `trial_accepted` | Trial Session Confirmed | Your trial request with {tutorName} has been approved. Tap to view details and pay. | Tutor accepts trial request | In-app, Push, Email |

**Trigger:** `trial_session_service.dart` → `NotificationHelperService.notifyTrialRequestAccepted`.  
**Action URL:** `/trials/{trialId}/payment`, **Action text:** "Pay Now".

---

### 3.3 Tutor rejects trial

| Recipient | Type | Title | Message (example) | Trigger | Channels |
|-----------|------|--------|-------------------|---------|----------|
| **Student/parent** | `trial_rejected` | ⚠️ Trial Session Declined | `{tutorName} has declined your trial session request.` (+ optional reason) | Tutor rejects trial request | In-app, Push, Email |

**Trigger:** `trial_session_service.dart` → `NotificationHelperService.notifyTrialRequestRejected`.  
**Action URL:** `/trials`, **Action text:** "Find Another Tutor".

---

### 3.4 Student/parent cancels approved trial

| Recipient | Type | Title | Message (example) | Trigger | Channels |
|-----------|------|--------|-------------------|---------|----------|
| **Tutor** | `trial_cancelled` | ⚠️ Trial Session Cancelled | `{studentName} has cancelled the trial session for {subject} scheduled for {date} at {time}.` (+ optional reason) | Student/parent cancels approved trial | In-app, Push, Email |

**Trigger:** `trial_session_service.dart` → `NotificationHelperService.notifyTrialSessionCancelled`.  
**Action URL:** `/trials/{trialId}`.

---

### 3.5 Trial request updated / deleted / modified

| Recipient | Type | Title | Message (example) | Trigger | Channels |
|-----------|------|--------|-------------------|---------|----------|
| **Tutor** | `trial_request_updated` | 🔄 Trial Request Updated | `{studentName} has updated their trial request for {subject}. Please review the changes.` | Student/parent updates pending trial request | In-app, Email |
| **Tutor** | `trial_session_modified` | (session modified) | Session modified (e.g. after missed paid session) | Trial session modified (e.g. reschedule flow) | In-app, Email |
| **Tutor** | `trial_request_deleted` | (request deleted) | Trial request deleted | Student/parent deletes trial request | In-app, Email |

**Trigger:** `trial_session_service.dart` (update/delete/modify flows).

---

## 4. PAYMENT

### 4.1 Recurring payment – success (after student pays)

| Recipient | Type | Title | Message (example) | Trigger | Channels |
|-----------|------|--------|-------------------|---------|----------|
| **Student/parent** | `payment_request_paid` | Payment Confirmed | Your payment has been confirmed. Your sessions are now active! Tap to view booking. | Fapshi webhook confirms recurring payment | In-app, Push, Email |
| **Tutor** | `payment_received` | Payment Received | A student has paid for their booking. Sessions are now active! | Same webhook | In-app, Push (no email) |

**Trigger:** `fapshi_webhook_service.dart` → `NotificationHelperService.notifyPaymentRequestPaid` after successful recurring payment.  
**Action URLs:** Student → `/bookings/{bookingRequestId}`; Tutor → `/tutor/bookings/...`.

---

### 4.2 Recurring payment – failure

| Recipient | Type | Title | Message (example) | Trigger | Channels |
|-----------|------|--------|-------------------|---------|----------|
| **Student/parent** | `payment_request_failed` | ⚠️ Payment Failed | Your payment could not be processed. Reason: {reason}. Please try again. | Fapshi webhook reports payment failure | In-app, Push, Email |

**Trigger:** `fapshi_webhook_service.dart` → `NotificationHelperService.notifyPaymentRequestFailed`.  
**Action URL:** `/payments/{paymentRequestId}`, **Action text:** "Retry Payment".

---

### 4.3 Recurring payment – sessions created (after payment success)

| Recipient | Type | Title | Message (example) | Trigger | Channels |
|-----------|------|--------|-------------------|---------|----------|
| **Student/parent** | `sessions_created` | Sessions Created | `{sessionCount} sessions have been created for your booking with {tutorName}. Sessions are now visible in your Sessions tab!` | Webhook creates individual sessions after payment | In-app, Push, Email |
| **Tutor** | `sessions_created` | Sessions Created | `{sessionCount} sessions have been created for your booking with {studentName}. Sessions are now visible in your Sessions tab!` | Same | In-app, Push (no email) |

**Trigger:** `fapshi_webhook_service.dart` → `NotificationHelperService.notifySessionsCreated` and `notifyTutorSessionsCreated`.  
**Action URLs:** `/sessions`, `/tutor/sessions`.

---

### 4.4 Trial payment – success

| Recipient | Type | Title | Message (example) | Trigger | Channels |
|-----------|------|--------|-------------------|---------|----------|
| **Student/parent** | `trial_payment_completed` | Trial Payment Confirmed | Your trial session payment has been confirmed. Meet link is now available. / Your session is scheduled. | Fapshi webhook confirms trial payment | In-app, Push, Email |
| **Tutor** | `trial_payment_received` | Trial Payment Received | A student has paid for their trial session in {subject}. The session is now scheduled. | Same webhook | In-app, Push (no email) |

**Trigger:** `fapshi_webhook_service.dart` → `NotificationHelperService.notifyTrialPaymentCompleted` and `notifyTrialPaymentReceived`.  
**Action URLs:** Learner → `/trials/{trialSessionId}`; Tutor → `/tutor/trials/{trialSessionId}`.

---

### 4.5 Trial payment – failure

| Recipient | Type | Title | Message (example) | Trigger | Channels |
|-----------|------|--------|-------------------|---------|----------|
| **Student/parent** | `trial_payment_failed` | ⚠️ Trial Payment Failed | Your trial session payment could not be processed. Reason: {reason}. Please try again. | Fapshi webhook reports trial payment failure | In-app, Push, Email |

**Trigger:** `fapshi_webhook_service.dart` → `NotificationHelperService.notifyTrialPaymentFailed`.

---

### 4.6 Tutor session ready (after trial payment)

| Recipient | Type | Title | Message (example) | Trigger | Channels |
|-----------|------|--------|-------------------|---------|----------|
| **Tutor** | `session_ready` | Session Confirmed - Payment Received | Payment received! Your trial/recurring session with {learnerName} for {subject} is scheduled for {date} at {time}. The meeting link is ready / will be available soon. | Trial payment completed and Meet link generated (or scheduled) | In-app, Push, Email |

**Trigger:** `trial_session_service.dart` → `NotificationHelperService.notifyTutorSessionReady` after trial payment completion.  
**Action URL:** `/sessions/{sessionId}`.

---

### 4.7 Payment reminders (scheduled)

| Recipient | Type | Title | Message (example) | Trigger | Channels |
|-----------|------|--------|-------------------|---------|----------|
| **Student/parent** | `payment_reminder` | ⏰ Payment Reminder / Payment Due Tomorrow / 🚨 Payment Due Soon! | Payment due in 2 days / tomorrow / 2 hours for {subject} ({amount} {currency}). | Scheduled (2 days, 1 day, 2 hours before deadline) | In-app, Email (push for 2-hour) |

**Trigger:** `NotificationHelperService.schedulePaymentReminders` (e.g. from trial flow); API or fallback creates reminders.  
**Action URL:** `/payments/...`.

---

### 4.8 Low credits balance

| Recipient | Type | Title | Message (example) | Trigger | Channels |
|-----------|------|--------|-------------------|---------|----------|
| **Student/parent** | `low_credits_balance` | (low credits) | Credits balance low | Credits service detects low balance | In-app, etc. |

**Trigger:** `user_credits_service.dart` → `NotificationHelperService.notifyLowCreditsBalance`.

---

## 5. SESSION REMINDERS & ATTENDING

### 5.1 Session reminders (scheduled)

| Recipient | Type | Title | Message (example) | Trigger | Channels |
|-----------|------|--------|-------------------|---------|----------|
| **Tutor & Student** | (scheduled) | 24h: Session reminder; 1h: Session starting soon; 15min: Join now | Reminders at 24 hours, 1 hour, and 15 minutes before session start | Scheduled by API after payment/session creation | In-app, Push, Email (API) |

**Trigger:** `NotificationHelperService.scheduleSessionReminders` (e.g. from `trial_session_service.dart` and `fapshi_webhook_service.dart` after trial payment). Backend API schedules the three reminders.

---

### 5.2 Session started (join meeting)

| Recipient | Type | Title | Message (example) | Trigger | Channels |
|-----------|------|--------|-------------------|---------|----------|
| **Other party** (tutor or student) | `session_started` | 🎓 Session Started | Your session has started! Join the meeting now: {meetLink} | One party starts the session (e.g. joins video) | In-app, Push, Email |

**Trigger:** `session_lifecycle_service.dart` → `NotificationHelperService.notifySessionStarted` when session is marked started (e.g. Meet link used). Sent to the **other** party (the one not yet in the session).  
**Action URL:** `/sessions/{sessionId}`, **Action text:** "Join Meeting".

---

### 5.3 Session completed

| Recipient | Type | Title | Message (example) | Trigger | Channels |
|-----------|------|--------|-------------------|---------|----------|
| **Student/parent** | `session_completed` | Session Completed | Your session has been completed. Payment of X XAF is due. / Please provide feedback when ready. | Session marked completed in lifecycle | In-app only |

**Trigger:** `session_lifecycle_service.dart` → `_sendSessionCompletedNotification` → `NotificationService.createNotification` (in-app only).  
**Action URL:** Payment due → `/payments/session/{paymentId}` (Pay Now); else `/sessions/{sessionId}/feedback` (Provide Feedback).

---

### 5.4 Session cancelled

| Recipient | Type | Title | Message (example) | Trigger | Channels |
|-----------|------|--------|-------------------|---------|----------|
| **Other party** | `session_cancelled` | ⚠️ Session Cancelled | Tutor/Student has cancelled the session. Reason: {reason} | Session cancelled by one party | In-app only |

**Trigger:** `session_lifecycle_service.dart` → `_sendSessionCancelledNotification` → `NotificationService.createNotification`.  
**Action URL:** `/sessions/{sessionId}`.

---

### 5.5 Feedback reminder (24h after session)

| Recipient | Type | Title | Message (example) | Trigger | Channels |
|-----------|------|--------|-------------------|---------|----------|
| **Student** | `feedback_reminder` | Feedback Reminder | Please provide feedback for your completed session. It helps your tutor improve! | Scheduled 24 hours after session end | In-app (or API-scheduled) |

**Trigger:** `session_lifecycle_service.dart` → `NotificationHelperService.scheduleFeedbackReminder`.  
**Action URL:** `/sessions/{sessionId}/feedback`.

---

### 5.6 Review reminder (24h after session)

| Recipient | Type | Title | Message (example) | Trigger | Channels |
|-----------|------|--------|-------------------|---------|----------|
| **User** (tutor or student) | (review reminder) | Session Completed / Leave Review | Your {trial/recurring} session with {otherPartyName} for {subject} has been completed. Please leave a review! | Scheduled 24h after session (via API) | In-app, Email (NotificationHelperService.notifySessionCompleted used elsewhere) |

**Note:** `NotificationHelperService.notifySessionCompleted` exists and schedules a review reminder via API; session lifecycle currently uses its own in-app `session_completed` above.

---

## 6. TUTOR EARNINGS & PAYOUT

### 6.1 Earnings added to pending balance

| Recipient | Type | Title | Message (example) | Trigger | Channels |
|-----------|------|--------|-------------------|---------|----------|
| **Tutor** | `earnings_added` | Earnings Added | {amount} XAF has been added to your pending balance. It will become active after payment confirmation. | Session payment record created | In-app, Push, Email |

**Trigger:** From payment/session flow (e.g. session payment service).  
**Action URL:** `/earnings`.

---

### 6.2 Payout request (tutor → admin)

| Recipient | Type | Title | Message (example) | Trigger | Channels |
|-----------|------|--------|-------------------|---------|----------|
| **Admin** | (payout request) | Log / in-app | Payout request created for tutor {name} ({amount} XAF) | Tutor requests payout | Log / optional in-app (tutor_payout_service) |

**Trigger:** `tutor_payout_service.dart` → `_notifyAdminOfPayoutRequest` (currently logs; can be extended to create admin notifications).

---

### 6.3 Payout status (admin → tutor)

| Recipient | Type | Title | Message (example) | Trigger | Channels |
|-----------|------|--------|-------------------|---------|----------|
| **Tutor** | `payout_status` | (processing / completed / failed) | Your payout request is being processed / has been completed / failed. | Admin processes payout via API | In-app (Supabase `notifications`) |

**Trigger:** Backend/API updates payout status; `tutor_payout_service.dart` → `_notifyTutorOfPayoutStatus` creates in-app notification.

---

## 7. ADMIN – TUTOR REQUESTS (FIND A TUTOR)

| Recipient | Type | Title | Message (example) | Trigger | Channels |
|-----------|------|--------|-------------------|---------|----------|
| **Admin** | `tutor_request` | 🎓 New Tutor Request | {requesterName} has submitted a new tutor request. Please review and find a suitable tutor. | User submits “find a tutor” request | In-app, Push, Email |
| **User** (student/parent) | `tutor_request_matched` | Tutor Matched | We found a tutor for your request: {tutorName} | Admin matches request with a tutor | In-app, Push, Email |

**Trigger:** From admin/tutor-request flow (e.g. `NotificationHelperService.notifyTutorRequestCreated`, `notifyTutorRequestMatched`).  
**Action URLs:** Admin → `/admin/tutor-requests/{requestId}`; User → request detail.

---

## 8. MODIFICATION REQUESTS (TRIAL / RECURRING)

| Recipient | Type | Title | Message (example) | Trigger | Channels |
|-----------|------|--------|-------------------|---------|----------|
| **Tutor** | `tutor_modification_request` | (modification request) | Student/parent requested a change (e.g. time, date) | Student/parent requests modification | In-app, Email |
| **Student/parent** | `modification_accepted` | (modification accepted) | Tutor accepted your modification request | Tutor accepts modification | In-app, Email |

**Trigger:** `trial_session_service.dart` → `NotificationHelperService.notifyTutorModificationRequest`, `notifyModificationAccepted`.

---

## 9. ABANDONED BOOKING REMINDER

| Recipient | Type | Title | Message (example) | Trigger | Channels |
|-----------|------|--------|-------------------|---------|----------|
| **Student/parent** | `abandoned_booking_reminder` | (reminder) | Reminder to complete or cancel abandoned booking | Abandoned booking logic | In-app, Email |

**Trigger:** `NotificationHelperService.notifyAbandonedBookingReminder`.

---

## 10. QUICK REFERENCE: WHEN A TUTOR IS BOOKED

**Recurring booking:**  
1. **Tutor** gets `booking_request` when student/parent creates the request.  
2. When tutor **accepts**, **student/parent** gets `booking_approved` (with Pay Now link if payment request created).  
3. When student **pays**, **tutor** gets `payment_received` and **both** get `sessions_created`.  
4. **Tutor** can also get `session_ready` (e.g. after trial payment) and `earnings_added` when earnings are recorded.

**Trial booking:**  
1. **Tutor** gets `trial_request` when student/parent requests a trial.  
2. When tutor **accepts**, **student/parent** gets `trial_accepted` (Pay Now).  
3. When student **pays**, **tutor** gets `trial_payment_received` and `session_ready`; **student** gets `trial_payment_completed`.  
4. Session reminders (24h, 1h, 15min) are scheduled for **both**; **session_started** goes to the other party when one joins.

So **yes: when a tutor is booked (recurring or trial), they receive notifications** at request, acceptance, payment, session creation, and session reminders/start/completion as above.

---

## Summary table by role

| Role | Notification types (examples) |
|------|------------------------------|
| **Admin** | New user signup, survey completed, new tutor request, payout request (log/in-app). |
| **Tutor** | Onboarding reminder; booking/trial request; trial accepted/cancelled/updated/modified; payment received; session ready; sessions created; session reminders; session started; earnings added; profile approved/improvement/rejected; modification request; payout status. |
| **Student/Parent** | Booking approved/rejected; trial accepted/rejected; payment confirmed/failed; sessions created; payment reminders; session reminders; session started; session completed; feedback/review reminder; low credits; tutor request matched; modification accepted; abandoned booking reminder. |

All of the above are implemented in `notification_helper_service.dart` (and some in `notification_service.dart` or `session_lifecycle_service.dart`). In-app notifications are always created; push and email depend on the API and per-notification flags.

---

## Limiting factors

| Factor | Impact |
|--------|--------|
| **API dependency for push/email** | Push (FCM) and email are sent via Next.js API. If the API is down or unreachable, only in-app notifications are created. Users get no push/email until they open the app. |
| **Scheduled reminders** | Session reminders (24h, 1h, 15min), payment reminders (2 days, 1 day, 2 hours), feedback/review reminders are scheduled via API. If the API call fails, fallback only logs; no server-side cron means reminders may not fire. |
| **FCM token** | Push requires a valid FCM token stored in `fcm_tokens`. Web needs a service worker; iOS needs APNS. Simulators or missing permission = no push. |
| **Email deliverability** | Email goes through Resend via API. Rate limits, spam filters, or misconfiguration can block or delay delivery. |
| **Single channel emphasis** | In-app is the only guaranteed channel. Users who don’t open the app won’t see anything unless push/email succeeded. |
| **No retry for API send** | If `_sendNotificationViaAPI` fails (network/timeout), we don’t retry. Push/email for that event are lost. |
| **Admin payout notification** | Payout request from tutor currently logs only; no in-app notification to admins unless extended. |

---

## How notifications can be improved

1. **Reduce API dependency**  
   - Option A: Use Supabase Edge Functions or a background job to send push/email from DB (e.g. poll `notifications` or use pg_notify).  
   - Option B: Store “pending push/email” in DB and have a worker/API retry with backoff.

2. **Reliable scheduling**  
   - Move reminder scheduling to a backend (Supabase cron, Edge Function on schedule, or external scheduler) that reads “session start” / “payment due” and creates notifications at the right time.  
   - Keep client call only to “register that reminders are needed”; actual send at 24h/1h/15min (or 2d/1d/2h) server-side.

3. **Retry and observability**  
   - Retry failed API calls (with backoff) for push/email.  
   - Log failures to a table or monitoring; alert on high failure rate.

4. **FCM and permissions**  
   - Ensure token is refreshed and stored after permission grant; re-prompt on iOS if previously denied.  
   - On web, document/service-worker setup for FCM.

5. **Admin payout alerts**  
   - Create in-app (and optional push/email) notifications to admins when a tutor requests payout, using the same pattern as other admin notifications.

6. **User preferences**  
   - Use notification preferences (already have `notification_preferences_screen`) to gate email/push per type so we don’t send unwanted channels.

7. **Deep links and action URLs**  
   - Ensure all `actionUrl` values are handled by app_links/deep linking so tapping a notification opens the right screen (e.g. `/bookings/requests/:id`, `/trials/:id`).
