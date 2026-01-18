# 📹 Google Calendar Approval Video Guide

## 🎯 **Purpose**
This video is for **Google Cloud Console verification** to get approval for Google Calendar API access. The video demonstrates to Google's review team how PrepSkul uses the Calendar API so they can approve the OAuth scopes for ALL users.

**Important:** 
- ❌ This is **NOT** a user tutorial or marketing video
- ✅ This is a **verification video** that will be submitted to Google Cloud Console
- ✅ The goal is to prove PrepSkul legitimately needs `calendar.events` scope
- ✅ Once approved, ALL PrepSkul users will be able to connect their Google Calendar

**Where to Submit:**
1. Go to [Google Cloud Console](https://console.cloud.google.com/)
2. Navigate to: **APIs & Services** → **OAuth consent screen**
3. Find the scope that needs verification (`calendar.events`)
4. Click "Fix the issue" or "Submit for verification"
5. Upload this video in the "Video link" field

---

## 📱 **Screens to Record**

### **Flow 1: First-Time Calendar Connection (Student/Learner)**

#### **Screen 1: My Sessions Screen - Before Connection**
- **What to show:**
  - Navigate to "My Sessions" tab
  - Show an upcoming session card
  - Point out the "Connect & Add" button (outlined calendar icon)
  - Explain: "This session doesn't have a calendar event yet"

#### **Screen 2: Click "Connect & Add" Button**
- **What to show:**
  - Tap the "Connect & Add" button
  - Show the Google Sign-In dialog/modal appearing
- **Voiceover (say this while showing):** "When the user clicks this button, PrepSkul requests OAuth permission to access their Google Calendar. This is the permission request that requires Google's approval."

#### **Screen 3: Google OAuth Flow**
- **What to show:**
  - Google account selection screen (if multiple accounts)
  - **IMPORTANT:** Zoom in on the permission request screen showing:
    - "See, edit, share, and permanently delete all the calendars you can access using Google Calendar"
    - "Make changes to events"
  - User clicking "Allow" or "Continue"
- **Voiceover (say this while showing):** "This is the exact permission screen that requires Google's verification. PrepSkul requests these scopes to create calendar events with Google Meet links for tutoring sessions. The user grants permission, and PrepSkul can then create events on their behalf."

#### **Screen 4: Success - Session Added to Calendar**
- **What to show:**
  - Return to My Sessions screen
  - Show success snackbar: "Session added to calendar with Meet link!"
  - Button now shows "Add to Calendar" (filled icon) or disappears if already added
- **Voiceover (say this while showing):** "After permission is granted, PrepSkul uses the Google Calendar API to create a calendar event. The event includes the session details and a Google Meet link for online sessions."

#### **Screen 5: Verify in Google Calendar App (CRITICAL - MUST SHOW)**
- **What to show:**
  - Open Google Calendar app (or web) - **This is the most important part!**
  - Show the session event in the calendar with correct date/time
  - **Zoom in** on the event details showing:
    - The Meet link (clickable Google Meet URL)
    - Session title: "Trial Session: [Subject]" or "PrepSkul Session: [Subject]"
    - Tutor and student emails as attendees
    - PrepSkul VA email as attendee
- **Voiceover (say this while showing):** "Here's proof that PrepSkul successfully created a calendar event using the Google Calendar API. The event includes the session details, a Google Meet link for online sessions, and all attendees. This demonstrates that PrepSkul uses the calendar.events scope to create events, not to read or modify existing calendar data."

---

### **Flow 2: Subsequent Sessions (Already Connected) - OPTIONAL**

**Note:** This flow is optional but shows that once permission is granted, PrepSkul can create events seamlessly.

#### **Screen 1: My Sessions Screen - Already Connected**
- **What to show:**
  - Navigate to "My Sessions" tab
  - Show a new upcoming session card
  - Point out the "Add to Calendar" button (filled calendar icon)
- **Voiceover (say this while showing):** "Once a user has granted permission, PrepSkul can create additional calendar events without re-authentication. This shows the seamless experience after initial OAuth approval."

#### **Screen 2: One-Tap Add**
- **What to show:**
  - Tap "Add to Calendar" button
  - **NO Google Sign-In dialog** (already authenticated)
  - Direct success message
- **Voiceover (say this while showing):** "The event is created instantly using the stored OAuth token, demonstrating that PrepSkul only creates events when explicitly requested by the user."

---

### **Flow 3: Payment Flow with Auto Calendar (Trial Session)**

#### **Screen 1: Trial Payment Screen**
- **What to show:**
  - Navigate to a trial session that's been approved
  - Show payment screen with phone number input
  - Explain: "After tutor approval, we can pay for the trial session"

#### **Screen 2: Complete Payment**
- **What to show:**
  - Enter phone number
  - Tap "Pay Now" or use sandbox test button
  - Show payment success
  - Explain: "Payment completed successfully"

#### **Screen 3: Automatic Navigation & Calendar**
- **What to show:**
  - Automatic navigation to "My Sessions" screen
  - Show the paid session in "Upcoming" tab
  - Show countdown timer
  - Show "Add to Calendar" button (if not auto-added)
  - Explain: "The session is ready, and if calendar is connected, it's automatically added"

#### **Screen 4: Meet Link Available**
- **What to show:**
  - Tap on the session card
  - Show session details with Meet link
  - Show "Join Meeting" button
  - Explain: "The Meet link is generated and ready for both tutor and student"

---

### **Flow 4: Tutor Side - Calendar Connection**

#### **Screen 1: Tutor Sessions Screen**
- **What to show:**
  - Navigate to tutor's "My Sessions" screen
  - Show an upcoming session card
  - Show "Add to Calendar" or "Connect & Add" button
  - Explain: "Tutors can also connect their calendar"

#### **Screen 2: Tutor Calendar Connection**
- **What to show:**
  - Same Google OAuth flow as student
  - Show permission request
  - Show success

#### **Screen 3: Tutor Session in Calendar**
- **What to show:**
  - Open Google Calendar
  - Show session event
  - Show both student and tutor emails as attendees
  - Show PrepSkul VA email
  - Explain: "All parties are added as attendees automatically"

---

## 🎬 **Recommended Video Flow**

### **Option A: Complete Verification Demo (3-5 minutes) - RECOMMENDED**
1. **Introduction** (15s)
   - "This video demonstrates how PrepSkul uses the Google Calendar API to create calendar events with Meet links for tutoring sessions."
   - "PrepSkul is an online tutoring platform that connects students with tutors."

2. **OAuth Permission Request** (30s)
   - Show the "Connect & Add" button
   - Show Google OAuth permission screen
   - **Emphasize:** "PrepSkul requests permission to create calendar events, not to read or modify existing events."

3. **Calendar Event Creation** (1-2 min)
   - Show user clicking "Allow"
   - Show success message
   - **CRITICAL:** Open Google Calendar and show the created event
   - **Show clearly:** Event title, date/time, Meet link, attendees

4. **Meet Link Generation** (30s)
   - Show the Meet link in the calendar event
   - Explain: "PrepSkul uses the Google Calendar API to automatically generate Google Meet links for online sessions."

5. **Conclusion** (15s)
   - "PrepSkul only creates calendar events when users explicitly request it by clicking 'Add to Calendar'."
   - "We use the calendar.events scope solely to create events for tutoring sessions, not to access other calendar data."

### **Option B: Quick Demo (2-3 minutes)**
1. **Quick Intro** (5s)
   - "PrepSkul Google Calendar integration"

2. **Connection Flow** (1 min)
   - Show "Connect & Add" button
   - Google OAuth flow
   - Success message

3. **Payment & Auto-Add** (1 min)
   - Pay for trial
   - Show automatic calendar addition
   - Show Meet link

4. **Verification** (30s)
   - Open Google Calendar
   - Show event with Meet link

---

## 📝 **Key Points to Highlight (FOR GOOGLE REVIEW TEAM)**

### **1. Explicit User Action Required**
- ✅ "Users must explicitly click 'Add to Calendar' - PrepSkul never creates events automatically"
- ✅ "Calendar integration is optional - users can use PrepSkul without connecting their calendar"

### **2. Limited Scope Usage**
- ✅ "PrepSkul ONLY creates calendar events - we do not read, modify, or delete existing calendar events"
- ✅ "We use calendar.events scope solely to create events for tutoring sessions booked through PrepSkul"

### **3. Meet Link Generation**
- ✅ "PrepSkul uses Google Calendar API to generate Meet links for online tutoring sessions"
- ✅ "Meet links are created as part of the calendar event, not separately"

### **4. User Control**
- ✅ "Users grant permission once and can revoke it anytime through Google Account settings"
- ✅ "Each calendar event creation requires explicit user action (clicking 'Add to Calendar')"

### **5. Educational Purpose**
- ✅ "PrepSkul is an educational platform connecting students with tutors"
- ✅ "Calendar events help students and tutors manage their tutoring sessions"
- ✅ "This is a legitimate educational use case for the Calendar API"

---

## 🎥 **Recording Tips**

### **Device Setup**
- Use a real device (not emulator) for better OAuth flow
- Ensure Google Calendar app is installed
- Have a test Google account ready

### **Screen Recording**
- Use screen recording feature (iOS/Android built-in)
- Record in landscape for better visibility
- Show full screen, not cropped

### **Voiceover**
- Speak clearly and slowly
- Explain each step as you do it
- Pause briefly after key actions

### **Editing**
- Add text overlays for key features
- Highlight buttons with circles/arrows
- Add transitions between screens
- Keep total length under 5 minutes

---

## 🔑 **Key Screens to Capture**

1. ✅ **My Sessions Screen** - Shows "Connect & Add" button
2. ✅ **Google OAuth Dialog** - Permission request screen
3. ✅ **Success Message** - "Session added to calendar"
4. ✅ **Google Calendar App** - Event with Meet link visible
5. ✅ **Payment Screen** - Trial payment flow
6. ✅ **Session Details** - Meet link and countdown
7. ✅ **Tutor Sessions** - Tutor-side calendar connection

---

## 📋 **Checklist Before Recording**

- [ ] Test account has no existing calendar connection
- [ ] Test account has Google Calendar app installed
- [ ] Have a trial session ready (approved, unpaid)
- [ ] Have a paid session ready (to show Meet link)
- [ ] Screen recording is enabled
- [ ] Audio/microphone is working
- [ ] Device is charged/plugged in
- [ ] Clear workspace (no notifications)

---

## 🎯 **Target Audience**

- **Primary:** Students/Parents using PrepSkul
- **Secondary:** Tutors using PrepSkul
- **Tertiary:** Investors/Stakeholders (feature demo)

---

## 📊 **Submission Checklist**

Before submitting to Google Cloud Console:
- [ ] Video clearly shows OAuth permission request screen
- [ ] Video shows calendar event being created in Google Calendar
- [ ] Video shows Meet link in the created event
- [ ] Video demonstrates user explicitly clicking "Add to Calendar"
- [ ] Video is 2-5 minutes long
- [ ] Video is uploaded to YouTube (unlisted) or Google Drive (shareable)
- [ ] Video link is added to Google Cloud Console verification form
- [ ] Additional info field explains PrepSkul's use case

---

## 🔗 **Related Documentation**

- `GOOGLE_CALENDAR_OAUTH_IMPLEMENTATION.md` - Technical details
- `CALENDAR_CONNECTION_LOGIC.md` - User experience flow
- `FATHOM_MEETING_FLOW.md` - Recording integration






















