 # Fathom AI API Documentation

**Purpose:** Complete reference for integrating Fathom AI meeting intelligence in PrepSkul app  
**Last Updated:** January 2025  
**Status:** Ready for Implementation

---

## Table of Contents

1. [Overview](#overview)
2. [Authentication](#authentication)
3. [How Fathom Joins Meetings](#how-fathom-joins-meetings)
4. [API Endpoints](#api-endpoints)
5. [Webhook Integration](#webhook-integration)
6. [Summary & Transcript Distribution](#summary--transcript-distribution)
7. [Action Items & Assignments](#action-items--assignments)
8. [Admin Flags & Monitoring](#admin-flags--monitoring)
9. [Rate Limiting](#rate-limiting)
10. [Limitations & Challenges](#limitations--challenges)
11. [Is Fathom Good Enough?](#is-fathom-good-enough)
12. [Implementation Guide](#implementation-guide)

---

## Overview

Fathom AI automatically joins meetings, records them, and provides:
- **Real-time transcripts** with speaker identification
- **AI-generated summaries** (markdown formatted)
- **Action items** with assignees
- **Meeting insights** and key points

**Key Capabilities:**
- ✅ Auto-joins Google Meet, Zoom, Microsoft Teams via calendar invite
- ✅ Records and transcribes automatically
- ✅ Generates summaries and action items
- ✅ Webhooks for real-time notifications
- ✅ API access to all meeting data

**Reference:** [Fathom API Documentation](https://developers.fathom.ai/api-overview)

---

## Authentication

Fathom supports two authentication methods:
1. **API Key Authentication** - For direct API calls
2. **OAuth 2.0** - For calendar integration and user authorization

### API Key Authentication

All Fathom API requests require an **API key** in the header:

```http
X-Api-Key: YOUR_API_KEY
```

### Getting Your API Key

1. Log into Fathom dashboard
2. Go to **Settings** → **API Access**
3. Generate a new API key
4. **Store securely** - API key acts as password

⚠️ **Security:**
- Never commit API keys to Git
- Store in environment variables
- Rotate keys regularly
- Use different keys for development/production

### OAuth 2.0 Authentication

**Purpose:** OAuth is required for:
- Calendar integration (auto-join meetings)
- Accessing meetings from connected calendars
- User authorization flow

**PrepSkul App Credentials:**

**Development Environment:**
```
Client ID: [REDACTED - Get from Fathom Dashboard]
Client Secret: [REDACTED - Get from Fathom Dashboard]
Webhook Secret: [REDACTED - Get from Fathom Dashboard]
Authorize Link: https://fathom.video/external/v1/oauth2/authorize?client_id={YOUR_CLIENT_ID}&redirect_uri={redirect_uri}&response_type=code&scope=public_api&state={state}
```

**Production Environment:**
```
Client ID: [REDACTED - Get from Fathom Dashboard]
Client Secret: [REDACTED - Get from Fathom Dashboard]
Webhook Secret: [REDACTED - Get from Fathom Dashboard]
Authorize Link: https://fathom.video/external/v1/oauth2/authorize?client_id={YOUR_CLIENT_ID}&redirect_uri={redirect_uri}&response_type=code&scope=public_api&state={state}
```

**Redirect URLs Required:**

⚠️ **Important:** Fathom **does NOT accept**:
- ❌ `http://` links (HTTPS required)
- ❌ `localhost` addresses
- ❌ Private/internal URLs

**Add these HTTPS redirect URLs to your Fathom app settings:**

**Development:**
- `https://app.prepskul.com/auth/fathom/callback`
- `https://app.prepskul.com/`

**Production:**
- `https://app.prepskul.com/auth/fathom/callback`
- `https://app.prepskul.com/`
- `https://www.prepskul.com/auth/fathom/callback` (if needed)

**Mobile App Redirect URLs:**

⚠️ **Fathom does NOT accept custom URL schemes** (e.g., `prepskul://`)

**Solution: Use HTTPS web app URLs for all platforms:**

**For Mobile Apps (iOS & Android):**
- `https://app.prepskul.com/auth/fathom/callback`
- `https://app.prepskul.com/`

**How It Works:**
1. Mobile app initiates OAuth flow
2. Redirects to Fathom authorization page
3. After authorization, Fathom redirects to `https://app.prepskul.com/auth/fathom/callback`
4. Web app handles OAuth callback and exchanges code for token
5. Web app can then deep link back to mobile app with token (optional)
6. Or mobile app can use web app for OAuth completion

**Key Point:** Since meetings are on Google Meet (works on mobile browsers) and you have a web app, mobile users can:
- Access web app at `app.prepskul.com` on mobile browser
- Join Google Meet sessions from mobile
- Fathom joins automatically via calendar invite (device-independent)
- All calendar operations work automatically regardless of user's device

⚠️ **App Status:** Currently **UNVERIFIED**
- Users will see a warning when connecting your app
- **Verification Requirements:**
  - ✅ Requires **production usage** with real active users
  - ❌ Development/testing does NOT count toward verification
  - ✅ Request verification once you have sufficient active users in production
  - ✅ Update app details in Fathom dashboard (icon, description, company URL)
- **Recommendation:** Start with unverified status, request verification after launch with real users

### Base URL

```
https://api.fathom.ai/external/v1
```

---

## How Fathom Joins Meetings

### Calendar-Based Auto-Join

Fathom **automatically joins meetings** when:

1. **PrepSkul AI email is added as attendee** to Google Calendar event
2. Meeting link is a **Google Meet, Zoom, or Microsoft Teams** link
3. Fathom account is **connected to the calendar** (via OAuth)

### Setup Process

1. **Create PrepSkul Virtual Assistant Gmail Account:**
   - Email: `prepskul-va@prepskul.com` (or `prepskul-ai@prepskul.com`)
   - **Naming Decision:** Use "Virtual Assistant" instead of "AI" for:
     - Better trust-building with parents, tutors, investors
     - More professional, human-like perception
     - Less intimidating than "AI"
     - Can be shortened to "PrepSkul VA" in UI
   - Connect Fathom account to this email

2. **OAuth Calendar Integration:**
   - Authorize Fathom to access PrepSkul VA's Google Calendar
   - Fathom will monitor calendar for meetings

3. **Add to Calendar Events:**
   - When creating session calendar events, add `prepskul-va@prepskul.com` as attendee
   - Fathom automatically joins when meeting starts
   - **Note:** Only ONE meeting at a time (see concurrent meetings limitation)

### Behavior

- **Silent Participation:** Fathom joins as a participant (visible in participant list)
- **Automatic Recording:** Starts recording when meeting begins
- **Auto-Transcription:** Generates transcript in real-time
- **Post-Meeting Summary:** Generates summary after meeting ends

**Reference:** [Fathom Integrations](https://www.fathom.ai/integrations)

---

## API Endpoints

### 1. List Meetings

**Endpoint:** `GET /meetings`

**Purpose:** Retrieve all meetings with optional filters

**Authentication:**
```http
X-Api-Key: YOUR_API_KEY
```

**Query Parameters:**
```
calendar_invitees[]: string[] - Filter by attendee emails
calendar_invitees_domains[]: string[] - Filter by company domains
created_after: string - Filter meetings created after timestamp
created_before: string - Filter meetings created before timestamp
include_transcript: boolean - Include transcript in response (default: false)
include_summary: boolean - Include summary in response (default: false)
include_action_items: boolean - Include action items (default: false)
cursor: string - Pagination cursor
```

**Example Request:**
```bash
curl --request GET \
  --url 'https://api.fathom.ai/external/v1/meetings?calendar_invitees[]=prepskul-ai@prepskul.com&include_transcript=true&include_summary=true&include_action_items=true' \
  --header 'X-Api-Key: YOUR_API_KEY'
```

**Success Response (200 OK):**
```json
{
  "limit": 1,
  "next_cursor": "eyJwYWdlX251bSI6Mn0=",
  "items": [
    {
      "title": "Trial Session: Mathematics",
      "meeting_title": "Trial Session: Mathematics",
      "recording_id": 123456789,
      "url": "https://fathom.video/xyz123",
      "share_url": "https://fathom.video/share/xyz123",
      "created_at": "2025-01-25T16:01:30Z",
      "scheduled_start_time": "2025-01-25T16:00:00Z",
      "scheduled_end_time": "2025-01-25T17:00:00Z",
      "recording_start_time": "2025-01-25T16:01:12Z",
      "recording_end_time": "2025-01-25T17:00:55Z",
      "transcript": [
        {
          "speaker": {
            "display_name": "Tutor Name",
            "matched_calendar_invitee_email": "tutor@example.com"
          },
          "text": "Let's start with algebra basics.",
          "timestamp": "00:05:32"
        }
      ],
      "default_summary": {
        "template_name": "general",
        "markdown_formatted": "## Summary\nSession covered algebra basics, quadratic equations, and homework assignment.\n"
      },
      "action_items": [
        {
          "description": "Complete exercises 1-10 from chapter 3",
          "user_generated": false,
          "completed": false,
          "recording_timestamp": "00:10:45",
          "recording_playback_url": "https://fathom.video/xyz123#t=645",
          "assignee": {
            "name": "Student Name",
            "email": "student@example.com"
          }
        }
      ],
      "calendar_invitees": [
        {
          "name": "Tutor Name",
          "email": "tutor@example.com",
          "is_external": false
        },
        {
          "name": "Student Name",
          "email": "student@example.com",
          "is_external": false
        },
        {
          "name": "PrepSkul AI",
          "email": "prepskul-ai@prepskul.com",
          "is_external": false
        }
      ]
    }
  ]
}
```

**Use Cases:**
- Fetch all PrepSkul sessions (filter by `prepskul-ai@prepskul.com`)
- Get meeting transcripts for storage
- Retrieve summaries for distribution
- Extract action items for assignment system

---

### 2. Get Meeting Summary

**Endpoint:** `GET /recordings/{recording_id}/summary`

**Purpose:** Retrieve AI-generated summary for a specific recording

**Authentication:**
```http
X-Api-Key: YOUR_API_KEY
```

**Path Parameters:**
```
recording_id: integer (required) - The recording ID from meeting data
```

**Query Parameters:**
```
destination_url: string (optional) - URL to POST summary asynchronously
```

**Example Request:**
```bash
curl --request GET \
  --url 'https://api.fathom.ai/external/v1/recordings/123456789/summary' \
  --header 'X-Api-Key: YOUR_API_KEY'
```

**Success Response (200 OK):**
```json
{
  "summary": {
    "template_name": "general",
    "markdown_formatted": "## Summary\n\nSession covered algebra basics, quadratic equations, and homework assignment. Student showed good understanding of linear equations.\n\n### Key Points:\n- Reviewed chapter 2 concepts\n- Introduced quadratic formula\n- Assigned practice problems\n\n### Next Steps:\n- Complete exercises 1-10\n- Review before next session"
  }
}
```

**Async Mode (with destination_url):**
```bash
curl --request GET \
  --url 'https://api.fathom.ai/external/v1/recordings/123456789/summary?destination_url=https://prepskul.com/api/webhooks/fathom/summary' \
  --header 'X-Api-Key: YOUR_API_KEY'
```

**Use Cases:**
- Send summary to tutor, student, and parent emails
- Store summary in database for record-keeping
- Display summary in app after session
- Generate session reports

---

### 3. Get Meeting Transcript

**Endpoint:** `GET /recordings/{recording_id}/transcript`

**Purpose:** Retrieve full transcript with speaker identification

**Authentication:**
```http
X-Api-Key: YOUR_API_KEY
```

**Path Parameters:**
```
recording_id: integer (required) - The recording ID from meeting data
```

**Query Parameters:**
```
destination_url: string (optional) - URL to POST transcript asynchronously
```

**Example Request:**
```bash
curl --request GET \
  --url 'https://api.fathom.ai/external/v1/recordings/123456789/transcript' \
  --header 'X-Api-Key: YOUR_API_KEY'
```

**Success Response (200 OK):**
```json
{
  "transcript": [
    {
      "speaker": {
        "display_name": "Tutor Name",
        "matched_calendar_invitee_email": "tutor@example.com"
      },
      "text": "Let's start with algebra basics.",
      "timestamp": "00:05:32"
    },
    {
      "speaker": {
        "display_name": "Student Name",
        "matched_calendar_invitee_email": "student@example.com"
      },
      "text": "I understand.",
      "timestamp": "00:05:45"
    }
  ]
}
```

**Use Cases:**
- Store full transcript in database
- Search transcripts for specific topics
- Generate detailed session reports
- Analyze conversation patterns

---

### 4. List Teams

**Endpoint:** `GET /teams`

**Purpose:** List all teams in Fathom account

**Authentication:**
```http
X-Api-Key: YOUR_API_KEY
```

**Use Cases:**
- Organize tutors/students into teams
- Filter meetings by team
- Generate team-level reports

---

### 5. List Team Members

**Endpoint:** `GET /team-members`

**Purpose:** List members of a specific team

**Authentication:**
```http
X-Api-Key: YOUR_API_KEY
```

**Use Cases:**
- Manage team access
- Filter meetings by team members

---

## Webhook Integration

### Purpose

Webhooks notify your server when meeting content is ready (asynchronous).

### Create Webhook

**Endpoint:** `POST /webhooks`

**Purpose:** Register a webhook endpoint

**Request Body:**
```json
{
  "url": "https://prepskul.com/api/webhooks/fathom",
  "events": ["new_meeting_content_ready"]
}
```

**Events:**
- `new_meeting_content_ready` - Triggered when meeting recording, transcript, and summary are available

### Webhook Payload

When meeting content is ready, Fathom POSTs to your endpoint:

```json
{
  "event": "new_meeting_content_ready",
  "recording_id": 123456789,
  "meeting_title": "Trial Session: Mathematics",
  "scheduled_start_time": "2025-01-25T16:00:00Z",
  "scheduled_end_time": "2025-01-25T17:00:00Z",
  "recording_start_time": "2025-01-25T16:01:12Z",
  "recording_end_time": "2025-01-25T17:00:55Z",
  "calendar_invitees": [
    {
      "name": "Tutor Name",
      "email": "tutor@example.com"
    },
    {
      "name": "Student Name",
      "email": "student@example.com"
    },
    {
      "name": "PrepSkul AI",
      "email": "prepskul-ai@prepskul.com"
    }
  ],
  "url": "https://fathom.video/xyz123",
  "share_url": "https://fathom.video/share/xyz123"
}
```

### Webhook Handler Implementation

**File:** `PrepSkul_Web/app/api/webhooks/fathom/route.ts`

```typescript
export async function POST(request: Request) {
  try {
    const payload = await request.json();
    
    // Verify webhook (if Fathom provides signature)
    // const isValid = verifyWebhookSignature(payload, request.headers);
    // if (!isValid) return new Response('Unauthorized', { status: 401 });
    
    if (payload.event === 'new_meeting_content_ready') {
      const { recording_id, calendar_invitees, meeting_title } = payload;
      
      // Find session by calendar invitees (tutor + student emails)
      const tutorEmail = calendar_invitees.find((e: any) => 
        e.email !== 'prepskul-ai@prepskul.com' && 
        e.email.includes('tutor')
      )?.email;
      
      const studentEmail = calendar_invitees.find((e: any) => 
        e.email !== 'prepskul-ai@prepskul.com' && 
        !e.email.includes('tutor')
      )?.email;
      
      // Fetch summary and transcript from Fathom API
      const summary = await fetchFathomSummary(recording_id);
      const transcript = await fetchFathomTranscript(recording_id);
      
      // Store in database
      await storeSessionData({
        recording_id,
        summary: summary.markdown_formatted,
        transcript: JSON.stringify(transcript),
        tutor_email: tutorEmail,
        student_email: studentEmail,
      });
      
      // Send summaries to all parties
      await sendSummariesToParticipants({
        tutorEmail,
        studentEmail,
        summary: summary.markdown_formatted,
        meetingTitle: meeting_title,
      });
      
      // Extract and assign action items
      await processActionItems(recording_id);
      
      // Check for flags (irregular behavior)
      await checkForAdminFlags(transcript, summary);
    }
    
    return Response.json({ success: true });
  } catch (error) {
    console.error('Fathom webhook error:', error);
    return new Response('Internal Server Error', { status: 500 });
  }
}
```

**Reference:** [Fathom Webhooks](https://developers.fathom.ai/api-reference/webhooks/create-a-webhook)

---

## Summary & Transcript Distribution

### Automatic Distribution Flow

1. **Fathom generates summary** after meeting ends
2. **Webhook triggers** → `new_meeting_content_ready`
3. **Fetch summary** from Fathom API
4. **Distribute to:**
   - **Tutor** (email + in-app notification)
   - **Student/Parent** (email + in-app notification)
   - **Admin** (for monitoring - optional)

### Email Distribution

**File:** `lib/features/sessions/services/fathom_summary_service.dart`

```dart
class FathomSummaryService {
  // Send summary to all participants
  static Future<void> sendSummaryToParticipants({
    required String recordingId,
    required String tutorEmail,
    required String studentEmail,
    String? parentEmail,
    required String summary,
    required String meetingTitle,
  }) async {
    // 1. Send to tutor
    await EmailService.sendEmail(
      to: tutorEmail,
      subject: 'Session Summary: $meetingTitle',
      body: _formatSummaryEmail(summary, meetingTitle, isTutor: true),
    );
    
    // 2. Send to student
    await EmailService.sendEmail(
      to: studentEmail,
      subject: 'Your Session Summary: $meetingTitle',
      body: _formatSummaryEmail(summary, meetingTitle, isTutor: false),
    );
    
    // 3. Send to parent (if applicable)
    if (parentEmail != null) {
      await EmailService.sendEmail(
        to: parentEmail,
        subject: 'Your Child\'s Session Summary: $meetingTitle',
        body: _formatSummaryEmail(summary, meetingTitle, isParent: true),
      );
    }
    
    // 4. Create in-app notifications
    await NotificationService.createNotification(
      userId: tutorId,
      type: 'session_summary_ready',
      title: 'Session Summary Ready',
      message: 'Summary for $meetingTitle is available',
      data: {'recording_id': recordingId, 'summary': summary},
    );
    
    await NotificationService.createNotification(
      userId: studentId,
      type: 'session_summary_ready',
      title: 'Your Session Summary',
      message: 'Summary for $meetingTitle is ready',
      data: {'recording_id': recordingId, 'summary': summary},
    );
  }
}
```

### Email Format

**Tutor Email:**
```
Subject: Session Summary: Trial Session - Mathematics

Hi [Tutor Name],

Your session with [Student Name] has been completed.

## Session Summary

[Fathom-generated summary here]

## Action Items
- [Action item 1]
- [Action item 2]

View full transcript: [Link]
```

**Student/Parent Email:**
```
Subject: Your Session Summary: Trial Session - Mathematics

Hi [Student/Parent Name],

Here's a summary of your session with [Tutor Name].

## What We Covered

[Fathom-generated summary here]

## Your Assignments
- [Action item 1] - Due: [Date]
- [Action item 2] - Due: [Date]

Keep up the great work!
```

---

## Action Items & Assignments

### Extracting Action Items

Fathom automatically extracts action items from meetings:

```json
{
  "action_items": [
    {
      "description": "Complete exercises 1-10 from chapter 3",
      "user_generated": false,
      "completed": false,
      "recording_timestamp": "00:10:45",
      "recording_playback_url": "https://fathom.video/xyz123#t=645",
      "assignee": {
        "name": "Student Name",
        "email": "student@example.com"
      }
    }
  ]
}
```

### Assignment System Integration

**File:** `lib/features/sessions/services/assignment_service.dart`

```dart
class AssignmentService {
  // Create assignments from Fathom action items
  static Future<void> createAssignmentsFromFathom({
    required String sessionId,
    required List<FathomActionItem> actionItems,
  }) async {
    for (final item in actionItems) {
      // Create assignment in database
      await _supabase.from('assignments').insert({
        'session_id': sessionId,
        'session_type': 'trial', // or 'recurring'
        'student_id': item.assignee.userId,
        'tutor_id': sessionTutorId,
        'title': item.description,
        'description': item.description,
        'due_date': _calculateDueDate(sessionDate),
        'status': 'pending',
        'fathom_timestamp': item.recording_timestamp,
        'fathom_playback_url': item.recording_playback_url,
        'created_at': DateTime.now().toIso8601String(),
      });
      
      // Send notification to student
      await NotificationService.createNotification(
        userId: item.assignee.userId,
        type: 'new_assignment',
        title: 'New Assignment',
        message: item.description,
        data: {'assignment_id': assignmentId},
      );
    }
  }
}
```

### Database Schema

```sql
CREATE TABLE assignments (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  session_id UUID NOT NULL,
  session_type TEXT CHECK (session_type IN ('trial', 'recurring')),
  student_id UUID REFERENCES profiles(id) ON DELETE CASCADE,
  tutor_id UUID REFERENCES profiles(id) ON DELETE CASCADE,
  title TEXT NOT NULL,
  description TEXT,
  due_date DATE,
  status TEXT DEFAULT 'pending' CHECK (status IN ('pending', 'in_progress', 'completed', 'overdue')),
  fathom_timestamp TEXT, -- Recording timestamp where assignment was mentioned
  fathom_playback_url TEXT, -- Link to specific moment in recording
  completed_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ DEFAULT NOW()
);
```

---

## Admin Flags & Monitoring

### Irregular Behavior Detection

**File:** `lib/features/admin/services/session_monitoring_service.dart`

```dart
class SessionMonitoringService {
  // Analyze transcript for flags
  static Future<List<AdminFlag>> analyzeSessionForFlags({
    required String transcript,
    required String summary,
    required String sessionId,
  }) async {
    final flags = <AdminFlag>[];
    
    // 1. Check for inappropriate language
    if (_containsInappropriateLanguage(transcript)) {
      flags.add(AdminFlag(
        type: 'inappropriate_language',
        severity: 'high',
        description: 'Inappropriate language detected in session',
        sessionId: sessionId,
      ));
    }
    
    // 2. Check for no-show
    final participants = _extractParticipants(transcript);
    if (participants.length < 2) {
      flags.add(AdminFlag(
        type: 'no_show',
        severity: 'medium',
        description: 'One or more participants did not join',
        sessionId: sessionId,
      ));
    }
    
    // 3. Check for very short sessions (< 10 minutes)
    final duration = _calculateDuration(transcript);
    if (duration < 10) {
      flags.add(AdminFlag(
        type: 'short_session',
        severity: 'low',
        description: 'Session ended unusually early',
        sessionId: sessionId,
      ));
    }
    
    // 4. Check for payment bypass attempts
    if (_containsPaymentBypassKeywords(transcript)) {
      flags.add(AdminFlag(
        type: 'payment_bypass_attempt',
        severity: 'critical',
        description: 'Possible attempt to bypass payment system',
        sessionId: sessionId,
      ));
    }
    
    // 5. Check for external contact attempts
    if (_containsExternalContactKeywords(transcript)) {
      flags.add(AdminFlag(
        type: 'external_contact_attempt',
        severity: 'high',
        description: 'Possible attempt to contact outside platform',
        sessionId: sessionId,
      ));
    }
    
    // Store flags in database
    if (flags.isNotEmpty) {
      await _storeAdminFlags(flags);
      
      // Notify admins
      await NotificationService.notifyAdmins(
        type: 'session_flags',
        title: 'Session Flags Detected',
        message: '${flags.length} flags detected in session',
        data: {'session_id': sessionId, 'flags': flags.map((f) => f.toJson()).toList()},
      );
    }
    
    return flags;
  }
}
```

### Flag Types

1. **Inappropriate Language** - Profanity, harassment, etc.
2. **No-Show** - Participant didn't join
3. **Short Session** - Ended prematurely
4. **Payment Bypass Attempt** - Mentions of paying outside platform
5. **External Contact Attempt** - Sharing contact info outside platform
6. **Content Violation** - Off-topic or inappropriate content

### Database Schema

```sql
CREATE TABLE admin_flags (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  session_id UUID NOT NULL,
  session_type TEXT CHECK (session_type IN ('trial', 'recurring')),
  flag_type TEXT NOT NULL,
  severity TEXT CHECK (severity IN ('low', 'medium', 'high', 'critical')),
  description TEXT NOT NULL,
  transcript_excerpt TEXT, -- Relevant excerpt from transcript
  resolved BOOLEAN DEFAULT FALSE,
  resolved_by UUID REFERENCES profiles(id),
  resolved_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ DEFAULT NOW()
);
```

---

## Rate Limiting

### Global Rate Limits

- **Maximum:** 60 API calls per 60 seconds
- **Response Headers:**
  - `RateLimit-Limit`: Maximum requests allowed
  - `RateLimit-Remaining`: Requests remaining in window
  - `RateLimit-Reset`: Time remaining in window

### Handling Rate Limits

**Status Code:** `429 Too Many Requests`

**Implementation:**
```dart
class FathomService {
  static Future<T> _makeRequest<T>(Future<T> Function() request) async {
    int retries = 0;
    while (retries < 3) {
      try {
        return await request();
      } on HttpException catch (e) {
        if (e.statusCode == 429) {
          // Rate limited - wait and retry
          final waitTime = Duration(seconds: 60);
          await Future.delayed(waitTime);
          retries++;
          continue;
        }
        rethrow;
      }
    }
    throw Exception('Rate limit exceeded');
  }
}
```

**Reference:** [Fathom Rate Limiting](https://developers.fathom.ai/api-overview)

---

## Implementation Guide

### Step 1: Setup Fathom Account

1. Create Fathom account
2. Generate API key in Settings → API Access
3. Connect PrepSkul AI email (`prepskul-ai@prepskul.com`) to Fathom
4. Authorize Google Calendar access for PrepSkul AI account

### Step 2: Calendar Integration

1. When creating session calendar events, add `prepskul-ai@prepskul.com` as attendee
2. Fathom automatically joins when meeting starts
3. Fathom records and transcribes automatically

### Step 3: Webhook Setup

1. Create webhook endpoint: `POST /api/webhooks/fathom`
2. Register webhook with Fathom API
3. Handle `new_meeting_content_ready` events

### Step 4: Data Processing

1. Fetch summary and transcript on webhook trigger
2. Store in `session_transcripts` and `session_summaries` tables
3. Extract action items and create assignments
4. Analyze for admin flags
5. Send summaries to all participants

### Step 5: Distribution

1. Email summaries to tutor, student, parent
2. Create in-app notifications
3. Store transcripts for future reference
4. Display summaries in app

---

## Environment Variables

```env
# Fathom API Key (alternative to OAuth)
FATHOM_API_KEY=your_api_key_here

# Fathom OAuth (Development)
FATHOM_CLIENT_ID_DEV=your-fathom-dev-client-id-here
FATHOM_CLIENT_SECRET_DEV=your-fathom-dev-client-secret-here
FATHOM_WEBHOOK_SECRET_DEV=your-fathom-dev-webhook-secret-here

# Fathom OAuth (Production)
FATHOM_CLIENT_ID_PROD=your-fathom-prod-client-id-here
FATHOM_CLIENT_SECRET_PROD=your-fathom-prod-client-secret-here
FATHOM_WEBHOOK_SECRET_PROD=your-fathom-prod-webhook-secret-here

# PrepSkul Virtual Assistant Account
# Note: Using "Virtual Assistant" instead of "AI" for better trust-building with parents, tutors, investors
# Using your VA email (Fathom account email), can migrate to prepskul-va@prepskul.com later
PREPSKUL_VA_EMAIL=your-va-email-here
PREPSKUL_VA_NAME=PrepSkul Virtual Assistant
PREPSKUL_VA_DISPLAY_NAME=PrepSkul VA  # Short form for UI
FATHOM_ACCOUNT_EMAIL=your-fathom-account-email-here  # Fathom account email

# Admin Email for Flags
ADMIN_EMAIL=admin@prepskul.com

# Redirect URLs (Use HTTPS web app URLs for all platforms - mobile & web)
FATHOM_REDIRECT_URI_DEV=https://app.prepskul.com/auth/fathom/callback
FATHOM_REDIRECT_URI_PROD=https://app.prepskul.com/auth/fathom/callback
# Note: Fathom doesn't accept custom URL schemes (prepskul://)
# Mobile apps redirect to web app URL, which handles OAuth and can deep link back
```

---

## Limitations & Challenges

### 1. Concurrent Meetings ⚠️ **CRITICAL LIMITATION**

**Question:** Can Fathom handle multiple meetings at the same time?

**Answer:** ❌ **NO - Fathom can only join ONE meeting at a time**

**Critical Finding:**
- **Fathom can only join and record ONE meeting at a time**
- If you have overlapping or simultaneous meetings, Fathom will only join ONE
- This is a **major limitation** for platforms with multiple concurrent sessions

**Impact on PrepSkul:**
- If multiple tutors have sessions at the same time, only ONE will be recorded
- Other sessions will be missed unless handled differently

**Solutions & Workarounds:**

1. **Session Scheduling Strategy:**
   - Stagger session times to avoid overlaps
   - Implement buffer time between sessions (e.g., 15-minute gaps)
   - Prioritize which sessions Fathom should join

2. **Alternative Approach - Multiple Fathom Accounts:**
   - Create multiple Fathom accounts (one per concurrent session slot)
   - Each account connects to different PrepSkul email addresses:
     - `prepskul-va-1@prepskul.com`
     - `prepskul-va-2@prepskul.com`
     - `prepskul-va-3@prepskul.com`
   - Distribute sessions across accounts based on time slots
   - **Cost consideration:** Each account may have separate pricing

3. **Hybrid Solution:**
   - Use Fathom for priority sessions
   - Use Google Meet's built-in recording for others
   - Process recordings separately

4. **Fallback Monitoring:**
   - Track which sessions Fathom successfully joined
   - Notify admins if sessions were missed
   - Implement manual recording triggers for missed sessions

**Best Practices:**

1. **Smart Scheduling:**
   ```dart
   // When creating sessions, check for conflicts
   final conflictingSessions = await checkForFathomConflicts(
     scheduledTime: sessionTime,
     duration: sessionDuration,
   );
   
   if (conflictingSessions.isNotEmpty) {
     // Either reschedule or use alternative recording method
     await handleConcurrentSessionConflict(session, conflictingSessions);
   }
   ```

2. **Meeting Identification:**
   ```dart
   // Filter meetings by specific calendar invitees
   final meetings = await FathomService.getPrepSkulSessions(
     calendarInvitees: [
       'prepskul-va@prepskul.com',  // Updated name
       tutorEmail,
       studentEmail,
     ],
     createdAfter: DateTime.now().subtract(Duration(hours: 1)),
   );
   ```

3. **Priority System:**
   - Trial sessions get priority (first-time conversions)
   - Recurring sessions can use alternative recording
   - VIP/premium sessions prioritized

**Recommendation:**
- **For Phase 1.2:** Accept the limitation, implement smart scheduling
- **For Scale:** Consider multiple Fathom accounts or hybrid solution
- **Monitor:** Track missed sessions and adjust strategy

### 2. Rate Limiting

**Challenge:** Global rate limit of **60 API calls per 60 seconds**

**Impact:**
- If processing many concurrent meetings, you might hit rate limits
- Webhook processing might be delayed if rate limited

**Solutions:**
- Implement exponential backoff for retries
- Queue API requests if approaching limit
- Use webhooks for async processing (reduces API calls)
- Consider caching meeting data

### 3. App Verification Status

**Current Status:** **UNVERIFIED**

**Impact:**
- Users see warning when authorizing PrepSkul app
- May reduce trust in app
- Cannot request verification until certain number of active users

**Solutions:**
- Complete app details in Fathom dashboard
- Add proper app icon and description
- Request verification once user threshold reached
- Consider using API keys instead of OAuth for initial rollout

### 4. API Key Limitations

**Challenge:** API keys are user-specific

- API keys can only access meetings recorded by the key owner
- Cannot access meetings from other users unless shared within team
- Admin API keys don't grant access to unshared meetings

**Solution:**
- Use OAuth flow for calendar integration
- Ensure PrepSkul AI account is the calendar owner
- All meetings should have PrepSkul AI as attendee

### 5. Platform Support

**Supported Platforms:**
- ✅ Google Meet
- ✅ Zoom
- ✅ Microsoft Teams

**Device Compatibility:**
- ✅ Mac and Windows computers
- ❌ **Mobile devices NOT supported** (iOS, Android, tablets)
- ❌ Chromebooks, Linux systems

**Impact on PrepSkul:**
- ✅ **Fathom CAN join meetings from mobile users** - It joins via calendar invite, not dependent on user's device
- ✅ **Mobile users can join via Google Meet** - Google Meet works perfectly on mobile browsers
- ✅ **Web app accessible on mobile** - Users can access `app.prepskul.com` on mobile browser
- ✅ **Automatic calendar works for all** - Calendar events are created server-side, device-independent
- **How it works:**
  1. User (on any device) books session → Payment processed
  2. Server creates Google Calendar event automatically
  3. Server adds PrepSkul VA as attendee automatically
  4. Fathom monitors PrepSkul VA's calendar and joins automatically
  5. User joins Google Meet from their device (mobile/desktop/tablet)
  6. Fathom joins as participant (device-independent)
  7. Recording and transcription happen automatically

**Potential Issues:**
- Other video platforms not supported
- Meeting link changes after calendar creation
- Timezone handling for international sessions
- Mobile app OAuth requires deep links, not standard redirects

### 6. Data Privacy & Compliance

**Considerations:**
- Transcripts contain sensitive student/tutor conversations
- Must comply with data protection regulations
- Store transcripts securely
- Implement access controls (RLS policies)

### 7. Cost Implications

**Unknown Factors:**
- Pricing based on number of meetings
- Cost per transcription hour
- Storage costs for recordings
- API usage costs

**Recommendation:**
- Monitor usage closely
- Implement cost alerts
- Consider archiving old transcripts

### 8. Accuracy & Language Support

**Potential Issues:**
- Transcript accuracy depends on audio quality
- Language detection might not work perfectly for all languages
- Accent recognition might vary
- Technical terms might be mis-transcribed

**Solutions:**
- Review transcripts for critical sessions
- Allow manual corrections
- Test with various accents and languages

### 9. Webhook Reliability

**Challenges:**
- Webhook delivery failures
- Network issues
- Idempotency handling

**Solutions:**
- Implement webhook retry logic
- Store webhook events for replay
- Use idempotency keys
- Monitor webhook delivery status

### 10. Calendar Integration Complexity

**Challenges:**
- OAuth token expiration
- Calendar sync delays
- Multiple calendar accounts
- Timezone conversions

**Solutions:**
- Implement OAuth token refresh
- Add retry logic for calendar operations
- Use single PrepSkul AI calendar account
- Store timezone per session

---

## Is Fathom Good Enough?

### ✅ **Strengths:**

1. **Automatic Meeting Join** - No manual intervention needed
2. **Comprehensive Features** - Transcripts, summaries, action items
3. **Webhook Support** - Real-time notifications
4. **API Flexibility** - Good filtering and query capabilities
5. **Multiple Platform Support** - Google Meet, Zoom, Teams
6. **Handles Concurrent Meetings** - Can join multiple meetings simultaneously

### ⚠️ **Considerations:**

1. **Rate Limiting** - 60 calls/min might be limiting at scale
2. **App Verification** - Currently unverified (users see warning)
3. **Cost Unknown** - Pricing structure not clear
4. **Platform Dependency** - Requires supported video platforms
5. **Accuracy Varies** - Depends on audio quality and language

### 🎯 **Recommendation:**

**⚠️ Fathom has limitations, but can work for Phase 1.2** with careful planning:

**Pros:**
1. **Start with Fathom** - It provides most required features
2. **Automatic join** - Calendar-based integration works well
3. **Comprehensive features** - Transcripts, summaries, action items

**Cons & Mitigations:**
1. **Concurrent meetings limitation** - Only ONE at a time
   - **Mitigation:** Smart scheduling, multiple accounts, or hybrid approach
2. **Rate limiting** - 60 calls/min
   - **Mitigation:** Use webhooks, implement queuing
3. **Mobile not directly supported** - But works via calendar
   - **Mitigation:** OAuth via deep links, calendar-based joining
4. **App verification** - Requires production users
   - **Mitigation:** Start unverified, request after launch

**Implementation Strategy:**

1. **Phase 1.2 (Initial):**
   - Accept concurrent meeting limitation
   - Implement smart scheduling to minimize overlaps
   - Use single Fathom account
   - Monitor missed sessions

2. **Phase 2 (Scale):**
   - Evaluate multiple Fathom accounts if needed
   - Consider hybrid approach (Fathom + Google Meet recording)
   - Implement priority system for sessions

3. **Verification:**
   - Complete app details in Fathom dashboard
   - Launch with real users in production
   - Request verification after sufficient usage

**Alternative Consideration:**
- If concurrent meetings become critical issue:
  - Google Meet API directly (more control, more complexity)
  - Custom transcription service (more customization, more development)
  - Hybrid approach (Fathom for priority + Google Meet for others)
  - Multiple Fathom accounts (cost consideration)

---

## Quick Reference

### Auto-Join Setup
1. Add `prepskul-va@prepskul.com` (PrepSkul Virtual Assistant) to calendar event attendees
2. Fathom joins automatically when meeting starts
3. **Important:** Only ONE meeting at a time - schedule accordingly
4. No manual intervention needed

### Summary Distribution
1. Webhook triggers when content ready
2. Fetch summary from API
3. Email to tutor, student, parent
4. Store in database

### Action Items
1. Extract from Fathom response
2. Create assignments in database
3. Send notifications to students
4. Track completion

### Admin Flags
1. Analyze transcript for keywords
2. Check for irregular patterns
3. Store flags in database
4. Notify admins

---

## Support & Resources

- **API Documentation:** https://developers.fathom.ai/api-overview
- **Webhook Documentation:** https://developers.fathom.ai/api-reference/webhooks/create-a-webhook
- **Support:** Contact Fathom support for integration help

---

**Document Version:** 1.0  
**Last Updated:** January 2025  
**Maintained By:** PrepSkul Development Team






