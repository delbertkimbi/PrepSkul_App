# ⚡ Quick Test Guide - Day 7

## 🎯 **Quick Start Testing**

### **Before Testing:**
1. ✅ Migration 008 applied? (28 columns in tutor_profiles) ✓
2. ✅ App running? `flutter run`
3. ✅ Admin dashboard running? (admin.prepskul.com)
4. ✅ WhatsApp ready? (to receive notifications)

---

## 🧪 **3 Main Test Flows**

### **1️⃣ TRIAL SESSION BOOKING** (5 mins)
```
Home → Find Tutors → [Pick Tutor] → Book Trial Session
  ↓
Fill form (date, time, goals)
  ↓
Submit → Check "My Requests" → Trial tab
  ✅ Should see your booking!
```

**Database Check:**
```sql
SELECT * FROM trial_sessions 
WHERE learner_id = auth.uid() 
ORDER BY created_at DESC LIMIT 1;
```

---

### **2️⃣ REGULAR BOOKING** (8 mins)
```
Find Tutors → [Pick Tutor] → Book Tutor
  ↓
Step 1: Frequency (Weekly)
  ↓
Step 2: Days (Mon/Wed/Fri)
  ↓
Step 3: Time slots
  ↓
Step 4: Location (should auto-fill!)
  ↓
Step 5: Review → Select payment plan
  ↓
Submit → Check "My Requests" → Pending tab
  ✅ Should see your booking!
```

**Database Check:**
```sql
SELECT sr.*, rs.* 
FROM session_requests sr
LEFT JOIN recurring_sessions rs ON sr.id = rs.session_request_id
WHERE sr.learner_id = auth.uid()
ORDER BY sr.created_at DESC LIMIT 1;
```

---

### **3️⃣ CUSTOM TUTOR REQUEST** (6 mins)
```
Find Tutors → No results OR Click "Request a Tutor"
  ↓
Fill multi-step form
  ↓
Submit → 🔔 CHECK WHATSAPP (+237 6 53 30 19 97)
  ↓
Check "My Requests" → Custom tab
  ✅ Should see your request!
  ✅ WhatsApp should have detailed message!
```

**Database Check:**
```sql
SELECT * FROM tutor_requests 
WHERE requester_id = auth.uid()
ORDER BY created_at DESC LIMIT 1;
```

---

## 🎨 **Empty State Tests** (2 mins each)

### **Test 1: Clean My Requests**
```
My Requests → All tab (empty)
  ✅ Should show "Request a Tutor" card ONLY
  ❌ Should NOT show "No requests yet" text
```

### **Test 2: No Tutors Found**
```
Find Tutors → Apply very specific filters
  ✅ Should show "Clear filters" button
  ✅ Should show "Request a Tutor" card below
  ❌ Should NOT show search icon or "adjust search" text
```

---

## 🐛 **Common Issues to Check**

### **Issue 1: Location Not Pre-filling**
- **Where:** Regular booking Step 4
- **Expected:** City/Quarter from survey
- **Fix:** Check survey data saved correctly

### **Issue 2: Payment Plan Defaulting**
- **Where:** Booking review screen
- **Expected:** No default selection
- **Fix:** User must choose payment plan

### **Issue 3: WhatsApp Not Sending**
- **Where:** After custom request submit
- **Expected:** WhatsApp opens with message
- **Fix:** Check `url_launcher` permissions

### **Issue 4: Dark Screen on Back**
- **Where:** Bottom navbar screens
- **Expected:** Stay in app
- **Fix:** Check `automaticallyImplyLeading: false` in AppBar

---

## 📊 **Quick Database Verification**

Run these in Supabase SQL Editor:

```sql
-- 1. Count your bookings
SELECT 
  'Trial Sessions' as type, COUNT(*) as total
FROM trial_sessions WHERE learner_id = auth.uid()
UNION ALL
SELECT 
  'Regular Bookings', COUNT(*)
FROM session_requests WHERE learner_id = auth.uid()
UNION ALL
SELECT 
  'Custom Requests', COUNT(*)
FROM tutor_requests WHERE requester_id = auth.uid();

-- 2. Check latest request details
SELECT 
  'Trial' as type,
  scheduled_time::text as details,
  status,
  created_at
FROM trial_sessions 
WHERE learner_id = auth.uid()
UNION ALL
SELECT 
  'Regular',
  frequency,
  status,
  created_at
FROM session_requests 
WHERE learner_id = auth.uid()
UNION ALL
SELECT 
  'Custom',
  urgency,
  status::text,
  created_at
FROM tutor_requests 
WHERE requester_id = auth.uid()
ORDER BY created_at DESC;
```

---

## ✅ **Quick Checklist**

After each test, verify:
- [ ] No errors in console
- [ ] Success message shown
- [ ] Data in "My Requests"
- [ ] Database entry created
- [ ] UI looks good (no overflow)
- [ ] Navigation works properly

---

## 🚀 **Test Priority**

1. **CRITICAL** (Must work):
   - Trial booking end-to-end
   - Custom request + WhatsApp
   - Database saves correctly

2. **HIGH** (Should work):
   - Regular booking flow
   - Empty states correct
   - Navigation smooth

3. **MEDIUM** (Nice to have):
   - Payment plan selection
   - Location pre-fill
   - Admin dashboard sync

---

## 📱 **Testing Workflow**

```
1. Open app in simulator/emulator
   ↓
2. Test each flow (20 mins total)
   ↓
3. Check "My Requests" after each
   ↓
4. Run database queries
   ↓
5. Check WhatsApp for notifications
   ↓
6. Report any bugs immediately
```

---

## 🎯 **Done Testing?**

Fill out the summary:

```
✅ PASSED: [List what works]
❌ FAILED: [List what's broken]
🐛 BUGS: [Describe issues]
📊 COVERAGE: XX%
```

**Then proceed to Week 2 features!** 🎉

