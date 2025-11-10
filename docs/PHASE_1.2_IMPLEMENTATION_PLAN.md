# Phase 1.2: Trial Session Flow Implementation Plan

**Status:** Planning Complete - Ready for Implementation  
**Payment Provider:** Fapshi  
**Video Platform:** Google Meet  
**Security Focus:** Prevent tutor-student bypass

---

## Overview

Complete trial session flow with:
1. Fapshi payment integration (direct-pay)
2. Google Meet link generation with security measures
3. Payment gate before Meet link access
4. Fathom AI auto-join and monitoring
5. Automatic summary distribution to all parties
6. Action items extraction and assignment system
7. Admin flags for irregular behavior detection
8. Post-session conversion to recurring booking
9. Webhook integration for async payment and meeting updates

---

## 1. Fapshi Payment Service Implementation

### 1.1 Core Fapshi Service

**File:** `lib/features/payment/services/fapshi_service.dart`

**Responsibilities:**
- Direct payment request initiation
- Payment status polling
- Error handling and retries
- Environment configuration (sandbox/live)

**Key Methods:**
```dart
class FapshiService {
  // Initiate direct payment
  static Future<FapshiPaymentResponse> initiateDirectPayment({
    required int amount,
    required String phone,
    String? medium, // 'mobile money' or 'orange money'
    String? name,
    String? email,
    String? userId,
    required String externalId, // trial_session_id or booking_id
    String? message,
  });

  // Get payment status
  static Future<FapshiPaymentStatus> getPaymentStatus(String transId);

  // Poll payment status (with retry logic)
  static Future<FapshiPaymentStatus> pollPaymentStatus(
    String transId, {
    int maxAttempts = 40,
    Duration interval = const Duration(seconds: 3),
  });
}
```

**Configuration:**
```dart
class FapshiConfig {
  static String get baseUrl => _isProduction 
    ? 'https://live.fapshi.com'
    : 'https://sandbox.fapshi.com';
  
  static String get collectionApiUser => _isProduction
    ? 'your-fapshi-collection-api-user-here'
    : 'your-fapshi-sandbox-api-user-here';
  
  static String get collectionApiKey => _isProduction
    ? 'your-fapshi-collection-api-key-here'
    : 'your-fapshi-sandbox-api-key-here';
  
  static String get disburseApiUser => _isProduction
    ? 'your-fapshi-disburse-api-user-here'
    : 'your-fapshi-sandbox-api-user-here';
  
  static String get disburseApiKey => _isProduction
    ? 'your-fapshi-disburse-api-key-here'
    : 'your-fapshi-sandbox-api-key-here';
}
```

### 1.2 Payment Models

**File:** `lib/features/payment/models/fapshi_transaction_model.dart`

```dart
class FapshiPaymentResponse {
  final String message;
  final String transId;
  final DateTime dateInitiated;
}

class FapshiPaymentStatus {
  final String transId;
  final String status; // 'PENDING', 'SUCCESSFUL', 'FAILED'
  final int amount;
  final DateTime dateInitiated;
  final DateTime? dateCompleted;
}
```

### 1.3 High-Level Payment Service

**File:** `lib/features/payment/services/payment_service.dart`

**Abstraction layer** that uses FapshiService internally:

```dart
class PaymentService {
  // Process trial session payment
  static Future<PaymentResult> processTrialPayment({
    required String trialSessionId,
    required String phoneNumber,
    required double amount,
  });

  // Process booking payment
  static Future<PaymentResult> processBookingPayment({
    required String bookingRequestId,
    required String phoneNumber,
    required double amount,
    required String paymentPlan,
  });

  // Verify payment status
  static Future<bool> verifyPayment(String transactionId);
}
```

---

## 2. Google Meet Integration with Security

### 2.1 Meet Service

**File:** `lib/features/sessions/services/meet_service.dart`

**Security Measures:**

1. **Payment Gate:**
   - Meet link only generated when `payment_status = 'paid'`
   - Link stored in database, never sent via external channels
   - Both parties see link in-app at same time

2. **Link Visibility Control:**
   - Trial sessions: Link visible only after payment
   - Recurring sessions: Link visible after first payment
   - Links expire after session time + 30min buffer

3. **In-App Meeting:**
   - Embed Meet in Flutter WebView (when possible)
   - Show "Join Meeting" button only after payment verified
   - Track join times for both parties
   - Display session controls in-app

**Implementation:**
```dart
class MeetService {
  // Generate Meet link for trial session
  static Future<String> generateTrialMeetLink({
    required String trialSessionId,
    required String tutorId,
    required String studentId,
    required DateTime scheduledDate,
    required String scheduledTime,
    required int durationMinutes,
  });

  // Generate permanent Meet link for recurring session
  static Future<String> generateRecurringMeetLink({
    required String recurringSessionId,
    required String tutorId,
    required String studentId,
  });

  // Verify Meet link access (payment check)
  static Future<bool> canAccessMeetLink(String sessionId, String sessionType);
}
```

### 2.2 Google Calendar Integration

**File:** `lib/core/services/google_calendar_service.dart`

**Purpose:**
- Create calendar events for sessions
- Auto-generate Meet links via Calendar API
- Add PrepSkul AI as required attendee (triggers Fathom auto-join)
- Sync cancellations

**Implementation:**
```dart
class GoogleCalendarService {
  // Create calendar event with Meet link
  static Future<CalendarEvent> createSessionEvent({
    required String title,
    required DateTime startTime,
    required int durationMinutes,
    required List<String> attendeeEmails, // tutor, student, prepskul-ai
    String? description,
  }) async {
    // 1. Create event with Google Calendar API
    // 2. Auto-generate Meet link
    // 3. Add PrepSkul AI email (prepskul-ai@prepskul.com) as attendee
    //    This triggers Fathom to auto-join the meeting
    // 4. Return event with Meet link and calendar_event_id
  }

  // Cancel calendar event
  static Future<void> cancelEvent(String eventId);
}
```

**Required Setup:**
- Google Cloud Project with Calendar API enabled
- Service account for PrepSkul AI
- OAuth credentials for calendar access
- Environment variables for credentials

**Fathom Auto-Join:**
- When `prepskul-ai@prepskul.com` is added as attendee, Fathom automatically:
  - Joins the meeting when it starts
  - Records and transcribes the session
  - Generates summary and action items
  - Sends webhook when content is ready

### 2.3 Database Schema Updates

**Migration:** `012_add_meet_calendar_fields.sql`

```sql
-- Trial sessions
ALTER TABLE trial_sessions 
ADD COLUMN IF NOT EXISTS meet_link TEXT,
ADD COLUMN IF NOT EXISTS calendar_event_id TEXT,
ADD COLUMN IF NOT EXISTS fapshi_trans_id TEXT,
ADD COLUMN IF NOT EXISTS payment_initiated_at TIMESTAMPTZ,
ADD COLUMN IF NOT EXISTS tutor_joined_at TIMESTAMPTZ,
ADD COLUMN IF NOT EXISTS student_joined_at TIMESTAMPTZ,
ADD COLUMN IF NOT EXISTS meet_link_generated_at TIMESTAMPTZ;

-- Recurring sessions
ALTER TABLE recurring_sessions 
ADD COLUMN IF NOT EXISTS meet_link TEXT,
ADD COLUMN IF NOT EXISTS calendar_event_id TEXT;

-- Indexes for performance
CREATE INDEX IF NOT EXISTS idx_trial_sessions_trans_id ON trial_sessions(fapshi_trans_id);
CREATE INDEX IF NOT EXISTS idx_trial_sessions_payment_status ON trial_sessions(payment_status);
```

---

## 3. Payment Gate Flow

### 3.1 Payment Screen

**File:** `lib/features/booking/screens/trial_payment_screen.dart`

**UI Flow:**
1. Show trial session details (tutor, subject, date, time, fee)
2. Phone number input (pre-filled from profile if available)
3. "Pay Now" button → Initiate Fapshi payment
4. Payment processing screen:
   - Loading indicator
   - "Processing payment..." message
   - Poll status every 3 seconds
   - Max 2 minutes timeout
5. Success screen:
   - "Payment successful!"
   - "Generating session link..."
   - Auto-navigate to session detail
6. Failure screen:
   - Error message
   - "Retry Payment" button
   - "Cancel" option

### 3.2 Updated Trial Session Flow

**File:** `lib/features/booking/services/trial_session_service.dart`

**Modified Methods:**
```dart
// After tutor approves, payment required
static Future<void> initiatePayment(String trialSessionId, String phoneNumber) async {
  // 1. Get trial session
  final trial = await getTrialSessionById(trialSessionId);
  
  // 2. Verify status is 'approved' and payment is 'unpaid'
  if (trial.status != 'approved' || trial.paymentStatus != 'unpaid') {
    throw Exception('Trial session not ready for payment');
  }
  
  // 3. Initiate Fapshi payment
  final paymentResponse = await FapshiService.initiateDirectPayment(
    amount: trial.trialFee.toInt(),
    phone: phoneNumber,
    externalId: trialSessionId,
    userId: trial.learnerId,
    message: 'Trial session fee - ${trial.subject}',
  );
  
  // 4. Update trial session with transId
  await _supabase
    .from('trial_sessions')
    .update({
      'fapshi_trans_id': paymentResponse.transId,
      'payment_initiated_at': DateTime.now().toIso8601String(),
    })
    .eq('id', trialSessionId);
  
  // 5. Poll payment status
  final status = await FapshiService.pollPaymentStatus(paymentResponse.transId);
  
  // 6. On success, generate Meet link
  if (status.status == 'SUCCESSFUL') {
    await _completePaymentAndGenerateMeet(trialSessionId);
  }
}

static Future<void> _completePaymentAndGenerateMeet(String trialSessionId) async {
  // 1. Update payment status
  await _supabase
    .from('trial_sessions')
    .update({
      'payment_status': 'paid',
      'status': 'scheduled',
    })
    .eq('id', trialSessionId);
  
  // 2. Generate Meet link
  final trial = await getTrialSessionById(trialSessionId);
  final meetLink = await MeetService.generateTrialMeetLink(
    trialSessionId: trialSessionId,
    tutorId: trial.tutorId,
    studentId: trial.learnerId,
    scheduledDate: trial.scheduledDate,
    scheduledTime: trial.scheduledTime,
    durationMinutes: trial.durationMinutes,
  );
  
  // 3. Create calendar event
  final calendarEvent = await GoogleCalendarService.createSessionEvent(
    title: 'Trial Session: ${trial.subject}',
    startTime: DateTime.parse('${trial.scheduledDate} ${trial.scheduledTime}'),
    durationMinutes: trial.durationMinutes,
    attendeeEmails: [
      trial.tutorEmail,
      trial.learnerEmail,
      'prepskul-ai@prepskul.com', // PrepSkul AI account
    ],
  );
  
  // 4. Update trial session with Meet link and calendar event
  await _supabase
    .from('trial_sessions')
    .update({
      'meet_link': meetLink,
      'calendar_event_id': calendarEvent.id,
      'meet_link_generated_at': DateTime.now().toIso8601String(),
    })
    .eq('id', trialSessionId);
  
  // 5. Send notifications to both parties
  await NotificationService.createNotification(
    userId: trial.tutorId,
    type: 'trial_scheduled',
    title: 'Trial Session Scheduled',
    message: 'Your trial session with ${trial.learnerName} is ready. Payment received.',
    data: {'trial_session_id': trialSessionId, 'meet_link': meetLink},
  );
  
  await NotificationService.createNotification(
    userId: trial.learnerId,
    type: 'trial_scheduled',
    title: 'Trial Session Ready',
    message: 'Your trial session with ${trial.tutorName} is scheduled. Join now!',
    data: {'trial_session_id': trialSessionId, 'meet_link': meetLink},
  );
}
```

---

## 4. Webhook Integration

### 4.1 Webhook Endpoint (Next.js)

**File:** `PrepSkul_Web/app/api/webhooks/fapshi/route.ts`

**Purpose:**
- Receive payment status updates from Fapshi
- Update trial_sessions.payment_status
- Trigger Meet link generation on success
- Send notifications

**Implementation:**
```typescript
export async function POST(request: Request) {
  try {
    const payload = await request.json();
    
    // Verify webhook (if Fapshi provides signature)
    // const isValid = verifyWebhookSignature(payload, request.headers);
    // if (!isValid) return new Response('Unauthorized', { status: 401 });
    
    const { event, transId, status, externalId, userId } = payload;
    
    // Find trial session by externalId (trial_session_id)
    if (externalId && externalId.startsWith('trial_')) {
      const trialSessionId = externalId.replace('trial_', '');
      
      if (status === 'SUCCESSFUL') {
        // Update payment status
        await supabase
          .from('trial_sessions')
          .update({
            payment_status: 'paid',
            status: 'scheduled',
            fapshi_trans_id: transId,
          })
          .eq('id', trialSessionId);
        
        // Trigger Meet link generation (async)
        // This should call a service that generates Meet link
        await generateMeetLinkForTrial(trialSessionId);
      } else if (status === 'FAILED') {
        await supabase
          .from('trial_sessions')
          .update({
            payment_status: 'unpaid',
          })
          .eq('id', trialSessionId);
      }
    }
    
    return Response.json({ success: true });
  } catch (error) {
    console.error('Webhook error:', error);
    return new Response('Internal Server Error', { status: 500 });
  }
}
```

### 4.2 Webhook Security

- Verify webhook signature (if Fapshi provides)
- Rate limiting (max requests per minute)
- Idempotency (handle duplicate events)
- Log all webhook events for audit

---

## 4. Fathom AI Integration & Monitoring

### 4.1 Fathom Service Implementation

**File:** `lib/features/sessions/services/fathom_service.dart` - NEW

**Purpose:**
- Fetch meeting data from Fathom API
- Retrieve transcripts and summaries
- Process action items
- Handle webhook events

**Key Methods:**
```dart
class FathomService {
  // List meetings for PrepSkul AI
  static Future<List<FathomMeeting>> getPrepSkulSessions({
    DateTime? createdAfter,
    DateTime? createdBefore,
    List<String>? calendarInvitees,
  });

  // Get meeting by recording ID
  static Future<FathomMeeting> getMeeting(int recordingId);

  // Get summary
  static Future<FathomSummary> getSummary(int recordingId);

  // Get transcript
  static Future<FathomTranscript> getTranscript(int recordingId);
}
```

**Authentication:**
- API key in header: `X-Api-Key: YOUR_API_KEY`
- Base URL: `https://api.fathom.ai/external/v1`

### 4.2 Auto-Join Setup

**How It Works:**
1. When creating calendar event, add `prepskul-ai@prepskul.com` as attendee
2. Fathom monitors PrepSkul AI's calendar
3. When meeting starts, Fathom automatically joins
4. Fathom records and transcribes automatically
5. After meeting ends, Fathom generates summary and action items
6. Webhook triggers → `new_meeting_content_ready`

**Setup Required:**
- Fathom account with API key
- PrepSkul AI email (`prepskul-ai@prepskul.com`) connected to Fathom
- Google Calendar OAuth authorized for PrepSkul AI account
- Fathom webhook configured

### 4.3 Summary Distribution

**File:** `lib/features/sessions/services/fathom_summary_service.dart` - NEW

**Flow:**
1. Webhook receives `new_meeting_content_ready` event
2. Fetch summary from Fathom API using `recording_id`
3. Store in `session_transcripts` table
4. Send email to:
   - **Tutor** - "Session Summary: [Title]"
   - **Student/Parent** - "Your Session Summary: [Title]"
5. Create in-app notifications for all parties
6. Display summary in app

**Email Format:**
- Tutor: Includes full summary, action items, student progress notes
- Student/Parent: Includes summary, assignments, next steps
- Admin: Includes summary + flags (if any)

### 4.4 Action Items & Assignments

**File:** `lib/features/sessions/services/assignment_service.dart` - NEW

**Flow:**
1. Extract action items from Fathom meeting response
2. Create assignments in `assignments` table
3. Assign to students based on Fathom's assignee detection
4. Set due dates (default: next session date or 7 days)
5. Send notifications to students
6. Track completion

**Action Item Structure:**
```json
{
  "description": "Complete exercises 1-10 from chapter 3",
  "assignee": {
    "name": "Student Name",
    "email": "student@example.com"
  },
  "recording_timestamp": "00:10:45",
  "recording_playback_url": "https://fathom.video/xyz123#t=645"
}
```

**Assignment Features:**
- Link to specific moment in recording
- Due date tracking
- Completion status
- Tutor can view all assignments for their students
- Students see assignments in their dashboard

### 4.5 Admin Flags & Monitoring

**File:** `lib/features/admin/services/session_monitoring_service.dart` - NEW

**Flag Types:**
1. **Inappropriate Language** (high severity)
   - Profanity, harassment, inappropriate content
   - Triggers immediate admin notification

2. **Payment Bypass Attempt** (critical severity)
   - Mentions of paying outside platform
   - Sharing contact info for direct payment
   - Triggers immediate admin action

3. **External Contact Attempt** (high severity)
   - Sharing WhatsApp/phone outside platform
   - Attempting to move communication off-platform
   - Triggers admin review

4. **No-Show** (medium severity)
   - One or more participants didn't join
   - Session ended immediately

5. **Short Session** (low severity)
   - Session ended unusually early (< 10 minutes for 30min session, < 20 for 60min)

6. **Content Violation** (medium severity)
   - Off-topic content
   - Inappropriate subject matter

**Implementation:**
```dart
class SessionMonitoringService {
  // Analyze transcript for flags
  static Future<List<AdminFlag>> analyzeSessionForFlags({
    required String transcript,
    required String summary,
    required String sessionId,
  }) async {
    final flags = <AdminFlag>[];
    
    // Keyword detection for each flag type
    if (_detectsPaymentBypass(transcript)) {
      flags.add(AdminFlag(
        type: 'payment_bypass_attempt',
        severity: 'critical',
        description: 'Possible attempt to bypass payment system',
      ));
    }
    
    // ... other flag detections
    
    // Store flags and notify admins
    if (flags.isNotEmpty) {
      await _storeFlags(flags);
      await _notifyAdmins(flags);
    }
    
    return flags;
  }
}
```

**Admin Dashboard:**
- View all flags with severity indicators
- Filter by type, severity, resolved status
- View transcript excerpt and Fathom playback link
- Resolve flags with notes
- Export flag reports

### 4.6 Fathom Webhook Handler

**File:** `PrepSkul_Web/app/api/webhooks/fathom/route.ts` - NEW

**Complete Flow:**
```typescript
export async function POST(request: Request) {
  const payload = await request.json();
  
  if (payload.event === 'new_meeting_content_ready') {
    const { recording_id, calendar_invitees, meeting_title } = payload;
    
    // 1. Find session by calendar invitees
    const session = await findSessionByEmails(calendar_invitees);
    
    // 2. Fetch summary and transcript from Fathom
    const summary = await fetchFathomSummary(recording_id);
    const transcript = await fetchFathomTranscript(recording_id);
    
    // 3. Store in database
    await storeSessionTranscript({
      session_id: session.id,
      session_type: session.type,
      recording_id,
      transcript: transcript.transcript,
      summary: summary.summary.markdown_formatted,
      fathom_url: payload.url,
    });
    
    // 4. Extract and create assignments from action items
    if (payload.action_items && payload.action_items.length > 0) {
      await AssignmentService.createFromFathomActionItems(
        sessionId: session.id,
        actionItems: payload.action_items,
      );
    }
    
    // 5. Analyze for admin flags
    const flags = await SessionMonitoringService.analyzeSessionForFlags(
      transcript: JSON.stringify(transcript.transcript),
      summary: summary.summary.markdown_formatted,
      sessionId: session.id,
    );
    
    // 6. Send summaries to all participants
    await FathomSummaryService.sendSummaryToParticipants(
      recordingId: recording_id,
      tutorEmail: session.tutorEmail,
      studentEmail: session.studentEmail,
      parentEmail: session.parentEmail,
      summary: summary.summary.markdown_formatted,
      meetingTitle: meeting_title,
    );
    
    // 7. Notify admins if critical flags
    if (flags.any((f) => f.severity === 'critical')) {
      await NotificationService.notifyAdmins(
        type: 'critical_session_flag',
        title: 'Critical Flag Detected',
        message: 'Critical flag in session requires immediate attention',
        data: { session_id: session.id, flags },
      );
    }
  }
  
  return Response.json({ success: true });
}
```

---

## 5. Post-Session Conversion

### 5.1 Conversion Screen

**File:** `lib/features/booking/screens/post_trial_conversion_screen.dart`

**Trigger:**
- After trial session status = 'completed'
- Show conversion prompt (optional, not forced)

**UI:**
- "How was your trial session?" feedback
- "Would you like to continue with this tutor?" prompt
- "Yes, Book Regular Sessions" button
- "Not Yet" button (allows multiple trials)

**Flow:**
1. Student completes trial → Status: 'completed'
2. Show conversion screen (optional)
3. If student chooses to convert:
   - Navigate to booking flow
   - Pre-fill: tutor, subject, location preference
   - Allow schedule selection
   - Create booking request
4. Mark trial as `converted_to_recurring = true`

### 5.2 Conversion Service

**File:** `lib/features/booking/services/trial_conversion_service.dart`

```dart
class TrialConversionService {
  // Convert trial to booking request
  static Future<String> convertTrialToBooking({
    required String trialSessionId,
    required int frequency,
    required List<String> days,
    required Map<String, String> times,
    required String paymentPlan,
  }) async {
    // 1. Get trial session
    final trial = await TrialSessionService.getTrialSessionById(trialSessionId);
    
    // 2. Create booking request with trial data
    final bookingRequestId = await BookingService.createBookingRequest(
      tutorId: trial.tutorId,
      frequency: frequency,
      days: days,
      times: times,
      location: trial.location,
      address: trial.address,
      locationDescription: trial.locationDescription,
      paymentPlan: paymentPlan,
      monthlyTotal: _calculateMonthlyTotal(frequency, days, times, trial.tutorPrice),
    );
    
    // 3. Mark trial as converted
    await TrialSessionService.markAsConverted(trialSessionId, bookingRequestId);
    
    // 4. Send notification to tutor
    await NotificationService.createNotification(
      userId: trial.tutorId,
      type: 'trial_converted',
      title: 'Trial Converted to Booking',
      message: '${trial.learnerName} wants to continue with regular sessions',
      data: {'booking_request_id': bookingRequestId},
    );
    
    return bookingRequestId;
  }
}
```

### 5.3 In-App Messaging for Conversion

**If messaging works seamlessly:**
- Send conversion prompt in chat after session
- Tutor can also initiate conversion discussion
- Smooth UX with contextual prompts

**If messaging not ready:**
- Show conversion screen as separate step
- Still maintain good UX with clear CTAs

---

## 6. Security Checklist

### Prevent Tutor-Student Bypass

✅ **Meet Links:**
- [ ] Links only visible after payment verified
- [ ] Links stored in database, not external channels
- [ ] Links expire after session time
- [ ] Unique links per session (trial) or pair (recurring)

✅ **Payment Verification:**
- [ ] Payment status checked before Meet link generation
- [ ] Webhook verification for payment updates
- [ ] Transaction reconciliation with externalId

✅ **AI Monitoring:**
- [ ] PrepSkul AI joins all sessions automatically
- [ ] AI visible in participant list
- [ ] Session transcripts stored
- [ ] Suspicious patterns flagged

✅ **Access Control:**
- [ ] Meet link access verified in-app
- [ ] Join times tracked
- [ ] Session duration verified
- [ ] No-show detection

---

## 7. Testing Checklist

### Payment Flow
- [ ] Trial booking → Tutor approval → Payment screen
- [ ] Payment initiation → Fapshi API call
- [ ] Payment polling → Status updates
- [ ] Payment success → Meet link generation
- [ ] Payment failure → Error handling → Retry
- [ ] Webhook → Payment status update

### Meet Link Generation
- [ ] Meet link only after payment
- [ ] Calendar event creation
- [ ] PrepSkul AI added as attendee
- [ ] Link expiration after session
- [ ] Access control verification

### Fathom Integration
- [ ] Fathom auto-joins via calendar invite
- [ ] Webhook receives meeting content ready
- [ ] Summary fetched and stored
- [ ] Summaries sent to tutor, student, parent
- [ ] Action items extracted and assigned
- [ ] Admin flags detected and stored
- [ ] Admin notifications for critical flags

### Post-Session Conversion
- [ ] Conversion prompt after completed trial
- [ ] Pre-filled booking form
- [ ] Booking request creation
- [ ] Trial marked as converted

---

## 8. Environment Variables

```env
# Fapshi Configuration
FAPSHI_ENVIRONMENT=sandbox  # or 'live'
FAPSHI_COLLECTION_API_USER_LIVE=your-fapshi-collection-api-user-here
FAPSHI_COLLECTION_API_KEY_LIVE=your-fapshi-collection-api-key-here
FAPSHI_DISBURSE_API_USER_LIVE=your-fapshi-disburse-api-user-here
FAPSHI_DISBURSE_API_KEY_LIVE=your-fapshi-disburse-api-key-here
FAPSHI_SANDBOX_API_USER=your-fapshi-sandbox-api-user-here
FAPSHI_SANDBOX_API_KEY=your-fapshi-sandbox-api-key-here

# Google Calendar API
GOOGLE_CALENDAR_CLIENT_ID=your_client_id
GOOGLE_CALENDAR_CLIENT_SECRET=your_client_secret
GOOGLE_CALENDAR_SERVICE_ACCOUNT_EMAIL=prepskul-ai@prepskul.iam.gserviceaccount.com
GOOGLE_CALENDAR_PRIVATE_KEY=your_private_key

# PrepSkul AI Account (for Fathom)
PREPSKUL_AI_EMAIL=prepskul-ai@prepskul.com
PREPSKUL_AI_NAME=PrepSkul AI

# Fathom API
FATHOM_API_KEY=your_fathom_api_key
FATHOM_WEBHOOK_SECRET=your_webhook_secret_if_provided

# Admin Email for Flags
ADMIN_EMAIL=admin@prepskul.com
```

---

## 9. Implementation Order

### Week 1: Payment Integration
1. Create Fapshi service and models
2. Implement payment screen UI
3. Add payment gate to trial flow
4. Test payment flow end-to-end

### Week 2: Google Meet & Calendar Integration
1. Set up Google Calendar API
2. Implement Meet link generation
3. Add calendar event creation with PrepSkul AI as attendee
4. Test Meet link access control
5. Verify Fathom auto-join via calendar

### Week 3: Fathom Integration & Webhooks
1. Set up Fathom account and API key
2. Connect PrepSkul AI email to Fathom
3. Implement Fathom service for fetching data
4. Create Fathom webhook endpoint
5. Test webhook with sample events
6. Implement summary distribution to all parties

### Week 4: Action Items & Admin Flags
1. Extract action items from Fathom
2. Create assignment system
3. Implement admin flag detection
4. Set up admin notifications
5. Test complete flow end-to-end

### Week 5: Post-Session Conversion & Polish
1. Create conversion screen
2. Implement conversion service
3. Test conversion flow
4. Polish UX and error handling

---

## 10. Questions & Clarifications Needed

1. **Google Calendar Setup:**
   - Do you have Google Cloud Project set up?
   - Service account credentials ready?
   - PrepSkul AI Gmail account created?

2. **Fathom AI Integration:**
   - Do you have Fathom account created?
   - API key generated?
   - PrepSkul AI email (`prepskul-ai@prepskul.com`) connected to Fathom?
   - Google Calendar OAuth authorized for PrepSkul AI account?
   - Webhook endpoint configured?

3. **In-App Messaging:**
   - Is messaging system ready for post-session conversion?
   - Or should we use separate conversion screen for now?

4. **Direct Pay Activation:**
   - Have you contacted Fapshi support to activate direct-pay in live mode?
   - Or should we test with sandbox only for now?

---

**Document Version:** 1.0  
**Created:** January 2025  
**Status:** Ready for Implementation

