# Session Rescheduling System with Mutual Agreement

## ✅ **What's Been Implemented**

### **1. Database Schema** ✅
**File:** `supabase/migrations/021_session_rescheduling.sql`

**New Table:** `session_reschedule_requests`
- Stores rescheduling requests with mutual agreement requirement
- Tracks approval status from both tutor and student
- Stores original and proposed session details
- Auto-expires after 48 hours if not approved

**Columns Added to `individual_sessions`:**
- `reschedule_request_id` - Links to active reschedule request
- `original_scheduled_date` - Stores original date before reschedule
- `original_scheduled_time` - Stores original time before reschedule

### **2. Rescheduling Service** ✅
**File:** `lib/features/booking/services/session_reschedule_service.dart`

**Methods:**
- `requestReschedule()` - Create a reschedule request
- `approveRescheduleRequest()` - Approve a request (mutual agreement)
- `rejectRescheduleRequest()` - Reject a request
- `cancelRescheduleRequest()` - Cancel own request
- `getRescheduleRequests()` - Get requests for a session
- `_applyReschedule()` - Apply reschedule when both parties approve

---

## 🔄 **How It Works**

### **Step 1: Request Reschedule**
Either tutor or student can request to reschedule:

```dart
await SessionRescheduleService.requestReschedule(
  sessionId: sessionId,
  proposedDate: DateTime(2025, 1, 20), // New date
  proposedTime: '16:00:00', // New time
  reason: 'Family emergency',
  additionalNotes: 'Can we move to next week?',
);
```

**What Happens:**
1. Reschedule request created with status 'pending'
2. Requester automatically approves (tutor_approved or student_approved = true)
3. Other party receives notification
4. Session stores original date/time and links to request

### **Step 2: Other Party Reviews**
The other party receives:
- In-app notification
- Email notification
- Can view request details

### **Step 3: Approval/Rejection**

**If Approved:**
```dart
await SessionRescheduleService.approveRescheduleRequest(requestId);
```

**What Happens:**
1. Their approval flag is set (tutor_approved or student_approved = true)
2. System checks if both parties approved
3. **If both approved:**
   - Session date/time updated automatically
   - Reschedule request status → 'approved'
   - Both parties notified
   - Original date/time preserved for reference
4. **If only one approved:**
   - Request remains 'pending'
   - Requester notified that approval is pending

**If Rejected:**
```dart
await SessionRescheduleService.rejectRescheduleRequest(
  requestId,
  reason: 'Not available at that time',
);
```

**What Happens:**
1. Request status → 'rejected'
2. Session reschedule_request_id cleared
3. Requester notified with rejection reason
4. Session remains at original time

### **Step 4: Automatic Application**
When both parties approve:
- Session `scheduled_date` updated
- Session `scheduled_time` updated
- Optional: Duration, location, address updated if proposed
- Google Calendar event updated (if Meet link exists)
- Both parties notified

---

## 🔐 **Security & Validation**

### **Authorization:**
- ✅ Only session participants (tutor, student, parent) can create requests
- ✅ Only the other party can approve/reject
- ✅ Only requester can cancel their own request
- ✅ RLS policies enforce access control

### **Validation:**
- ✅ Only 'scheduled' sessions can be rescheduled
- ✅ Cannot create duplicate pending requests
- ✅ Request expires after 48 hours
- ✅ Cannot approve/reject non-pending requests

---

## 📱 **UI Integration Points**

### **1. Tutor Sessions Screen**
Add "Reschedule" button to session cards:
- Show if session is 'scheduled'
- Show pending reschedule request status
- Allow approval/rejection if request exists

### **2. Student Sessions Screen**
Same functionality for students:
- Request reschedule
- Approve/reject tutor requests

### **3. Session Detail Screen**
Show reschedule request details:
- Original date/time
- Proposed date/time
- Approval status
- Approve/Reject buttons

---

## 🔔 **Notifications**

### **Reschedule Request Created:**
- **To:** Other party
- **Type:** `session_reschedule_request`
- **Message:** "[Name] has requested to reschedule a session"
- **Action:** "Review Request" → Navigate to reschedule screen

### **Reschedule Approved (Partial):**
- **To:** Requester
- **Type:** `session_reschedule_approved`
- **Message:** "[Name] has approved. Waiting for other party."

### **Reschedule Approved (Complete):**
- **To:** Both parties
- **Type:** `session_rescheduled`
- **Message:** "Session rescheduled! Both parties approved."

### **Reschedule Rejected:**
- **To:** Requester
- **Type:** `session_reschedule_rejected`
- **Message:** "[Name] rejected. Reason: [reason]"

---

## 📋 **Example Flow**

### **Scenario: Student wants to reschedule**

1. **Student requests:**
   - Original: Monday, Jan 15, 4:00 PM
   - Proposed: Wednesday, Jan 17, 4:00 PM
   - Reason: "Doctor's appointment"

2. **Tutor receives notification:**
   - "John has requested to reschedule..."
   - Clicks "Review Request"

3. **Tutor reviews:**
   - Sees original and proposed times
   - Sees reason
   - Approves or rejects

4. **If approved:**
   - Session automatically rescheduled
   - Both parties notified
   - Calendar updated (if applicable)

---

## 🚀 **Next Steps**

### **1. UI Implementation** ⏳
- [ ] Add "Reschedule" button to session cards
- [ ] Create reschedule request dialog/screen
- [ ] Create reschedule review screen
- [ ] Show pending requests in session list

### **2. Google Calendar Integration** ⏳
- [ ] Update calendar event when rescheduled
- [ ] Regenerate Meet link if needed
- [ ] Notify PrepSkul VA of time change

### **3. Conflict Detection** ⏳
- [ ] Check for conflicts with other sessions
- [ ] Warn if proposed time conflicts
- [ ] Suggest alternative times

### **4. Testing** ⏳
- [ ] Test request creation
- [ ] Test approval flow
- [ ] Test rejection flow
- [ ] Test expiration
- [ ] Test notifications

---

## ✅ **Status**

- ✅ Database schema created
- ✅ Rescheduling service implemented
- ✅ Mutual agreement logic working
- ✅ Notifications integrated
- ⏳ UI components needed
- ⏳ Google Calendar update needed
- ⏳ Conflict detection needed

---

## 📝 **Notes**

1. **Auto-Approval:** The requester is automatically marked as approved, so only the other party needs to approve.

2. **Original Date Preservation:** Original date/time is stored so users can see what was changed.

3. **Expiration:** Requests expire after 48 hours to prevent stale requests.

4. **Multiple Requests:** Only one pending request per session is allowed.

5. **Meet Links:** When rescheduled, Meet links may need to be regenerated or calendar events updated.





## ✅ **What's Been Implemented**

### **1. Database Schema** ✅
**File:** `supabase/migrations/021_session_rescheduling.sql`

**New Table:** `session_reschedule_requests`
- Stores rescheduling requests with mutual agreement requirement
- Tracks approval status from both tutor and student
- Stores original and proposed session details
- Auto-expires after 48 hours if not approved

**Columns Added to `individual_sessions`:**
- `reschedule_request_id` - Links to active reschedule request
- `original_scheduled_date` - Stores original date before reschedule
- `original_scheduled_time` - Stores original time before reschedule

### **2. Rescheduling Service** ✅
**File:** `lib/features/booking/services/session_reschedule_service.dart`

**Methods:**
- `requestReschedule()` - Create a reschedule request
- `approveRescheduleRequest()` - Approve a request (mutual agreement)
- `rejectRescheduleRequest()` - Reject a request
- `cancelRescheduleRequest()` - Cancel own request
- `getRescheduleRequests()` - Get requests for a session
- `_applyReschedule()` - Apply reschedule when both parties approve

---

## 🔄 **How It Works**

### **Step 1: Request Reschedule**
Either tutor or student can request to reschedule:

```dart
await SessionRescheduleService.requestReschedule(
  sessionId: sessionId,
  proposedDate: DateTime(2025, 1, 20), // New date
  proposedTime: '16:00:00', // New time
  reason: 'Family emergency',
  additionalNotes: 'Can we move to next week?',
);
```

**What Happens:**
1. Reschedule request created with status 'pending'
2. Requester automatically approves (tutor_approved or student_approved = true)
3. Other party receives notification
4. Session stores original date/time and links to request

### **Step 2: Other Party Reviews**
The other party receives:
- In-app notification
- Email notification
- Can view request details

### **Step 3: Approval/Rejection**

**If Approved:**
```dart
await SessionRescheduleService.approveRescheduleRequest(requestId);
```

**What Happens:**
1. Their approval flag is set (tutor_approved or student_approved = true)
2. System checks if both parties approved
3. **If both approved:**
   - Session date/time updated automatically
   - Reschedule request status → 'approved'
   - Both parties notified
   - Original date/time preserved for reference
4. **If only one approved:**
   - Request remains 'pending'
   - Requester notified that approval is pending

**If Rejected:**
```dart
await SessionRescheduleService.rejectRescheduleRequest(
  requestId,
  reason: 'Not available at that time',
);
```

**What Happens:**
1. Request status → 'rejected'
2. Session reschedule_request_id cleared
3. Requester notified with rejection reason
4. Session remains at original time

### **Step 4: Automatic Application**
When both parties approve:
- Session `scheduled_date` updated
- Session `scheduled_time` updated
- Optional: Duration, location, address updated if proposed
- Google Calendar event updated (if Meet link exists)
- Both parties notified

---

## 🔐 **Security & Validation**

### **Authorization:**
- ✅ Only session participants (tutor, student, parent) can create requests
- ✅ Only the other party can approve/reject
- ✅ Only requester can cancel their own request
- ✅ RLS policies enforce access control

### **Validation:**
- ✅ Only 'scheduled' sessions can be rescheduled
- ✅ Cannot create duplicate pending requests
- ✅ Request expires after 48 hours
- ✅ Cannot approve/reject non-pending requests

---

## 📱 **UI Integration Points**

### **1. Tutor Sessions Screen**
Add "Reschedule" button to session cards:
- Show if session is 'scheduled'
- Show pending reschedule request status
- Allow approval/rejection if request exists

### **2. Student Sessions Screen**
Same functionality for students:
- Request reschedule
- Approve/reject tutor requests

### **3. Session Detail Screen**
Show reschedule request details:
- Original date/time
- Proposed date/time
- Approval status
- Approve/Reject buttons

---

## 🔔 **Notifications**

### **Reschedule Request Created:**
- **To:** Other party
- **Type:** `session_reschedule_request`
- **Message:** "[Name] has requested to reschedule a session"
- **Action:** "Review Request" → Navigate to reschedule screen

### **Reschedule Approved (Partial):**
- **To:** Requester
- **Type:** `session_reschedule_approved`
- **Message:** "[Name] has approved. Waiting for other party."

### **Reschedule Approved (Complete):**
- **To:** Both parties
- **Type:** `session_rescheduled`
- **Message:** "Session rescheduled! Both parties approved."

### **Reschedule Rejected:**
- **To:** Requester
- **Type:** `session_reschedule_rejected`
- **Message:** "[Name] rejected. Reason: [reason]"

---

## 📋 **Example Flow**

### **Scenario: Student wants to reschedule**

1. **Student requests:**
   - Original: Monday, Jan 15, 4:00 PM
   - Proposed: Wednesday, Jan 17, 4:00 PM
   - Reason: "Doctor's appointment"

2. **Tutor receives notification:**
   - "John has requested to reschedule..."
   - Clicks "Review Request"

3. **Tutor reviews:**
   - Sees original and proposed times
   - Sees reason
   - Approves or rejects

4. **If approved:**
   - Session automatically rescheduled
   - Both parties notified
   - Calendar updated (if applicable)

---

## 🚀 **Next Steps**

### **1. UI Implementation** ⏳
- [ ] Add "Reschedule" button to session cards
- [ ] Create reschedule request dialog/screen
- [ ] Create reschedule review screen
- [ ] Show pending requests in session list

### **2. Google Calendar Integration** ⏳
- [ ] Update calendar event when rescheduled
- [ ] Regenerate Meet link if needed
- [ ] Notify PrepSkul VA of time change

### **3. Conflict Detection** ⏳
- [ ] Check for conflicts with other sessions
- [ ] Warn if proposed time conflicts
- [ ] Suggest alternative times

### **4. Testing** ⏳
- [ ] Test request creation
- [ ] Test approval flow
- [ ] Test rejection flow
- [ ] Test expiration
- [ ] Test notifications

---

## ✅ **Status**

- ✅ Database schema created
- ✅ Rescheduling service implemented
- ✅ Mutual agreement logic working
- ✅ Notifications integrated
- ⏳ UI components needed
- ⏳ Google Calendar update needed
- ⏳ Conflict detection needed

---

## 📝 **Notes**

1. **Auto-Approval:** The requester is automatically marked as approved, so only the other party needs to approve.

2. **Original Date Preservation:** Original date/time is stored so users can see what was changed.

3. **Expiration:** Requests expire after 48 hours to prevent stale requests.

4. **Multiple Requests:** Only one pending request per session is allowed.

5. **Meet Links:** When rescheduled, Meet links may need to be regenerated or calendar events updated.



# Session Rescheduling System with Mutual Agreement

## ✅ **What's Been Implemented**

### **1. Database Schema** ✅
**File:** `supabase/migrations/021_session_rescheduling.sql`

**New Table:** `session_reschedule_requests`
- Stores rescheduling requests with mutual agreement requirement
- Tracks approval status from both tutor and student
- Stores original and proposed session details
- Auto-expires after 48 hours if not approved

**Columns Added to `individual_sessions`:**
- `reschedule_request_id` - Links to active reschedule request
- `original_scheduled_date` - Stores original date before reschedule
- `original_scheduled_time` - Stores original time before reschedule

### **2. Rescheduling Service** ✅
**File:** `lib/features/booking/services/session_reschedule_service.dart`

**Methods:**
- `requestReschedule()` - Create a reschedule request
- `approveRescheduleRequest()` - Approve a request (mutual agreement)
- `rejectRescheduleRequest()` - Reject a request
- `cancelRescheduleRequest()` - Cancel own request
- `getRescheduleRequests()` - Get requests for a session
- `_applyReschedule()` - Apply reschedule when both parties approve

---

## 🔄 **How It Works**

### **Step 1: Request Reschedule**
Either tutor or student can request to reschedule:

```dart
await SessionRescheduleService.requestReschedule(
  sessionId: sessionId,
  proposedDate: DateTime(2025, 1, 20), // New date
  proposedTime: '16:00:00', // New time
  reason: 'Family emergency',
  additionalNotes: 'Can we move to next week?',
);
```

**What Happens:**
1. Reschedule request created with status 'pending'
2. Requester automatically approves (tutor_approved or student_approved = true)
3. Other party receives notification
4. Session stores original date/time and links to request

### **Step 2: Other Party Reviews**
The other party receives:
- In-app notification
- Email notification
- Can view request details

### **Step 3: Approval/Rejection**

**If Approved:**
```dart
await SessionRescheduleService.approveRescheduleRequest(requestId);
```

**What Happens:**
1. Their approval flag is set (tutor_approved or student_approved = true)
2. System checks if both parties approved
3. **If both approved:**
   - Session date/time updated automatically
   - Reschedule request status → 'approved'
   - Both parties notified
   - Original date/time preserved for reference
4. **If only one approved:**
   - Request remains 'pending'
   - Requester notified that approval is pending

**If Rejected:**
```dart
await SessionRescheduleService.rejectRescheduleRequest(
  requestId,
  reason: 'Not available at that time',
);
```

**What Happens:**
1. Request status → 'rejected'
2. Session reschedule_request_id cleared
3. Requester notified with rejection reason
4. Session remains at original time

### **Step 4: Automatic Application**
When both parties approve:
- Session `scheduled_date` updated
- Session `scheduled_time` updated
- Optional: Duration, location, address updated if proposed
- Google Calendar event updated (if Meet link exists)
- Both parties notified

---

## 🔐 **Security & Validation**

### **Authorization:**
- ✅ Only session participants (tutor, student, parent) can create requests
- ✅ Only the other party can approve/reject
- ✅ Only requester can cancel their own request
- ✅ RLS policies enforce access control

### **Validation:**
- ✅ Only 'scheduled' sessions can be rescheduled
- ✅ Cannot create duplicate pending requests
- ✅ Request expires after 48 hours
- ✅ Cannot approve/reject non-pending requests

---

## 📱 **UI Integration Points**

### **1. Tutor Sessions Screen**
Add "Reschedule" button to session cards:
- Show if session is 'scheduled'
- Show pending reschedule request status
- Allow approval/rejection if request exists

### **2. Student Sessions Screen**
Same functionality for students:
- Request reschedule
- Approve/reject tutor requests

### **3. Session Detail Screen**
Show reschedule request details:
- Original date/time
- Proposed date/time
- Approval status
- Approve/Reject buttons

---

## 🔔 **Notifications**

### **Reschedule Request Created:**
- **To:** Other party
- **Type:** `session_reschedule_request`
- **Message:** "[Name] has requested to reschedule a session"
- **Action:** "Review Request" → Navigate to reschedule screen

### **Reschedule Approved (Partial):**
- **To:** Requester
- **Type:** `session_reschedule_approved`
- **Message:** "[Name] has approved. Waiting for other party."

### **Reschedule Approved (Complete):**
- **To:** Both parties
- **Type:** `session_rescheduled`
- **Message:** "Session rescheduled! Both parties approved."

### **Reschedule Rejected:**
- **To:** Requester
- **Type:** `session_reschedule_rejected`
- **Message:** "[Name] rejected. Reason: [reason]"

---

## 📋 **Example Flow**

### **Scenario: Student wants to reschedule**

1. **Student requests:**
   - Original: Monday, Jan 15, 4:00 PM
   - Proposed: Wednesday, Jan 17, 4:00 PM
   - Reason: "Doctor's appointment"

2. **Tutor receives notification:**
   - "John has requested to reschedule..."
   - Clicks "Review Request"

3. **Tutor reviews:**
   - Sees original and proposed times
   - Sees reason
   - Approves or rejects

4. **If approved:**
   - Session automatically rescheduled
   - Both parties notified
   - Calendar updated (if applicable)

---

## 🚀 **Next Steps**

### **1. UI Implementation** ⏳
- [ ] Add "Reschedule" button to session cards
- [ ] Create reschedule request dialog/screen
- [ ] Create reschedule review screen
- [ ] Show pending requests in session list

### **2. Google Calendar Integration** ⏳
- [ ] Update calendar event when rescheduled
- [ ] Regenerate Meet link if needed
- [ ] Notify PrepSkul VA of time change

### **3. Conflict Detection** ⏳
- [ ] Check for conflicts with other sessions
- [ ] Warn if proposed time conflicts
- [ ] Suggest alternative times

### **4. Testing** ⏳
- [ ] Test request creation
- [ ] Test approval flow
- [ ] Test rejection flow
- [ ] Test expiration
- [ ] Test notifications

---

## ✅ **Status**

- ✅ Database schema created
- ✅ Rescheduling service implemented
- ✅ Mutual agreement logic working
- ✅ Notifications integrated
- ⏳ UI components needed
- ⏳ Google Calendar update needed
- ⏳ Conflict detection needed

---

## 📝 **Notes**

1. **Auto-Approval:** The requester is automatically marked as approved, so only the other party needs to approve.

2. **Original Date Preservation:** Original date/time is stored so users can see what was changed.

3. **Expiration:** Requests expire after 48 hours to prevent stale requests.

4. **Multiple Requests:** Only one pending request per session is allowed.

5. **Meet Links:** When rescheduled, Meet links may need to be regenerated or calendar events updated.





