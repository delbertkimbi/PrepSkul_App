# 📋 DAY 7: End-to-End Testing Checklist

## 🎯 **Testing Scope**
Complete booking flow testing from both student/parent and tutor perspectives, including edge cases and error handling.

---

## 🧪 **TEST 1: Student/Parent → Trial Session Booking**

### **Steps to Test:**
1. ✅ Login as student/parent
2. ✅ Navigate to "Find Tutors"
3. ✅ Search/filter for a tutor
4. ✅ Click on tutor card → View details
5. ✅ Click "Book Trial Session"
6. ✅ Fill trial booking form:
   - Select available date from calendar
   - Choose time slot
   - Enter learning goals
   - Confirm location (should pre-fill from survey)
7. ✅ Review & Submit
8. ✅ Check "My Requests" → Trial tab
9. ✅ Verify request appears with correct details

### **Expected Results:**
- ✅ Calendar shows only tutor's available dates
- ✅ Time slots match tutor's schedule
- ✅ Location pre-fills from survey data
- ✅ Success message shown after submit
- ✅ Request visible in "My Requests" → Trial tab
- ✅ Status shows "Pending"
- ✅ Database has correct entry in `trial_sessions` table

### **Database Verification:**
```sql
-- Check trial session was created
SELECT * FROM public.trial_sessions
WHERE learner_id = 'YOUR_USER_ID'
ORDER BY created_at DESC
LIMIT 1;
```

---

## 🧪 **TEST 2: Student/Parent → Regular Session Booking**

### **Steps to Test:**
1. ✅ Find tutor from "Find Tutors"
2. ✅ Click tutor → "Book Tutor"
3. ✅ Step 1: Select frequency (weekly/biweekly/custom)
4. ✅ Step 2: Select days (Mon/Wed/Fri pattern)
5. ✅ Step 3: Select time slots
6. ✅ Step 4: Confirm/edit location
7. ✅ Step 5: Review all details
8. ✅ Select payment plan (monthly/per-session/package)
9. ✅ Submit booking
10. ✅ Check "My Requests" → Pending tab

### **Expected Results:**
- ✅ Multi-step wizard works smoothly
- ✅ Can go back/forward between steps
- ✅ Review shows correct summary
- ✅ Monthly payment estimate displayed
- ✅ Location pre-filled from survey
- ✅ Request appears in "My Requests"
- ✅ Database has entries in `session_requests` & `recurring_sessions`

### **Database Verification:**
```sql
-- Check session request was created
SELECT sr.*, rs.*
FROM public.session_requests sr
LEFT JOIN public.recurring_sessions rs ON sr.id = rs.session_request_id
WHERE sr.learner_id = 'YOUR_USER_ID'
ORDER BY sr.created_at DESC
LIMIT 1;
```

---

## 🧪 **TEST 3: Custom Tutor Request Flow**

### **Steps to Test:**
1. ✅ Go to "Find Tutors"
2. ✅ Apply filters → No tutors found
3. ✅ Click "Request a Tutor" card
4. ✅ Step 1: Enter subjects & education level
5. ✅ Step 2: Select teaching mode & preferences
6. ✅ Step 3: Set budget range
7. ✅ Step 4: Choose schedule & urgency
8. ✅ Step 5: Review & submit
9. ✅ **Check WhatsApp** → Should receive notification
10. ✅ Check "My Requests" → Custom tab

### **Expected Results:**
- ✅ Form pre-fills data from survey
- ✅ All steps validate correctly
- ✅ Success message after submit
- ✅ **WhatsApp message sent to +237 6 53 30 19 97**
- ✅ Message contains all user details
- ✅ Request visible in "My Requests" → Custom tab
- ✅ Database has entry in `tutor_requests`

### **WhatsApp Notification Format:**
```
🎓 NEW TUTOR REQUEST - PrepSkul
━━━━━━━━━━━━━━━━━━━━
👤 Requester: [Your Name]
📱 Phone: +237 6 XX XX XX XX
📚 Type: Student
━━━━━━━━━━━━━━━━━━━━
📖 SUBJECTS NEEDED: [Your Subjects]
🎓 EDUCATION: [Your Level]
💰 BUDGET: [Min - Max] XAF/month
...
```

### **Database Verification:**
```sql
-- Check tutor request was created
SELECT * FROM public.tutor_requests
WHERE requester_id = 'YOUR_USER_ID'
ORDER BY created_at DESC
LIMIT 1;
```

---

## 🧪 **TEST 4: Admin Dashboard - Request Management**

### **Steps to Test:**
1. ✅ Login to admin dashboard (admin.prepskul.com)
2. ✅ Navigate to "Tutor Requests"
3. ✅ View all pending custom requests
4. ✅ Click on a request → View details
5. ✅ Update status (Pending → In Progress)
6. ✅ Add admin notes
7. ✅ Navigate to "Tutors" section
8. ✅ View pending tutor approvals
9. ✅ Review tutor profile
10. ✅ Approve/Reject tutor

### **Expected Results:**
- ✅ All requests visible with filters
- ✅ Can update status & add notes
- ✅ Changes save to database
- ✅ Tutor approval workflow works
- ✅ Admin notes persist
- ✅ Real-time metrics update

---

## 🧪 **TEST 5: Empty States & Edge Cases**

### **Scenarios to Test:**

#### **5.1: No Requests Yet**
- ✅ Go to "My Requests" when empty
- ✅ **All Tab**: Should show "Request a Tutor" card
- ✅ **Custom Tab**: Should show "Request a Tutor" card
- ✅ **Trial Tab**: Should show simple empty state
- ✅ **Pending Tab**: Should show simple empty state
- ✅ **Approved Tab**: Should show simple empty state

#### **5.2: No Tutors Found**
- ✅ Apply very specific filters
- ✅ Should show "Clear filters" button
- ✅ Should show "Request a Tutor" card
- ✅ Card should navigate to request form

#### **5.3: Invalid Data**
- ✅ Try booking without selecting time
- ✅ Try submitting request with missing fields
- ✅ Should show validation errors
- ✅ Should not allow submission

---

## 🧪 **TEST 6: Payment Plan Selection**

### **Steps to Test:**
1. ✅ In booking review screen
2. ✅ Select "Monthly Payment Plan"
3. ✅ Verify monthly estimate shown
4. ✅ Select "Per Session"
5. ✅ Verify per-session rate shown
6. ✅ Select "Package Deal"
7. ✅ Verify package pricing shown

### **Expected Results:**
- ✅ Payment plan selection saves correctly
- ✅ Pricing updates based on selection
- ✅ Database stores selected plan

---

## 🧪 **TEST 7: Database Integrity Check**

### **Queries to Run:**

```sql
-- 1. Check all trial sessions have valid references
SELECT ts.*, p.full_name
FROM public.trial_sessions ts
LEFT JOIN public.profiles p ON ts.learner_id = p.id
WHERE ts.learner_id IS NOT NULL;

-- 2. Check all session requests have valid data
SELECT sr.*, p.full_name, tp.bio
FROM public.session_requests sr
LEFT JOIN public.profiles p ON sr.learner_id = p.id
LEFT JOIN public.tutor_profiles tp ON sr.tutor_id = tp.id;

-- 3. Check all tutor requests have requester info
SELECT tr.*, p.full_name, p.phone_number
FROM public.tutor_requests tr
LEFT JOIN public.profiles p ON tr.requester_id = p.id;

-- 4. Verify RLS policies work
-- Try selecting as different user
SELECT * FROM public.trial_sessions; -- Should only see own
SELECT * FROM public.session_requests; -- Should only see own
SELECT * FROM public.tutor_requests; -- Should only see own
```

---

## 🧪 **TEST 8: Navigation Flow**

### **Routes to Test:**
1. ✅ Home → Find Tutors → Tutor Details → Book Trial → Success → My Requests
2. ✅ Home → Find Tutors → Tutor Details → Book Regular → Success → My Requests
3. ✅ Find Tutors → No Results → Request Tutor → Submit → My Requests
4. ✅ My Requests → Empty State → Request Tutor → Submit → My Requests (with data)
5. ✅ Bottom Navbar: Home ↔ Find Tutors ↔ Requests ↔ Profile
6. ✅ Back button behavior (should not navigate to dark screen)

---

## 🧪 **TEST 9: UI/UX Verification**

### **Visual Checks:**
- ✅ No text overflow anywhere
- ✅ All buttons clickable & responsive
- ✅ Shimmers show during loading
- ✅ Error messages clear & helpful
- ✅ Success messages encouraging
- ✅ Empty states friendly & actionable
- ✅ Cards look clean & professional
- ✅ Icons & colors consistent
- ✅ Spacing & padding uniform

---

## 🧪 **TEST 10: Performance & Error Handling**

### **Scenarios:**
1. ✅ Submit booking with slow internet
2. ✅ Try booking when not logged in
3. ✅ Submit duplicate booking
4. ✅ Try accessing tutor details with invalid ID
5. ✅ Network error during submission
6. ✅ Database error (simulate)

### **Expected Behavior:**
- ✅ Loading indicators show
- ✅ Error messages display
- ✅ No app crashes
- ✅ Graceful fallbacks
- ✅ Retry mechanisms work

---

## ✅ **Testing Summary Template**

After testing, fill this out:

```markdown
## Test Results - [Date]

### ✅ PASSED:
- [ ] Student trial booking flow
- [ ] Student regular booking flow
- [ ] Custom tutor request flow
- [ ] Admin dashboard management
- [ ] Empty states
- [ ] Payment plan selection
- [ ] Database integrity
- [ ] Navigation flow
- [ ] UI/UX checks
- [ ] Error handling

### ❌ FAILED / BUGS FOUND:
1. [Bug description]
   - Steps to reproduce
   - Expected vs Actual
   - Priority: High/Medium/Low

2. [Bug description]
   ...

### 📊 Coverage:
- Student/Parent flows: XX%
- Admin flows: XX%
- Edge cases: XX%
- Database verification: XX%

### 🎯 Next Steps:
- Fix critical bugs
- Re-test failed scenarios
- Deploy fixes
- Proceed to Week 2 features
```

---

## 🚀 **Ready to Test!**

Start with **TEST 1** and work your way through. Report any bugs immediately so we can fix them before proceeding to Week 2 features.

**Let's make sure everything works perfectly!** 🎉

