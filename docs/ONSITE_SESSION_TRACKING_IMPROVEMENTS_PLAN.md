# 🏠 Onsite Session Tracking Improvements - Implementation Plan

**Date:** January 28, 2026  
**Priority:** 🔴 CRITICAL  
**Estimated Time:** 4-6 weeks

---

## 🧠 REAL-WORLD DESIGN: WHO CAN VERIFY WHAT?

### The Constraint
- **Parent books for student** – Parent is often **not present** when the tutor comes home to teach. Parent may be at work, running errands, or deliberately not in the room.
- **Student may not have a phone** – When parent books for a child, the **student might not have their own device**. So we **cannot assume** the student will check in via the app.
- **We need a design that works when only the tutor is reliably “on app”.**

### Who Is Reliably On-App?

| Role    | Has phone / in app? | Can check in? | Can give feedback? |
|---------|---------------------|---------------|---------------------|
| **Tutor**   | ✅ Almost always    | ✅ Yes        | ✅ Yes (tutor notes) |
| **Parent**  | ✅ Usually          | ⚠️ Often not at location | ✅ Yes (after session) |
| **Student** | ❌ Not guaranteed   | ⚠️ Only if they have phone | ✅ If parent submits on their behalf |

### Design Principle: **Tutor-Centric Verification + Feedback as Confirmation**

1. **Primary verification = TUTOR**
   - We **rely on the tutor** as the main proof that the session happened.
   - Tutor is the one delivering the service and is expected to have their phone.
   - **Tutor check-in** (location + optional selfie) = “I arrived and started the session.”
   - For **continuous monitoring**, we only **require** the tutor to stay at location (or we only enforce/monitor tutor location). Student/parent location is optional where possible.

2. **Student / parent check-in = OPTIONAL**
   - If the **student** has a phone and checks in → we record it and use it as extra signal.
   - If the **parent** is at home and checks in → same.
   - We **never block** session validity or payment because student or parent did not check in.
   - UI: “Optional – Check in if you’re here” for student/parent, not “You must check in.”

3. **Feedback = confirmation from family side**
   - After the session, **parent or student** (whoever has app access) submits the **session feedback/survey**.
   - That feedback is the family’s way to confirm (or dispute) that the session took place.
   - We can add a single explicit question: **“Did this session take place as scheduled?”** (Yes / No / Partially). If “No” or “Partially”, we flag for review even if tutor checked in.
   - So: **tutor check-in + (positive feedback or explicit “session took place”)** = strong confirmation. **Tutor check-in + “session did not take place”** = automatic flag for admin.

4. **System can be “smart”**
   - **Payment / completion rules:**  
     Session can count as completed if:  
     **Tutor checked in** AND  
     (**Parent/student submitted feedback saying session took place** OR **no dispute within X days**).  
     So we don’t require feedback to release payment, but we use feedback (and disputes) when present.
   - **Mismatch handling:**  
     If tutor has check-in but parent/student says “session didn’t happen” or gives very low rating with a reason like “tutor didn’t show”, we **flag for admin review** and optionally hold payment until resolved.
   - **Missing feedback:**  
     If parent/student never submits feedback, we still allow completion based on tutor check-in after a timeout (e.g. 7 days), but we can mark “no feedback from family” for analytics.

### Summary Table

| What we need                | Who provides it        | Required? |
|-----------------------------|------------------------|-----------|
| “Session started at location” | **Tutor** check-in     | ✅ Yes    |
| “Session ended / duration”  | **Tutor** end session  | ✅ Yes    |
| “Family confirms session”   | **Parent or student** feedback | ⚠️ Optional but used when present |
| “Who attended?” (multi-learner) | **Parent** in feedback | ⚠️ Optional (e.g. “Which learners attended?”) |
| Student at location         | Student check-in       | ❌ No (optional if they have phone) |
| Parent at location         | Parent check-in        | ❌ No (often not there) |

So: **we focus mainly on the tutor for verification, and use the session survey/feedback from student or parent as the family-side confirmation.** The system is “smart” by not requiring the student (or parent) to be on-site or on-app at session time, while still using their feedback when they do respond.

---

## 📊 CURRENT STATE ANALYSIS

### ✅ What Works
- GPS check-in with proximity verification (100m radius)
- Check-in/check-out timestamps
- Punctuality tracking (early/on-time/late)
- Selfie upload capability (exists but not enforced)
- Location sharing for parents
- Basic attendance tracking

### ❌ Critical Gaps
1. **No Continuous Monitoring** - Check-in happens once, users can leave immediately
2. **No Biometric Verification** - Selfie exists but no face matching/verification
3. **No Activity Verification** - No proof that teaching/learning occurred
4. **No Multi-Learner Tracking** - Can't verify all learners in group sessions
5. **No Safety Monitoring** - Location sharing exists but not actively monitored

---

## 🎯 IMPROVEMENT PRIORITIES

### Phase 1: Continuous Location Monitoring (Week 1-2) 🔴 CRITICAL
**Goal:** Ensure **tutor** remains at session location throughout session (student/parent optional)

**Design note:** Only the **tutor** is required to have app/phone at session time. So continuous location monitoring applies **primarily to the tutor**. Student/parent location checks are optional when they have a device.

---

#### ✅ Background only – no disturbance during class

- **All continuous monitoring runs in the background.** No popups, no “Verify your location” dialogs, no prompts during class. The tutor can teach without being interrupted.
- **Tutor can minimize the app** (send it to background) and use the phone for other things or set it aside. We use **OS-level background location updates** (e.g. every 5–10 minutes), so we do **not** require the app to be on screen.
- **Tutor can leave the app at any time.** If the tutor **fully quits** the app (force-close / swipe away):
  - We **cannot** get location while the app is killed. So for that period we have no continuous trail.
  - We **still have**: check-in at start (location verified) and check-out at end. That already proves “arrived at location” and “ended session.”
  - We **do not** block session completion or payment if the app was quit. Continuous monitoring is **best-effort**: when the app is in background we collect; when it’s killed we don’t, and we don’t penalize.
- **Optional:** One gentle reminder when they start the session: *“Keep the app in the background (minimized is fine) — it helps document your session and support smooth payment. You can teach normally.”* No repeated nagging.

**Summary:** Monitoring is **background-only**, **non-intrusive**. Tutors are not required to keep the app open on screen and can quit the app; we still rely on check-in + check-out as the main verification.

---

#### 📱 Tutor instructions (in-app copy)

Use this (or a short version) when the tutor **starts** an onsite session, so they know what to do with the app during class.

**Short version (banner or one-time message):**
> **During this session:** You can **minimize** the app and teach as usual. Keeping it in the background (don’t swipe it away) **helps document your session** so your work is clearly recorded and payment goes smoothly. We won’t show any popups during class.

**Full version (optional “Why?” expandable or help screen):**
> **During this onsite session**
> - **You can minimize the app** – Send it to the background and use your phone for other things or set it aside. You don’t need to keep the app on screen.
> - **Keeping the app running in the background helps you** – It backs up your session record so your check-in and time are clearly documented. That supports smooth completion and payment. We won’t show any popups or interrupt your class.
> - **If you do close the app** – Your session still counts. We’ll use your check-in and check-out. You won’t be penalized; we just won’t have the extra backup record for that time.

**One-line reminder (e.g. under “Session in progress”):**
> Keep the app in the background — it helps document your session and support smooth payment.

**Tone:** Frame as a **benefit to the tutor** (clear record, smooth payment), not as “we need to verify you.” **Do not say:** “so we can verify you stayed” or “you must keep the app open.” **Do say:** “It helps document your session” / “backs up your record” / “supports smooth payment.”

---

**Implementation:**
1. **Background Location Updates (Tutor)**
   - Use **background location** (OS APIs: iOS/Android background location) every 5–10 minutes during active session. **No in-app prompts** during class.
   - If tutor moves >50m from session location, we **log it** and can alert admin (e.g. after session). We do **not** show a popup to the tutor during class.
   - Store location history in database. If app was quit, we only have check-in + check-out points (no trail in between).

2. **Location Deviation Detection (post-session or silent)**
   - Detect deviations from stored location history. Alerts to admin (and optionally parent) can be **after the session** or via a silent notification – **not** a blocking dialog during class.
   - Session does **not** pause/resume based on location; tutor is never forced to interact during class.

3. **Background-Only Tracking**
   - Background location updates for **tutor** when app is in **background** (minimized). Battery-efficient interval (e.g. 5–10 min).
   - When app is **killed**: no updates; we still accept check-out and completion. No penalty.
   - Optional: same for student/parent if they have app in background (never block on it).

**Database Changes:**
```sql
-- Add to session_attendance table
ALTER TABLE session_attendance ADD COLUMN IF NOT EXISTS location_history JSONB;
-- Format: [{"timestamp": "2026-01-28T10:00:00Z", "lat": 4.0511, "lon": 9.7679, "distance_meters": 15}]

ALTER TABLE session_attendance ADD COLUMN IF NOT EXISTS location_deviations JSONB;
-- Format: [{"timestamp": "2026-01-28T10:15:00Z", "distance_meters": 150, "resolved": false}]

ALTER TABLE session_attendance ADD COLUMN IF NOT EXISTS last_location_check TIMESTAMPTZ;
ALTER TABLE session_attendance ADD COLUMN IF NOT EXISTS location_check_count INT DEFAULT 0;
```

**Code Structure:**
```dart
// New service: ContinuousLocationMonitoringService
class ContinuousLocationMonitoringService {
  // Start monitoring for a session
  static Future<void> startMonitoring(String sessionId, String userId);
  
  // Periodic location check
  static Future<void> performLocationCheck(String sessionId, String userId);
  
  // Check for deviations
  static Future<bool> checkLocationDeviation(String sessionId, String userId);
  
  // Stop monitoring
  static Future<void> stopMonitoring(String sessionId, String userId);
}
```

---

### Phase 2: Selfie-Based Verification (Week 2-3) 🔴 CRITICAL
**Goal:** Proof that the session happened with the right people – via selfie at check-in (onsite). **All capture is from the tutor’s side** for onsite sessions (tutor has the phone; student may not).

#### Two ways to use selfies (clarification)

| Type | Who takes it | What it proves | Needs face-matching API? |
|------|----------------|-----------------|---------------------------|
| **A) Tutor-only selfie** | Tutor (on tutor’s device) | “The person checking in is the tutor” (identity). Compare selfie to tutor profile photo. | Yes (e.g. AWS Rekognition) |
| **B) Group selfie (tutor + student(s))** | Tutor (on tutor’s device) | “Tutor and student(s) were together at the session” (presence). Just store the photo; optional face-count. | No (optional: face count only) |

**Recommended for onsite:** Use **B) Group selfie** as the primary check-in proof: tutor takes a **selfie with the student(s)** at check-in. That gives presence proof without requiring biometric APIs. **Optionally** add A) tutor-only face match if you want identity verification (same person as tutor profile).

**Whose end?** For **onsite** sessions, **the tutor** takes the selfie on **their** device (tutor’s app). Student(s) don’t need to have a phone; they just need to be in frame for the group photo.

**Implementation (choose one or both):**

1. **Group selfie with student(s) at check-in (recommended for onsite)**
   - **Tutor** takes one photo at check-in: **tutor + student(s) in frame** (or tutor + one student for 1:1).
   - Store the photo in session_attendance (e.g. `check_in_photo_url` or `check_in_selfie_url`). No face-matching required; it’s **presence proof** (“we were together”).
   - Optional: use face-detection (count faces) to check “at least N people in photo” for multi-learner sessions.
   - **Only at check-in** – no mid-session selfie prompts.

2. **Optional: Tutor identity verification (tutor-only selfie vs profile)**
   - If you also want “is this the same person as the tutor account?”: tutor takes a **solo** selfie at check-in; compare to tutor profile photo via AWS Rekognition (or similar). Store result in `check_in_face_verification` (confidence, verified).
   - Liveness (e.g. blink/motion) reduces photo spoofing. Fallback: retry or manual override if verification fails.

3. **No mid-session face prompts**
   - We do **not** ask for another selfie during class. Verification is **only at check-in** (and optionally at check-out if added later).

**Face recognition (only if using tutor identity verification):**
- AWS Rekognition, Google Cloud Vision, Face++, or self-hosted. Use only when comparing tutor selfie to profile photo.

**Database Changes:**
```sql
-- Group selfie (presence proof) – recommended for onsite
ALTER TABLE session_attendance ADD COLUMN IF NOT EXISTS check_in_photo_url TEXT;
-- URL of photo: tutor + student(s) at check-in. No face-matching needed.

-- Optional: tutor identity (if using face match to profile)
ALTER TABLE session_attendance ADD COLUMN IF NOT EXISTS check_in_face_verification JSONB;
-- Format: {"confidence": 0.95, "verified": true, "timestamp": "..."}

ALTER TABLE session_attendance ADD COLUMN IF NOT EXISTS face_verification_required BOOLEAN DEFAULT false;
ALTER TABLE session_attendance ADD COLUMN IF NOT EXISTS face_verification_passed BOOLEAN DEFAULT false;
```

**Code Structure:**
```dart
// Check-in photo (group selfie) – tutor takes photo with student(s)
// Upload to storage, store URL in session_attendance.check_in_photo_url.
// Optional: face count check (e.g. "at least 2 faces") for presence.

// If using tutor identity verification:
class FaceVerificationService {
  static Future<Map<String, dynamic>> verifyCheckInFace({
    required String userId,
    required File selfieFile,
    required String sessionId,
  });
  static Future<double> compareFaces(File sourceImage, File targetImage); // e.g. Rekognition
}
```

---

### Phase 3: Activity Verification (Week 3-4) 🟡 HIGH
**Goal:** Verify that teaching/learning occurred – **tutor notes required**; student/parent input via **feedback form**

**Design note:** Tutor is required to end the session and can be required to add notes. Student/parent “activity” is captured via the **session feedback/survey** (e.g. “What was covered?” or “Did this session take place?”), not a separate activity app at session time (student may not have phone).

**Implementation:**
1. **Tutor Activity Requirements**
   - Require tutor to submit session notes (and optionally photos) when **ending** the session
   - Optional: photo of whiteboard/work done
   - Brief summary of topics covered
   - Cross-reference with session duration

2. **Student/Parent Activity via Feedback (no phone at session required)**
   - **Session feedback form** (after session) asks parent or student:
     - “Did this session take place as scheduled?” (Yes / No / Partially)
     - Rating, what went well, what could improve (existing)
     - Optional: “What was covered?” or “What did the learner work on?”
   - No requirement for student to submit anything **during** the session

3. **Work Product Verification**
   - Timestamp tutor’s session notes and optional photos
   - Verify submitted at session end time (or within short window)
   - Use feedback “session took place” + rating as family-side confirmation

**Database Changes:**
```sql
-- New table: session_activity_verification
CREATE TABLE IF NOT EXISTS session_activity_verification (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  session_id UUID NOT NULL REFERENCES individual_sessions(id),
  user_id UUID NOT NULL REFERENCES auth.users(id),
  user_type TEXT NOT NULL CHECK (user_type IN ('tutor', 'student')),
  
  -- Activity Evidence
  session_notes TEXT,
  work_photos TEXT[], -- Array of photo URLs
  whiteboard_photo_url TEXT,
  summary TEXT,
  
  -- Verification
  submitted_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  verified BOOLEAN DEFAULT false,
  verification_notes TEXT,
  
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_session_activity_session ON session_activity_verification(session_id);
CREATE INDEX idx_session_activity_user ON session_activity_verification(user_id);
```

**Code Structure:**
```dart
// New service: SessionActivityVerificationService
class SessionActivityVerificationService {
  // Submit tutor activity
  static Future<void> submitTutorActivity({
    required String sessionId,
    required String tutorId,
    String? sessionNotes,
    List<File>? workPhotos,
    File? whiteboardPhoto,
  });
  
  // Submit student activity
  static Future<void> submitStudentActivity({
    required String sessionId,
    required String studentId,
    String? summary,
    List<File>? workPhotos,
  });
  
  // Verify activity was submitted during session
  static Future<bool> verifyActivityTiming(String sessionId);
}
```

---

### Phase 4: Multi-Learner Tracking (Week 4-5) 🟡 HIGH
**Goal:** Verify all learners in group sessions individually

**Implementation:**
1. **Individual Check-In Per Learner**
   - Require check-in for each learner separately
   - Face verification for each learner
   - Individual location tracking

2. **Group Photo Verification**
   - Require group photo with all learners + tutor
   - Face detection to count participants
   - Verify all expected learners present

3. **Individual Attendance Tracking**
   - Track attendance per learner
   - Individual location monitoring
   - Individual activity verification

**Database Changes:**
```sql
-- session_attendance already supports multiple records per session
-- Just need to ensure we create one per learner

-- Add to parent_learners table for face verification
ALTER TABLE parent_learners ADD COLUMN IF NOT EXISTS profile_photo_url TEXT;
ALTER TABLE parent_learners ADD COLUMN IF NOT EXISTS face_id TEXT; -- For face recognition
```

**Code Structure:**
```dart
// Enhance LocationCheckInService
class LocationCheckInService {
  // Check in multiple learners
  static Future<Map<String, dynamic>> checkInMultipleLearners({
    required String sessionId,
    required String parentId,
    required List<String> learnerIds,
    required String sessionAddress,
  });
  
  // Verify group photo
  static Future<Map<String, dynamic>> verifyGroupPhoto({
    required String sessionId,
    required File groupPhoto,
    required List<String> expectedLearnerIds,
  });
}
```

---

### Phase 5: Safety Monitoring (Week 5-6) 🔴 CRITICAL
**Goal:** Active safety monitoring for onsite sessions, especially for minors

**Implementation:**
1. **Real-Time Location Monitoring**
   - Active location tracking during session
   - Alert parent if location deviates >100m
   - Background location updates

2. **Emergency Features**
   - Panic button for student/tutor
   - Instant alert to parent/admin
   - Emergency contact notification
   - Location sharing with emergency contacts

3. **Automatic Safety Checks**
   - Check-in reminders if location not verified
   - Alert if session extends beyond scheduled time
   - Alert if location changes unexpectedly

**Database Changes:**
```sql
-- Enhance session_location_tracking table
ALTER TABLE session_location_tracking ADD COLUMN IF NOT EXISTS safety_alerts JSONB;
-- Format: [{"type": "deviation", "timestamp": "...", "distance_meters": 150, "resolved": false}]

ALTER TABLE session_location_tracking ADD COLUMN IF NOT EXISTS emergency_triggered BOOLEAN DEFAULT false;
ALTER TABLE session_location_tracking ADD COLUMN IF NOT EXISTS emergency_triggered_at TIMESTAMPTZ;
ALTER TABLE session_location_tracking ADD COLUMN IF NOT EXISTS emergency_contacts_notified TEXT[];
```

**Code Structure:**
```dart
// Enhance SessionSafetyService
class SessionSafetyService {
  // Monitor location for safety
  static Future<void> startSafetyMonitoring(String sessionId);
  
  // Check for safety issues
  static Future<void> checkSafetyStatus(String sessionId);
  
  // Trigger emergency
  static Future<void> triggerEmergency({
    required String sessionId,
    required String userId,
    required String reason,
  });
  
  // Notify emergency contacts
  static Future<void> notifyEmergencyContacts(String sessionId);
}
```

---

## 📋 FEEDBACK FORM & COMPLETION RULES

### Tutor assessment (learner growth & quality) – already in place for online and onsite

**This is separate from session tracking.** Tutor feedback at/after the session is an **assessment of learner growth and quality** (what was covered, progress, homework, next focus, engagement). It applies to **both online and onsite** sessions.

**Current implementation:**
- **Database:** `session_feedback` has: `tutor_notes`, `tutor_progress_notes`, `tutor_homework_assigned`, `tutor_next_focus_areas`, `tutor_student_engagement` (1–5). Same schema for online and onsite.
- **At end of session:** When the tutor taps “End Session”, they can add optional **notes** (one field). The lifecycle service also accepts `progressNotes`, `homeworkAssigned`, `nextFocusAreas`, `studentEngagement` and saves them to `session_feedback` when provided.
- **After session (feedback flow):** The **Session Feedback Flow** (`SessionFeedbackFlowScreen`) is available to the tutor (and student/parent) from Past Sessions. When the **tutor** submits, they can provide: rating, what was taught, **learner progress**, **homework assigned**, **next focus areas**, **student engagement** (1–5), and concerns. That is the full assessment for growth and quality.
- **Where it’s used:** `SessionLifecycleService.endSession()` and `SessionFeedbackService.submitStudentFeedback()` (tutor branch) both write to `session_feedback`. No distinction by session type (online vs onsite).

So **yes, we are already doing** tutor assessment for learner growth and quality for both online and onsite. The only UX gap: at the moment they tap “End Session” we only show a single “notes” field; the full assessment (progress, homework, next focus, engagement) is collected in the **post-session feedback flow**. Enhancing the “End Session” dialog to include those fields (or a short “Assessment” step) would make it easier to capture at end-of-session without relying on the later feedback flow.

---

### Feedback Form Enhancement (Session Survey)

**Current:** Session feedback already allows **parent or student** to submit rating, review, what went well, what could improve. Tutor can submit tutor notes, progress notes, homework, next focus, engagement (see above).

**Add for onsite (and optionally all sessions):**

1. **Explicit confirmation (family side)**
   - One question: **“Did this session take place as scheduled?”**
     - **Yes** – Session happened as planned  
     - **No** – Session did not happen (e.g. tutor didn’t show, wrong time)  
     - **Partially** – Session happened but with issues (e.g. late, short, different location)
   - If **No** or **Partially**, require a short reason (e.g. “Tutor didn’t show”, “Started 30 min late”).
   - Backend: store as `session_took_place` (yes / no / partially) and `session_took_place_reason` (optional). Use for flags and payment rules.

2. **Multi-learner (parent books for several children)**
   - If session has multiple learners (from `learner_labels`), add: **“Which learners attended this session?”** (checkboxes: list of learner names).
   - Use for attendance and payment (e.g. only pay for learners who attended, if we support partial attendance).

3. **Optional “What was covered?”**
   - Optional free text: “Briefly, what was covered or what did the learner work on?” – helps cross-check with tutor notes and supports disputes.

**Who submits feedback:**  
- **Parent** can submit on behalf of the family (typical when parent books for student and student has no phone).  
- **Student** can submit if they have app access.  
- One submission per session from “family side” (parent or student); tutor submission is separate (tutor notes).

### Completion & Payment Rules (Smart Defaults)

**Session counts as “completed” for payment when:**

1. **Tutor has checked in** (location verified at session start), and  
2. **Tutor has ended the session** (session_end, duration recorded), and  
3. **Either:**
   - **Option A:** Parent or student submitted feedback and answered “Did this session take place?” = **Yes**, or  
   - **Option B:** No feedback submitted within **X days** (e.g. 7 days) and **no dispute** (no “No” or “Partially” with reason).

**Dispute handling:**

- If parent/student submits **“Did this session take place?” = No (or Partially)** with a reason (e.g. “Tutor didn’t show”):
  - **Flag for admin review** (even if tutor had check-in).
  - **Optionally hold or reverse payment** until resolved.
  - Admin can compare: tutor check-in time/location vs feedback reason, and decide.

**Summary:**  
We **focus mainly on the tutor** (check-in, end session, optional continuous monitoring and selfie). We use **feedback from student or parent** as the family-side confirmation and dispute signal. The system is **smart** in that it does not require the parent to be present or the student to have a phone at session time; it only requires the tutor to verify and the family to have the option to confirm or dispute later via the session survey/feedback form.

---

## ⚠️ LIMITATIONS, ADMIN ROLE & SCALE

### Plan limitations (what we don’t promise)

- **We do not guarantee someone is “there” in real time.** Admin is **not** required to watch or monitor every session live. The system runs without an admin present.
- **Continuous location is best-effort.** If the tutor closes the app, we only have check-in + check-out. We don’t penalize; we just don’t have a full trail for that session.
- **Face verification can have false rejections.** We need a fallback (e.g. retry, manual override, or skip for that session) so one bad photo doesn’t block a valid session.
- **Disputes need human judgment.** Automation **flags** issues; it doesn’t decide outcomes. Admin (or support) resolves disputes using the evidence we store.

So: **we can say we don’t have to be there now, and things still go as planned** — because completion and payment are driven by **automated rules** (check-in, end session, feedback or timeout). Admin steps in only when something is **flagged**.

---

### Role of the admin

| Question | Answer |
|----------|--------|
| **Must admin be “there” during sessions?** | **No.** Admin does **not** monitor every session in real time. |
| **What does admin do?** | **Exception-based oversight.** Admin reviews only when the system **flags** something. |
| **When does a session complete without admin?** | When: tutor checked in + tutor ended session + (family said “session took place” OR no dispute within X days). **Fully automated.** |
| **When does admin get involved?** | Only when: (1) **Dispute** – family says “session didn’t take place” or “partially”; (2) **Location deviation** – e.g. report/digest after session; (3) **Safety alert** – emergency or escalation; (4) **Escalation** – user contacts support, or recurring issues (e.g. same tutor many deviations). |

**Summary:** Admin is **not** in the critical path for “all still goes as planned.” The default path is automated. Admin handles **exceptions** and **edge cases**.

---

### Do we review every session manually every day?

**No.** We do **not** manually review every session.

- **Automated rules** handle completion and payment: check-in + end session + (positive feedback or no dispute within X days) → session completed, payment released. No human in the loop.
- **Manual review** happens only for:
  1. **Flagged disputes** – e.g. “Session didn’t take place” or “Partially” with reason.
  2. **Location deviation summaries** – e.g. daily digest of sessions with deviations (admin can triage, not open every session).
  3. **Safety alerts** – emergency or safety-related flags.
  4. **Recurring issues** – e.g. same tutor repeatedly with deviations or failed verifications.

So admin workload scales with **number of exceptions**, not with **total number of sessions**.

---

### What happens if we scale to 10,000 sessions per day?

| Area | At 10k sessions/day |
|------|----------------------|
| **Completion & payment** | Still **fully automated**. Same rules: check-in + end session + feedback or timeout. No change. |
| **Admin review workload** | Only **exceptions**. If e.g. 2% need review (200/day), that’s the queue—not 10,000. Admin sees a **list of flagged items**, not every session. |
| **Infrastructure** | Location history, face checks, activity data grow with volume. Design for: batch processing, retention (e.g. 90 days detail then aggregate), and indexed queries so dashboards and reports stay fast. |
| **Dashboards** | Admin sees **aggregates** (sessions completed, deviation rate, dispute rate) and **queues** (e.g. “Disputes to resolve”, “Sessions with location deviations”). Not a scrollable list of 10,000 sessions. |
| **Optional quality/audit** | If desired: “Review 1% of sessions at random” or “Review all sessions for new tutors for first N sessions”—still a **bounded** number (e.g. 100 random + 50 new-tutor sessions per day). |

**Bottom line:** You do **not** need to review every session. The system is built so that **most sessions complete and get paid automatically**, and admin focuses on **flagged items only**. At 10k sessions/day, that remains true as long as exception rates stay in a reasonable range (e.g. single-digit %).

---

## 🗄️ DATABASE MIGRATION

### Migration File: `058_onsite_tracking_improvements.sql`

```sql
-- ======================================================
-- MIGRATION 058: Onsite Session Tracking Improvements
-- Continuous monitoring, biometric verification, activity tracking
-- ======================================================

-- 1. Enhance session_attendance table
ALTER TABLE public.session_attendance
  ADD COLUMN IF NOT EXISTS location_history JSONB,
  ADD COLUMN IF NOT EXISTS location_deviations JSONB,
  ADD COLUMN IF NOT EXISTS last_location_check TIMESTAMPTZ,
  ADD COLUMN IF NOT EXISTS location_check_count INT DEFAULT 0,
  ADD COLUMN IF NOT EXISTS check_in_photo_url TEXT,
  ADD COLUMN IF NOT EXISTS check_in_face_verification JSONB,
  ADD COLUMN IF NOT EXISTS periodic_face_checks JSONB,
  ADD COLUMN IF NOT EXISTS face_verification_required BOOLEAN DEFAULT false,
  ADD COLUMN IF NOT EXISTS face_verification_passed BOOLEAN DEFAULT false;

COMMENT ON COLUMN public.session_attendance.location_history IS 'Array of location checks during session: [{"timestamp": "...", "lat": 4.0511, "lon": 9.7679, "distance_meters": 15}]';
COMMENT ON COLUMN public.session_attendance.location_deviations IS 'Array of location deviations: [{"timestamp": "...", "distance_meters": 150, "resolved": false}]';
COMMENT ON COLUMN public.session_attendance.check_in_photo_url IS 'URL of check-in photo: tutor + student(s) in frame (presence proof). Tutor takes on their device.';
COMMENT ON COLUMN public.session_attendance.check_in_face_verification IS 'Optional tutor identity: {"confidence": 0.95, "verified": true, "timestamp": "..."} from comparing selfie to profile.';
COMMENT ON COLUMN public.session_attendance.periodic_face_checks IS 'Optional; no mid-session prompts by default. [{"timestamp": "...", "confidence": 0.92, "verified": true}]';

-- 2. Create session_activity_verification table
CREATE TABLE IF NOT EXISTS public.session_activity_verification (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  session_id UUID NOT NULL REFERENCES public.individual_sessions(id) ON DELETE CASCADE,
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  user_type TEXT NOT NULL CHECK (user_type IN ('tutor', 'student')),
  
  -- Activity Evidence
  session_notes TEXT,
  work_photos TEXT[], -- Array of photo URLs
  whiteboard_photo_url TEXT,
  summary TEXT,
  
  -- Verification
  submitted_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  verified BOOLEAN DEFAULT false,
  verification_notes TEXT,
  
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_session_activity_session ON public.session_activity_verification(session_id);
CREATE INDEX IF NOT EXISTS idx_session_activity_user ON public.session_activity_verification(user_id);
CREATE INDEX IF NOT EXISTS idx_session_activity_verified ON public.session_activity_verification(verified);

-- Enable RLS
ALTER TABLE public.session_activity_verification ENABLE ROW LEVEL SECURITY;

-- RLS Policies
CREATE POLICY "Users can view their own activity verification"
  ON public.session_activity_verification
  FOR SELECT
  USING (auth.uid() = user_id);

CREATE POLICY "Users can insert their own activity verification"
  ON public.session_activity_verification
  FOR INSERT
  WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update their own activity verification"
  ON public.session_activity_verification
  FOR UPDATE
  USING (auth.uid() = user_id);

-- 3. Enhance session_location_tracking table
ALTER TABLE public.session_location_tracking
  ADD COLUMN IF NOT EXISTS safety_alerts JSONB,
  ADD COLUMN IF NOT EXISTS emergency_triggered BOOLEAN DEFAULT false,
  ADD COLUMN IF NOT EXISTS emergency_triggered_at TIMESTAMPTZ,
  ADD COLUMN IF NOT EXISTS emergency_contacts_notified TEXT[];

COMMENT ON COLUMN public.session_location_tracking.safety_alerts IS 'Array of safety alerts: [{"type": "deviation", "timestamp": "...", "distance_meters": 150, "resolved": false}]';

-- 4. Add face verification to parent_learners
ALTER TABLE public.parent_learners
  ADD COLUMN IF NOT EXISTS profile_photo_url TEXT,
  ADD COLUMN IF NOT EXISTS face_id TEXT;

COMMENT ON COLUMN public.parent_learners.face_id IS 'Face recognition ID for biometric verification';

-- 5. Create indexes for performance
CREATE INDEX IF NOT EXISTS idx_session_attendance_location_check ON public.session_attendance(last_location_check);
CREATE INDEX IF NOT EXISTS idx_session_attendance_face_verified ON public.session_attendance(face_verification_passed);
```

---

## 📱 UI/UX IMPROVEMENTS

### 1. Enhanced Check-In Flow
```
Current: Simple "Check In" button
New: Multi-step verification:
  1. Location verification (GPS)
  2. Face verification (selfie with liveness)
  3. Confirmation screen
```

### 2. Continuous Monitoring UI
```
- Show "Session Active" indicator
- Display last location check time
- Show location status (at location / deviated)
- Alert banner if deviation detected
```

### 3. Activity Submission UI
```
- "Submit Session Activity" button (tutor)
- "Submit Learning Summary" button (student)
- Photo upload for work/whiteboard
- Notes/summary text input
```

### 4. Safety Features UI
```
- Panic button (always visible during session)
- Location sharing status
- Emergency contacts display
- Safety alerts banner
```

---

## 🔧 IMPLEMENTATION CHECKLIST

### Week 1: Continuous Location Monitoring
- [ ] Create `ContinuousLocationMonitoringService`
- [ ] Implement periodic location checks (every 5-10 min)
- [ ] Add location deviation detection
- [ ] Store location history in database
- [ ] Add UI for location status
- [ ] Test location monitoring

### Week 2: Biometric Verification
- [ ] Set up AWS Rekognition (or alternative)
- [ ] Create `FaceVerificationService`
- [ ] Add check-in group photo (tutor + student(s)) – presence proof
- [ ] (Optional) Implement tutor face verification vs profile (e.g. Rekognition)
- [ ] Add face/photo verification UI (check-in only; no mid-session prompts)
- [ ] Test face verification

### Week 3: Activity Verification
- [ ] Create `SessionActivityVerificationService`
- [ ] Add activity submission UI
- [ ] Implement photo upload for work/whiteboard
- [ ] Add notes/summary submission
- [ ] Verify activity timing
- [ ] Test activity verification

### Week 4: Multi-Learner Tracking
- [ ] Enhance check-in for multiple learners
- [ ] Add group photo verification
- [ ] Individual face verification per learner
- [ ] Individual location tracking
- [ ] Test multi-learner scenarios

### Week 5-6: Safety Monitoring
- [ ] Enhance `SessionSafetyService`
- [ ] Implement real-time location monitoring
- [ ] Add panic button functionality
- [ ] Emergency contact notification
- [ ] Safety alerts system
- [ ] Test safety features

---

## 💰 COST ESTIMATES

### Face / photo verification
- **Group selfie only (no face-matching):** No API cost; just photo storage.
- **Tutor identity (Rekognition):** ~$0.001 per check-in comparison. Optional; only if you use tutor selfie vs profile.

### Location Tracking
- GPS tracking: Free (device native)
- Background location: Minimal battery impact
- Storage: Negligible (JSONB)

### Photo Storage
- Supabase Storage: ~$0.021 per GB
- Estimated: 2-5 photos per session (~5MB)
- Monthly (1000 sessions): ~$0.10-0.25

### Total Additional Cost
- **Per Session:** ~$0.002-0.003
- **Monthly (1000 sessions):** ~$2-3
- **Monthly (10,000 sessions):** ~$20-30

**Very affordable!** ✅

---

## 🎯 SUCCESS METRICS

### Verification Rate
- **Target:** 95%+ sessions with verified check-in
- **Target:** 90%+ sessions with face verification passed
- **Target:** 85%+ sessions with activity submitted

### Fraud Prevention
- **Target:** 0% fake check-ins (location verified)
- **Target:** 0% identity fraud (face verified)
- **Target:** <5% sessions with location deviations

### Safety
- **Target:** <1% sessions with safety alerts
- **Target:** 100% emergency response time <2 minutes
- **Target:** 0% safety incidents

---

## 📁 MIGRATIONS TO RUN

| Migration | Purpose | Status |
|-----------|---------|--------|
| **056_abandoned_bookings_tracking.sql** | Abandoned bookings tracking | ✅ Exists in repo – run if not yet applied |
| **057_per_learner_acceptance_status.sql** | Per-learner accept/decline for multi-learner requests | ✅ Exists in repo – run if not yet applied |
| **058_onsite_tracking_improvements.sql** | Onsite tracking: location_history, deviations, check-in photo/face, session_activity_verification, safety fields | ❌ **Not yet a file** – create from the migration spec in this document (see “DATABASE MIGRATION” section) when you start implementing onsite tracking, then run it |

**If you’ve already run 056 and 057:** You’re up to date for existing features. Run **058** only after you create the file from the plan and are ready to implement Phase 1–5.

**How to run (Supabase):** `supabase db push` or apply the migration SQL in the Supabase dashboard / CLI.

---

## 🚀 NEXT STEPS

1. **Review and approve plan**
2. **Create migration 058** from the “DATABASE MIGRATION” section when starting onsite implementation (optional: set up Rekognition only if using tutor identity verification)
3. **Start Phase 1** (Continuous Location Monitoring)
4. **Test with pilot users**
5. **Iterate based on feedback**

---

**Ready to start implementation?** Let me know which phase you'd like to begin with!
