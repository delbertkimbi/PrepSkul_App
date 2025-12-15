# 🔐 Google Auth Verification Guide

**Issue:** Cannot click "Confirm" button, verification blocked by missing demo video

---

## ❌ **Current Problem**

From your screenshots:
1. **Verification Status:** "Needs verification" - Orange warning
2. **Reason:** "Your app has been configured with sensitive or restricted scopes"
3. **Missing Field:** "demo video" - Red warning banner
4. **Confirm Button:** Disabled (greyed out) - Cannot click

**Root Cause:** The `calendar.events` scope requires a demo video showing how your app uses Google Calendar.

---

## ✅ **Solution: Create and Submit Demo Video**

### **Step 1: Create Demo Video (Required)**

**What to Record:**
1. **Show your app** (PrepSkul tutoring platform)
2. **Show booking a session** (student booking with tutor)
3. **Show calendar event creation** (session added to Google Calendar)
4. **Show Meet link generation** (if applicable)
5. **Show calendar event in Google Calendar** (verify it appears)

**Video Requirements:**
- **Duration:** 2-5 minutes (recommended)
- **Format:** MP4, MOV, or YouTube link
- **Content:** Must clearly show how you use `calendar.events` scope
- **Language:** English (preferred) or include subtitles

**What to Demonstrate:**
```
1. Open PrepSkul app
2. Student books a tutoring session
3. Tutor approves the session
4. Show that a calendar event is created
5. Open Google Calendar app/website
6. Show the event appears in calendar
7. Show event has Meet link (if applicable)
8. Show event has correct date/time
```

### **Step 2: Upload Video**

**Option A: YouTube (Recommended)**
1. Upload video to YouTube (can be unlisted)
2. Copy YouTube URL
3. Paste URL in "Video link" field

**Option B: Direct Upload**
1. Upload video to Google Drive
2. Make it shareable (anyone with link can view)
3. Copy shareable link
4. Paste URL in "Video link" field

### **Step 3: Fill Additional Info (Optional but Recommended)**

In the "Additional info" field, add:
```
PrepSkul is an online tutoring platform that connects students with tutors.

We use Google Calendar to:
- Create calendar events when students book sessions
- Add Google Meet links for online sessions
- Send calendar reminders to students and tutors
- Update events when sessions are rescheduled

Test Credentials:
- Test account: [your-test-email]@gmail.com
- Password: [test-password]

We only create, update, and delete calendar events related to tutoring sessions.
We do not read or modify any other calendar events.
```

### **Step 4: Click "Fix the issue" Button**

1. Click the red "Fix the issue" button next to the warning
2. This will take you to the scope justification page
3. Add your video link
4. Fill additional info
5. **Now "Confirm" button should be enabled**

### **Step 5: Submit for Verification**

1. Review all information
2. Click "Confirm" (should now be enabled)
3. Submit for Google review
4. Wait for approval (usually 1-3 business days)

---

## 🎥 **Quick Video Script**

**If you need a quick script for the video:**

```
[0:00-0:30] Introduction
- "This is PrepSkul, an online tutoring platform"
- "I'm going to show how we use Google Calendar"

[0:30-1:30] Booking Flow
- "A student books a tutoring session with a tutor"
- "The tutor approves the booking"
- "The system creates a calendar event"

[1:30-2:30] Calendar Integration
- "Let me open Google Calendar"
- "You can see the session event was created"
- "The event has the correct date and time"
- "For online sessions, a Meet link is included"

[2:30-3:00] Conclusion
- "This is how PrepSkul uses Google Calendar"
- "We only create events for tutoring sessions"
- "We don't access any other calendar data"
```

---

## ⚠️ **Important Notes**

1. **Video MUST show actual usage** - Don't just describe, show it working
2. **Use test account** - Don't use production data
3. **Make video public or unlisted** - Google needs to access it
4. **Keep it simple** - 2-3 minutes is enough
5. **Show calendar event** - Must show event appearing in Google Calendar

---

## 🔄 **After Submission**

1. **Status:** Will change to "Under review"
2. **Timeline:** 1-3 business days typically
3. **If Rejected:** Google will provide feedback, fix and resubmit
4. **If Approved:** Verification status will update to "Verified"

---

## 📝 **Alternative: Remove Calendar Scope (Not Recommended)**

If you don't want to create a video, you could:
1. Remove `calendar.events` scope temporarily
2. Use calendar integration only after verification
3. But this breaks session calendar integration

**Recommendation:** Create the video - it's required for production use.

---

**Once video is uploaded and "Confirm" is clicked, Google will review your app and approve verification!** ✅

think oogle Auth Verification Guide

**Issue:** Cannot click "Confirm" button, verification blocked by missing demo video

---

## ❌ **Current Problem**

From your screenshots:
1. **Verification Status:** "Needs verification" - Orange warning
2. **Reason:** "Your app has been configured with sensitive or restricted scopes"
3. **Missing Field:** "demo video" - Red warning banner
4. **Confirm Button:** Disabled (greyed out) - Cannot click

**Root Cause:** The `calendar.events` scope requires a demo video showing how your app uses Google Calendar.

---

## ✅ **Solution: Create and Submit Demo Video**

### **Step 1: Create Demo Video (Required)**

**What to Record:**
1. **Show your app** (PrepSkul tutoring platform)
2. **Show booking a session** (student booking with tutor)
3. **Show calendar event creation** (session added to Google Calendar)
4. **Show Meet link generation** (if applicable)
5. **Show calendar event in Google Calendar** (verify it appears)

**Video Requirements:**
- **Duration:** 2-5 minutes (recommended)
- **Format:** MP4, MOV, or YouTube link
- **Content:** Must clearly show how you use `calendar.events` scope
- **Language:** English (preferred) or include subtitles

**What to Demonstrate:**
```
1. Open PrepSkul app
2. Student books a tutoring session
3. Tutor approves the session
4. Show that a calendar event is created
5. Open Google Calendar app/website
6. Show the event appears in calendar
7. Show event has Meet link (if applicable)
8. Show event has correct date/time
```

### **Step 2: Upload Video**

**Option A: YouTube (Recommended)**
1. Upload video to YouTube (can be unlisted)
2. Copy YouTube URL
3. Paste URL in "Video link" field

**Option B: Direct Upload**
1. Upload video to Google Drive
2. Make it shareable (anyone with link can view)
3. Copy shareable link
4. Paste URL in "Video link" field

### **Step 3: Fill Additional Info (Optional but Recommended)**

In the "Additional info" field, add:
```
PrepSkul is an online tutoring platform that connects students with tutors.

We use Google Calendar to:
- Create calendar events when students book sessions
- Add Google Meet links for online sessions
- Send calendar reminders to students and tutors
- Update events when sessions are rescheduled

Test Credentials:
- Test account: [your-test-email]@gmail.com
- Password: [test-password]

We only create, update, and delete calendar events related to tutoring sessions.
We do not read or modify any other calendar events.
```

### **Step 4: Click "Fix the issue" Button**

1. Click the red "Fix the issue" button next to the warning
2. This will take you to the scope justification page
3. Add your video link
4. Fill additional info
5. **Now "Confirm" button should be enabled**

### **Step 5: Submit for Verification**

1. Review all information
2. Click "Confirm" (should now be enabled)
3. Submit for Google review
4. Wait for approval (usually 1-3 business days)

---

## 🎥 **Quick Video Script**

**If you need a quick script for the video:**

```
[0:00-0:30] Introduction
- "This is PrepSkul, an online tutoring platform"
- "I'm going to show how we use Google Calendar"

[0:30-1:30] Booking Flow
- "A student books a tutoring session with a tutor"
- "The tutor approves the booking"
- "The system creates a calendar event"

[1:30-2:30] Calendar Integration
- "Let me open Google Calendar"
- "You can see the session event was created"
- "The event has the correct date and time"
- "For online sessions, a Meet link is included"

[2:30-3:00] Conclusion
- "This is how PrepSkul uses Google Calendar"
- "We only create events for tutoring sessions"
- "We don't access any other calendar data"
```

---

## ⚠️ **Important Notes**

1. **Video MUST show actual usage** - Don't just describe, show it working
2. **Use test account** - Don't use production data
3. **Make video public or unlisted** - Google needs to access it
4. **Keep it simple** - 2-3 minutes is enough
5. **Show calendar event** - Must show event appearing in Google Calendar

---

## 🔄 **After Submission**

1. **Status:** Will change to "Under review"
2. **Timeline:** 1-3 business days typically
3. **If Rejected:** Google will provide feedback, fix and resubmit
4. **If Approved:** Verification status will update to "Verified"

---

## 📝 **Alternative: Remove Calendar Scope (Not Recommended)**

If you don't want to create a video, you could:
1. Remove `calendar.events` scope temporarily
2. Use calendar integration only after verification
3. But this breaks session calendar integration

**Recommendation:** Create the video - it's required for production use.

---

**Once video is uploaded and "Confirm" is clicked, Google will review your app and approve verification!** ✅

have oogle Auth Verification Guide

**Issue:** Cannot click "Confirm" button, verification blocked by missing demo video

---

## ❌ **Current Problem**

From your screenshots:
1. **Verification Status:** "Needs verification" - Orange warning
2. **Reason:** "Your app has been configured with sensitive or restricted scopes"
3. **Missing Field:** "demo video" - Red warning banner
4. **Confirm Button:** Disabled (greyed out) - Cannot click

**Root Cause:** The `calendar.events` scope requires a demo video showing how your app uses Google Calendar.

---

## ✅ **Solution: Create and Submit Demo Video**

### **Step 1: Create Demo Video (Required)**

**What to Record:**
1. **Show your app** (PrepSkul tutoring platform)
2. **Show booking a session** (student booking with tutor)
3. **Show calendar event creation** (session added to Google Calendar)
4. **Show Meet link generation** (if applicable)
5. **Show calendar event in Google Calendar** (verify it appears)

**Video Requirements:**
- **Duration:** 2-5 minutes (recommended)
- **Format:** MP4, MOV, or YouTube link
- **Content:** Must clearly show how you use `calendar.events` scope
- **Language:** English (preferred) or include subtitles

**What to Demonstrate:**
```
1. Open PrepSkul app
2. Student books a tutoring session
3. Tutor approves the session
4. Show that a calendar event is created
5. Open Google Calendar app/website
6. Show the event appears in calendar
7. Show event has Meet link (if applicable)
8. Show event has correct date/time
```

### **Step 2: Upload Video**

**Option A: YouTube (Recommended)**
1. Upload video to YouTube (can be unlisted)
2. Copy YouTube URL
3. Paste URL in "Video link" field

**Option B: Direct Upload**
1. Upload video to Google Drive
2. Make it shareable (anyone with link can view)
3. Copy shareable link
4. Paste URL in "Video link" field

### **Step 3: Fill Additional Info (Optional but Recommended)**

In the "Additional info" field, add:
```
PrepSkul is an online tutoring platform that connects students with tutors.

We use Google Calendar to:
- Create calendar events when students book sessions
- Add Google Meet links for online sessions
- Send calendar reminders to students and tutors
- Update events when sessions are rescheduled

Test Credentials:
- Test account: [your-test-email]@gmail.com
- Password: [test-password]

We only create, update, and delete calendar events related to tutoring sessions.
We do not read or modify any other calendar events.
```

### **Step 4: Click "Fix the issue" Button**

1. Click the red "Fix the issue" button next to the warning
2. This will take you to the scope justification page
3. Add your video link
4. Fill additional info
5. **Now "Confirm" button should be enabled**

### **Step 5: Submit for Verification**

1. Review all information
2. Click "Confirm" (should now be enabled)
3. Submit for Google review
4. Wait for approval (usually 1-3 business days)

---

## 🎥 **Quick Video Script**

**If you need a quick script for the video:**

```
[0:00-0:30] Introduction
- "This is PrepSkul, an online tutoring platform"
- "I'm going to show how we use Google Calendar"

[0:30-1:30] Booking Flow
- "A student books a tutoring session with a tutor"
- "The tutor approves the booking"
- "The system creates a calendar event"

[1:30-2:30] Calendar Integration
- "Let me open Google Calendar"
- "You can see the session event was created"
- "The event has the correct date and time"
- "For online sessions, a Meet link is included"

[2:30-3:00] Conclusion
- "This is how PrepSkul uses Google Calendar"
- "We only create events for tutoring sessions"
- "We don't access any other calendar data"
```

---

## ⚠️ **Important Notes**

1. **Video MUST show actual usage** - Don't just describe, show it working
2. **Use test account** - Don't use production data
3. **Make video public or unlisted** - Google needs to access it
4. **Keep it simple** - 2-3 minutes is enough
5. **Show calendar event** - Must show event appearing in Google Calendar

---

## 🔄 **After Submission**

1. **Status:** Will change to "Under review"
2. **Timeline:** 1-3 business days typically
3. **If Rejected:** Google will provide feedback, fix and resubmit
4. **If Approved:** Verification status will update to "Verified"

---

## 📝 **Alternative: Remove Calendar Scope (Not Recommended)**

If you don't want to create a video, you could:
1. Remove `calendar.events` scope temporarily
2. Use calendar integration only after verification
3. But this breaks session calendar integration

**Recommendation:** Create the video - it's required for production use.

---

**Once video is uploaded and "Confirm" is clicked, Google will review your app and approve verification!** ✅

think oogle Auth Verification Guide

**Issue:** Cannot click "Confirm" button, verification blocked by missing demo video

---

## ❌ **Current Problem**

From your screenshots:
1. **Verification Status:** "Needs verification" - Orange warning
2. **Reason:** "Your app has been configured with sensitive or restricted scopes"
3. **Missing Field:** "demo video" - Red warning banner
4. **Confirm Button:** Disabled (greyed out) - Cannot click

**Root Cause:** The `calendar.events` scope requires a demo video showing how your app uses Google Calendar.

---

## ✅ **Solution: Create and Submit Demo Video**

### **Step 1: Create Demo Video (Required)**

**What to Record:**
1. **Show your app** (PrepSkul tutoring platform)
2. **Show booking a session** (student booking with tutor)
3. **Show calendar event creation** (session added to Google Calendar)
4. **Show Meet link generation** (if applicable)
5. **Show calendar event in Google Calendar** (verify it appears)

**Video Requirements:**
- **Duration:** 2-5 minutes (recommended)
- **Format:** MP4, MOV, or YouTube link
- **Content:** Must clearly show how you use `calendar.events` scope
- **Language:** English (preferred) or include subtitles

**What to Demonstrate:**
```
1. Open PrepSkul app
2. Student books a tutoring session
3. Tutor approves the session
4. Show that a calendar event is created
5. Open Google Calendar app/website
6. Show the event appears in calendar
7. Show event has Meet link (if applicable)
8. Show event has correct date/time
```

### **Step 2: Upload Video**

**Option A: YouTube (Recommended)**
1. Upload video to YouTube (can be unlisted)
2. Copy YouTube URL
3. Paste URL in "Video link" field

**Option B: Direct Upload**
1. Upload video to Google Drive
2. Make it shareable (anyone with link can view)
3. Copy shareable link
4. Paste URL in "Video link" field

### **Step 3: Fill Additional Info (Optional but Recommended)**

In the "Additional info" field, add:
```
PrepSkul is an online tutoring platform that connects students with tutors.

We use Google Calendar to:
- Create calendar events when students book sessions
- Add Google Meet links for online sessions
- Send calendar reminders to students and tutors
- Update events when sessions are rescheduled

Test Credentials:
- Test account: [your-test-email]@gmail.com
- Password: [test-password]

We only create, update, and delete calendar events related to tutoring sessions.
We do not read or modify any other calendar events.
```

### **Step 4: Click "Fix the issue" Button**

1. Click the red "Fix the issue" button next to the warning
2. This will take you to the scope justification page
3. Add your video link
4. Fill additional info
5. **Now "Confirm" button should be enabled**

### **Step 5: Submit for Verification**

1. Review all information
2. Click "Confirm" (should now be enabled)
3. Submit for Google review
4. Wait for approval (usually 1-3 business days)

---

## 🎥 **Quick Video Script**

**If you need a quick script for the video:**

```
[0:00-0:30] Introduction
- "This is PrepSkul, an online tutoring platform"
- "I'm going to show how we use Google Calendar"

[0:30-1:30] Booking Flow
- "A student books a tutoring session with a tutor"
- "The tutor approves the booking"
- "The system creates a calendar event"

[1:30-2:30] Calendar Integration
- "Let me open Google Calendar"
- "You can see the session event was created"
- "The event has the correct date and time"
- "For online sessions, a Meet link is included"

[2:30-3:00] Conclusion
- "This is how PrepSkul uses Google Calendar"
- "We only create events for tutoring sessions"
- "We don't access any other calendar data"
```

---

## ⚠️ **Important Notes**

1. **Video MUST show actual usage** - Don't just describe, show it working
2. **Use test account** - Don't use production data
3. **Make video public or unlisted** - Google needs to access it
4. **Keep it simple** - 2-3 minutes is enough
5. **Show calendar event** - Must show event appearing in Google Calendar

---

## 🔄 **After Submission**

1. **Status:** Will change to "Under review"
2. **Timeline:** 1-3 business days typically
3. **If Rejected:** Google will provide feedback, fix and resubmit
4. **If Approved:** Verification status will update to "Verified"

---

## 📝 **Alternative: Remove Calendar Scope (Not Recommended)**

If you don't want to create a video, you could:
1. Remove `calendar.events` scope temporarily
2. Use calendar integration only after verification
3. But this breaks session calendar integration

**Recommendation:** Create the video - it's required for production use.

---

**Once video is uploaded and "Confirm" is clicked, Google will review your app and approve verification!** ✅

t0-07654r
