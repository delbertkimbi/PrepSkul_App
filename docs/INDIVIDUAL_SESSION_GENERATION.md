# Individual Session Generation

## ✅ **What's Been Implemented**

### **Automatic Individual Session Generation** ✅
**File:** `lib/features/booking/services/recurring_session_service.dart`

**New Method:** `generateIndividualSessions()`

**Features:**
- ✅ Automatically generates individual session instances from recurring sessions
- ✅ Creates sessions for the next 8 weeks (configurable)
- ✅ Respects the recurring session's schedule (days, times, frequency)
- ✅ Prevents duplicate sessions (checks if session already exists)
- ✅ Batch inserts for performance (chunks of 100)
- ✅ Handles time parsing (12-hour format with AM/PM)
- ✅ Sets proper location and address based on recurring session

**When It Runs:**
- ✅ Automatically called when a recurring session is created from an approved booking request
- ✅ Can be manually called to generate more sessions ahead of time

---

## 🔄 **How It Works**

### **Step 1: Recurring Session Created**
When a tutor approves a booking request:
1. `RecurringSessionService.createRecurringSessionFromBooking()` is called
2. Recurring session is created in database
3. **Automatically calls `generateIndividualSessions()`**
4. Individual sessions are generated for the next 8 weeks

### **Step 2: Session Generation Logic**
For each week (up to 8 weeks ahead):
1. Iterate through each day in the schedule (e.g., Monday, Wednesday)
2. Calculate the date for that day in that week
3. Parse the time from the schedule (e.g., "4:00 PM" → 16:00)
4. Check if session already exists (prevents duplicates)
5. Create session data with:
   - Recurring session ID
   - Tutor and student IDs
   - Subject (from booking request)
   - Scheduled date and time
   - Duration (default 60 minutes)
   - Location and address
   - Status: 'scheduled'

### **Step 3: Batch Insert**
- Sessions are collected in a list
- Inserted in batches of 100 to avoid payload limits
- All sessions created atomically

---

## 📋 **Example**

### **Recurring Session:**
- **Days:** Monday, Wednesday
- **Times:** Monday: "4:00 PM", Wednesday: "4:00 PM"
- **Frequency:** 2 sessions per week
- **Start Date:** January 15, 2025

### **Generated Individual Sessions:**
1. **Week 1:**
   - Monday, Jan 15, 2025 at 4:00 PM
   - Wednesday, Jan 17, 2025 at 4:00 PM

2. **Week 2:**
   - Monday, Jan 22, 2025 at 4:00 PM
   - Wednesday, Jan 24, 2025 at 4:00 PM

3. **Week 3-8:** Continue pattern...

**Total:** 16 individual sessions (2 sessions/week × 8 weeks)

---

## 🔧 **Configuration**

### **Default Settings:**
- **Weeks Ahead:** 8 weeks (configurable)
- **Duration:** 60 minutes (can be made configurable per recurring session)
- **Batch Size:** 100 sessions per insert

### **To Generate More Sessions:**
```dart
// Generate sessions for next 12 weeks
await RecurringSessionService.generateIndividualSessions(
  recurringSessionId: sessionId,
  weeksAhead: 12,
);
```

---

## ⚙️ **Integration Points**

### **1. Booking Approval Flow**
**File:** `lib/features/booking/screens/tutor_booking_detail_screen.dart`

When tutor approves a booking:
1. `RecurringSessionService.createRecurringSessionFromBooking()` is called
2. Recurring session created
3. Individual sessions automatically generated
4. Tutor can immediately see upcoming sessions

### **2. Tutor Sessions Screen**
**File:** `lib/features/tutor/screens/tutor_sessions_screen.dart`

The screen already loads individual sessions:
- `IndividualSessionService.getTutorUpcomingSessions()` - Shows upcoming sessions
- `IndividualSessionService.getTutorPastSessions()` - Shows past sessions

Now these will be populated automatically!

### **3. Session Management**
- Tutors can start/end individual sessions
- Sessions can be cancelled or rescheduled
- Status tracking (scheduled → in_progress → completed)

---

## 🚀 **Next Steps**

### **1. Cron Job for Ongoing Generation** ⏳
Create a scheduled job to generate more sessions as time passes:
- Run weekly to generate next week's sessions
- Ensure sessions are always available 8 weeks ahead
- Can be implemented in Next.js as a cron job

### **2. Dynamic Duration** ⏳
Make session duration configurable:
- Add `duration_minutes` to `recurring_sessions` table
- Use that value when generating individual sessions
- Default to 60 minutes if not specified

### **3. Rescheduling Support** ⏳
When a session is rescheduled:
- Update the individual session's date/time
- Regenerate if needed
- Handle conflicts

### **4. Testing** ⏳
- Test with different schedules (daily, weekly, multiple days)
- Test with different time formats
- Test duplicate prevention
- Test batch insertion with large numbers

---

## ✅ **Status**

- ✅ Automatic generation implemented
- ✅ Called automatically on recurring session creation
- ✅ Prevents duplicates
- ✅ Batch insertion for performance
- ⏳ Needs cron job for ongoing generation
- ⏳ Needs testing with real data

---

## 📝 **Notes**

1. **Time Parsing:** Currently handles 12-hour format with AM/PM. May need enhancement for 24-hour format or other formats.

2. **Subject:** Tries to get subject from booking request. Falls back to "Tutoring Session" if not available.

3. **Location:** Hybrid sessions default to "online" for individual sessions. Onsite address is preserved.

4. **Performance:** Batch insertion in chunks of 100 prevents payload size issues with large schedules.

5. **Future Enhancement:** Consider generating sessions on-demand (lazy generation) instead of all at once for very long-term recurring sessions.





## ✅ **What's Been Implemented**

### **Automatic Individual Session Generation** ✅
**File:** `lib/features/booking/services/recurring_session_service.dart`

**New Method:** `generateIndividualSessions()`

**Features:**
- ✅ Automatically generates individual session instances from recurring sessions
- ✅ Creates sessions for the next 8 weeks (configurable)
- ✅ Respects the recurring session's schedule (days, times, frequency)
- ✅ Prevents duplicate sessions (checks if session already exists)
- ✅ Batch inserts for performance (chunks of 100)
- ✅ Handles time parsing (12-hour format with AM/PM)
- ✅ Sets proper location and address based on recurring session

**When It Runs:**
- ✅ Automatically called when a recurring session is created from an approved booking request
- ✅ Can be manually called to generate more sessions ahead of time

---

## 🔄 **How It Works**

### **Step 1: Recurring Session Created**
When a tutor approves a booking request:
1. `RecurringSessionService.createRecurringSessionFromBooking()` is called
2. Recurring session is created in database
3. **Automatically calls `generateIndividualSessions()`**
4. Individual sessions are generated for the next 8 weeks

### **Step 2: Session Generation Logic**
For each week (up to 8 weeks ahead):
1. Iterate through each day in the schedule (e.g., Monday, Wednesday)
2. Calculate the date for that day in that week
3. Parse the time from the schedule (e.g., "4:00 PM" → 16:00)
4. Check if session already exists (prevents duplicates)
5. Create session data with:
   - Recurring session ID
   - Tutor and student IDs
   - Subject (from booking request)
   - Scheduled date and time
   - Duration (default 60 minutes)
   - Location and address
   - Status: 'scheduled'

### **Step 3: Batch Insert**
- Sessions are collected in a list
- Inserted in batches of 100 to avoid payload limits
- All sessions created atomically

---

## 📋 **Example**

### **Recurring Session:**
- **Days:** Monday, Wednesday
- **Times:** Monday: "4:00 PM", Wednesday: "4:00 PM"
- **Frequency:** 2 sessions per week
- **Start Date:** January 15, 2025

### **Generated Individual Sessions:**
1. **Week 1:**
   - Monday, Jan 15, 2025 at 4:00 PM
   - Wednesday, Jan 17, 2025 at 4:00 PM

2. **Week 2:**
   - Monday, Jan 22, 2025 at 4:00 PM
   - Wednesday, Jan 24, 2025 at 4:00 PM

3. **Week 3-8:** Continue pattern...

**Total:** 16 individual sessions (2 sessions/week × 8 weeks)

---

## 🔧 **Configuration**

### **Default Settings:**
- **Weeks Ahead:** 8 weeks (configurable)
- **Duration:** 60 minutes (can be made configurable per recurring session)
- **Batch Size:** 100 sessions per insert

### **To Generate More Sessions:**
```dart
// Generate sessions for next 12 weeks
await RecurringSessionService.generateIndividualSessions(
  recurringSessionId: sessionId,
  weeksAhead: 12,
);
```

---

## ⚙️ **Integration Points**

### **1. Booking Approval Flow**
**File:** `lib/features/booking/screens/tutor_booking_detail_screen.dart`

When tutor approves a booking:
1. `RecurringSessionService.createRecurringSessionFromBooking()` is called
2. Recurring session created
3. Individual sessions automatically generated
4. Tutor can immediately see upcoming sessions

### **2. Tutor Sessions Screen**
**File:** `lib/features/tutor/screens/tutor_sessions_screen.dart`

The screen already loads individual sessions:
- `IndividualSessionService.getTutorUpcomingSessions()` - Shows upcoming sessions
- `IndividualSessionService.getTutorPastSessions()` - Shows past sessions

Now these will be populated automatically!

### **3. Session Management**
- Tutors can start/end individual sessions
- Sessions can be cancelled or rescheduled
- Status tracking (scheduled → in_progress → completed)

---

## 🚀 **Next Steps**

### **1. Cron Job for Ongoing Generation** ⏳
Create a scheduled job to generate more sessions as time passes:
- Run weekly to generate next week's sessions
- Ensure sessions are always available 8 weeks ahead
- Can be implemented in Next.js as a cron job

### **2. Dynamic Duration** ⏳
Make session duration configurable:
- Add `duration_minutes` to `recurring_sessions` table
- Use that value when generating individual sessions
- Default to 60 minutes if not specified

### **3. Rescheduling Support** ⏳
When a session is rescheduled:
- Update the individual session's date/time
- Regenerate if needed
- Handle conflicts

### **4. Testing** ⏳
- Test with different schedules (daily, weekly, multiple days)
- Test with different time formats
- Test duplicate prevention
- Test batch insertion with large numbers

---

## ✅ **Status**

- ✅ Automatic generation implemented
- ✅ Called automatically on recurring session creation
- ✅ Prevents duplicates
- ✅ Batch insertion for performance
- ⏳ Needs cron job for ongoing generation
- ⏳ Needs testing with real data

---

## 📝 **Notes**

1. **Time Parsing:** Currently handles 12-hour format with AM/PM. May need enhancement for 24-hour format or other formats.

2. **Subject:** Tries to get subject from booking request. Falls back to "Tutoring Session" if not available.

3. **Location:** Hybrid sessions default to "online" for individual sessions. Onsite address is preserved.

4. **Performance:** Batch insertion in chunks of 100 prevents payload size issues with large schedules.

5. **Future Enhancement:** Consider generating sessions on-demand (lazy generation) instead of all at once for very long-term recurring sessions.



# Individual Session Generation

## ✅ **What's Been Implemented**

### **Automatic Individual Session Generation** ✅
**File:** `lib/features/booking/services/recurring_session_service.dart`

**New Method:** `generateIndividualSessions()`

**Features:**
- ✅ Automatically generates individual session instances from recurring sessions
- ✅ Creates sessions for the next 8 weeks (configurable)
- ✅ Respects the recurring session's schedule (days, times, frequency)
- ✅ Prevents duplicate sessions (checks if session already exists)
- ✅ Batch inserts for performance (chunks of 100)
- ✅ Handles time parsing (12-hour format with AM/PM)
- ✅ Sets proper location and address based on recurring session

**When It Runs:**
- ✅ Automatically called when a recurring session is created from an approved booking request
- ✅ Can be manually called to generate more sessions ahead of time

---

## 🔄 **How It Works**

### **Step 1: Recurring Session Created**
When a tutor approves a booking request:
1. `RecurringSessionService.createRecurringSessionFromBooking()` is called
2. Recurring session is created in database
3. **Automatically calls `generateIndividualSessions()`**
4. Individual sessions are generated for the next 8 weeks

### **Step 2: Session Generation Logic**
For each week (up to 8 weeks ahead):
1. Iterate through each day in the schedule (e.g., Monday, Wednesday)
2. Calculate the date for that day in that week
3. Parse the time from the schedule (e.g., "4:00 PM" → 16:00)
4. Check if session already exists (prevents duplicates)
5. Create session data with:
   - Recurring session ID
   - Tutor and student IDs
   - Subject (from booking request)
   - Scheduled date and time
   - Duration (default 60 minutes)
   - Location and address
   - Status: 'scheduled'

### **Step 3: Batch Insert**
- Sessions are collected in a list
- Inserted in batches of 100 to avoid payload limits
- All sessions created atomically

---

## 📋 **Example**

### **Recurring Session:**
- **Days:** Monday, Wednesday
- **Times:** Monday: "4:00 PM", Wednesday: "4:00 PM"
- **Frequency:** 2 sessions per week
- **Start Date:** January 15, 2025

### **Generated Individual Sessions:**
1. **Week 1:**
   - Monday, Jan 15, 2025 at 4:00 PM
   - Wednesday, Jan 17, 2025 at 4:00 PM

2. **Week 2:**
   - Monday, Jan 22, 2025 at 4:00 PM
   - Wednesday, Jan 24, 2025 at 4:00 PM

3. **Week 3-8:** Continue pattern...

**Total:** 16 individual sessions (2 sessions/week × 8 weeks)

---

## 🔧 **Configuration**

### **Default Settings:**
- **Weeks Ahead:** 8 weeks (configurable)
- **Duration:** 60 minutes (can be made configurable per recurring session)
- **Batch Size:** 100 sessions per insert

### **To Generate More Sessions:**
```dart
// Generate sessions for next 12 weeks
await RecurringSessionService.generateIndividualSessions(
  recurringSessionId: sessionId,
  weeksAhead: 12,
);
```

---

## ⚙️ **Integration Points**

### **1. Booking Approval Flow**
**File:** `lib/features/booking/screens/tutor_booking_detail_screen.dart`

When tutor approves a booking:
1. `RecurringSessionService.createRecurringSessionFromBooking()` is called
2. Recurring session created
3. Individual sessions automatically generated
4. Tutor can immediately see upcoming sessions

### **2. Tutor Sessions Screen**
**File:** `lib/features/tutor/screens/tutor_sessions_screen.dart`

The screen already loads individual sessions:
- `IndividualSessionService.getTutorUpcomingSessions()` - Shows upcoming sessions
- `IndividualSessionService.getTutorPastSessions()` - Shows past sessions

Now these will be populated automatically!

### **3. Session Management**
- Tutors can start/end individual sessions
- Sessions can be cancelled or rescheduled
- Status tracking (scheduled → in_progress → completed)

---

## 🚀 **Next Steps**

### **1. Cron Job for Ongoing Generation** ⏳
Create a scheduled job to generate more sessions as time passes:
- Run weekly to generate next week's sessions
- Ensure sessions are always available 8 weeks ahead
- Can be implemented in Next.js as a cron job

### **2. Dynamic Duration** ⏳
Make session duration configurable:
- Add `duration_minutes` to `recurring_sessions` table
- Use that value when generating individual sessions
- Default to 60 minutes if not specified

### **3. Rescheduling Support** ⏳
When a session is rescheduled:
- Update the individual session's date/time
- Regenerate if needed
- Handle conflicts

### **4. Testing** ⏳
- Test with different schedules (daily, weekly, multiple days)
- Test with different time formats
- Test duplicate prevention
- Test batch insertion with large numbers

---

## ✅ **Status**

- ✅ Automatic generation implemented
- ✅ Called automatically on recurring session creation
- ✅ Prevents duplicates
- ✅ Batch insertion for performance
- ⏳ Needs cron job for ongoing generation
- ⏳ Needs testing with real data

---

## 📝 **Notes**

1. **Time Parsing:** Currently handles 12-hour format with AM/PM. May need enhancement for 24-hour format or other formats.

2. **Subject:** Tries to get subject from booking request. Falls back to "Tutoring Session" if not available.

3. **Location:** Hybrid sessions default to "online" for individual sessions. Onsite address is preserved.

4. **Performance:** Batch insertion in chunks of 100 prevents payload size issues with large schedules.

5. **Future Enhancement:** Consider generating sessions on-demand (lazy generation) instead of all at once for very long-term recurring sessions.





