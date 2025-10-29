# 💳 Monthly Pricing & Booking System - Implementation Plan

**Date:** October 29, 2025  
**Feature:** Monthly Payment Display + Smart Booking Flow  
**Priority:** P0 - Critical for Market Fit

---

## 🎯 **OVERVIEW**

In Cameroon and Africa, parents/students think in **monthly payments**, not hourly rates. This feature transforms how we display tutor pricing and creates an intelligent booking flow that leverages survey data.

---

## 📊 **KEY INSIGHTS**

### **Market Context**
- ✅ Monthly thinking (not hourly)
- ✅ Typical range: **25,000 - 50,000+ XAF/month**
- ✅ Based on 2-3 sessions/week = 8-12 sessions/month
- ✅ Payment options: Full upfront, Bi-weekly, Weekly
- ✅ Credits purchased ahead of time

### **Pricing Algorithm Inputs**
1. **Tutor per-session rate** (base price)
2. **Tutor rating** (initially admin-set, later from feedback)
3. **Tutor visibility subscription** (paid tutors get better visibility)
4. **Tutor credentials** (qualifications, PrepSkul Academy training)
5. **Course type** (academic vs skill vs exam prep)
6. **Session frequency** (2-3+ sessions/week)
7. **Session location** (online vs onsite vs hybrid)
8. **Admin overrides** (manual adjustments)

---

## 🎨 **UI CHANGES**

### **Tutor Card (Find Tutors Screen)**

**Current Display:**
```
Dr. Marie Ngono
⭐ 4.9 | Mathematics
5,000 XAF/hour
```

**New Display:**
```
Dr. Marie Ngono
⭐ 4.9 (127 reviews) | ✓ Verified
Mathematics, Further Mathematics

≈ 35,000 XAF / month
based on 2-3 sessions/week

[Book Trial] [Book Tutor]
```

**Rules:**
- Show estimated monthly fee prominently
- "based on X sessions/week" subtitle (calculated from survey data)
- Two action buttons visible on card
- Verified badge uses primary blue color

---

### **Tutor Detail Page (Scroll Down)**

**Additional Information:**
- Full bio, education, experience
- Video introduction
- Available schedule (calendar view)
- Reviews and ratings
- Success stories
- Payment breakdown:
  - Monthly estimate
  - Per-session rate
  - Discount options (for upfront payment)

---

## 🧮 **PRICING CALCULATION LOGIC**

### **Formula:**
```dart
monthlyEstimate = sessionRate × sessionsPerWeek × 4 (weeks)

Where:
- sessionRate = baseTutorRate × ratingMultiplier × credentialMultiplier × locationMultiplier
- sessionsPerWeek = from student/parent survey preference or default (2-3)
- ratingMultiplier = (rating / 5) * 1.2 (max 20% premium for 5-star)
- credentialMultiplier = 1.0 (Bachelor) | 1.15 (Master) | 1.3 (PhD) | 1.4 (PhD + Certified)
- locationMultiplier = 1.0 (online) | 1.2 (onsite) | 1.1 (hybrid)
```

### **Example Calculation:**

**Tutor:** Dr. Marie Ngono
- Base rate: 5,000 XAF/session
- Rating: 4.9 (multiplier = 1.176)
- Credentials: PhD + Cambridge Certified (multiplier = 1.4)
- Location: Hybrid (multiplier = 1.1)

```
sessionRate = 5000 × 1.176 × 1.4 × 1.1 = 9,039 XAF/session
monthlyEstimate = 9,039 × 2.5 (avg sessions/week) × 4 = 90,390 XAF/month
```

**Displayed:** ≈ 90,000 XAF / month (rounded for readability)

---

## 📅 **BOOKING FLOW**

### **Two Paths:**

#### **1. Book Trial Session** (Simple)
- ✅ Already exists (calendar-based)
- User picks available slot
- Selects trial duration (30 min / 60 min)
- States goal/reason for trial
- Pays for trial (fixed rate)

**Improvements Needed:**
- Capture more data during trial booking:
  - Specific learning challenges
  - Preferred communication style
  - Emergency contact (for parents)

---

#### **2. Book Tutor** (Complex - NEW)

**Step 1: Session Frequency**
```
How often do you need sessions?

⚪ 1x per week (4 sessions/month)
⚪ 2x per week (8 sessions/month) ← Prefilled if from survey
⚪ 3x per week (12 sessions/month)
⚪ Custom schedule

Monthly Total: 35,000 XAF
```

**Step 2: Days Selection**
```
Which days work best?

Based on tutor availability:

Mon  Tue  Wed  Thu  Fri  Sat  Sun
 ✓    -    ✓    -    ✓    -    -

← Prefilled from survey if available
```

**Step 3: Time Selection**
```
Select your preferred times:

Monday:
⚪ 9:00 AM - 10:00 AM
⚪ 3:00 PM - 4:00 PM  ← Prefilled from survey
⚪ 6:00 PM - 7:00 PM

Wednesday:
⚪ 9:00 AM - 10:00 AM
⚪ 3:00 PM - 4:00 PM  ← Prefilled
⚪ 6:00 PM - 7:00 PM

Friday:
⚪ 3:00 PM - 4:00 PM  ← Prefilled
⚪ 6:00 PM - 7:00 PM

Note: Tutor has 3 other students on Monday 3-4 PM ⚠️
```

**Step 4: Location Preference**
```
Where should sessions happen?

⚪ Online (Google Meet / Zoom)
⚪ Onsite at learner's home
⚪ Hybrid (some online, some onsite)

← Prefilled from survey
```

**Step 5: Review & Confirm**
```
📋 Booking Summary

Tutor: Dr. Marie Ngono
Subject: Mathematics

Schedule:
- Monday 3:00 PM - 4:00 PM (Online)
- Wednesday 3:00 PM - 4:00 PM (Online)
- Friday 3:00 PM - 4:00 PM (Onsite)

Location: Hybrid (2 online, 1 onsite)
Frequency: 3x per week (12 sessions/month)

💰 Payment
Monthly Total: 42,000 XAF
Per Session: 3,500 XAF

Payment Options:
⚪ Pay full month upfront (-10% discount = 37,800 XAF)
⚪ Pay bi-weekly (2 payments of 21,000 XAF)
⚪ Pay weekly (4 payments of 10,500 XAF)

All payments add credits to your account.
Credits are deducted per session.

[Send Request to Tutor]
```

---

## 📩 **REQUEST FLOW**

### **Student/Parent Side:**
1. Submit booking request
2. Request appears in dashboard as "Pending"
3. Card shows:
   - Tutor photo, name
   - Request date
   - Status badge
   - "View Details" button

### **Tutor Side:**
1. Request appears in tutor dashboard
2. Can view full request details:
   - Student/parent info
   - Requested schedule
   - Payment plan
   - Student survey data (relevant parts)
3. Actions:
   - ✅ **Approve** (confirmed)
   - ❌ **Reject** with reason
   - 📝 **Propose Modification** (different times/days)

### **Smart Matching Logic:**
- Check tutor availability (existing bookings)
- Highlight potential conflicts
- Suggest alternative times if tutor is busy
- Consider tutor's preference (online/onsite/hybrid)
- Match student survey data with tutor specialties

---

## 💾 **DATABASE SCHEMA UPDATES**

### **New Table: `session_requests`**
```sql
CREATE TABLE session_requests (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  tutor_id UUID REFERENCES auth.users(id),
  requester_id UUID REFERENCES auth.users(id),
  requester_type TEXT CHECK (requester_type IN ('student', 'parent')),
  learner_id UUID REFERENCES auth.users(id), -- if parent booking for child
  
  -- Session Details
  subject TEXT NOT NULL,
  session_frequency INT NOT NULL, -- sessions per week
  total_monthly_sessions INT NOT NULL,
  
  -- Schedule (JSONB for flexibility)
  requested_schedule JSONB NOT NULL, 
  -- Example: [{"day": "Monday", "time": "15:00", "duration": 60, "location": "online"}, ...]
  
  -- Location
  location_preference TEXT CHECK (location_preference IN ('online', 'onsite', 'hybrid')),
  onsite_address TEXT, -- if onsite or hybrid
  
  -- Payment
  monthly_total DECIMAL(10,2) NOT NULL,
  per_session_rate DECIMAL(10,2) NOT NULL,
  payment_plan TEXT CHECK (payment_plan IN ('monthly', 'biweekly', 'weekly')),
  
  -- Request Details
  learner_survey_data JSONB, -- relevant survey responses
  special_requests TEXT,
  
  -- Status
  status TEXT DEFAULT 'pending' CHECK (status IN ('pending', 'approved', 'rejected', 'modified', 'cancelled')),
  tutor_response_notes TEXT,
  modified_schedule JSONB, -- if tutor proposes changes
  
  -- Timestamps
  created_at TIMESTAMPTZ DEFAULT NOW(),
  responded_at TIMESTAMPTZ,
  expires_at TIMESTAMPTZ DEFAULT NOW() + INTERVAL '7 days'
);
```

### **New Table: `recurring_sessions`**
```sql
CREATE TABLE recurring_sessions (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  request_id UUID REFERENCES session_requests(id),
  tutor_id UUID REFERENCES auth.users(id),
  learner_id UUID REFERENCES auth.users(id),
  parent_id UUID REFERENCES auth.users(id), -- nullable
  
  -- Schedule
  weekly_schedule JSONB NOT NULL,
  -- Example: [{"day": "Monday", "time": "15:00", "duration": 60, "location": "online"}, ...]
  
  -- Payment
  monthly_total DECIMAL(10,2) NOT NULL,
  per_session_rate DECIMAL(10,2) NOT NULL,
  payment_plan TEXT NOT NULL,
  next_payment_due DATE,
  credits_allocated INT DEFAULT 0, -- sessions paid for
  credits_used INT DEFAULT 0, -- sessions completed
  
  -- Status
  is_active BOOLEAN DEFAULT TRUE,
  start_date DATE NOT NULL,
  end_date DATE, -- nullable (ongoing)
  
  -- Timestamps
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);
```

### **Update Table: `tutor_profiles`**
```sql
ALTER TABLE tutor_profiles
ADD COLUMN per_session_rate DECIMAL(10,2), -- base rate per session
ADD COLUMN visibility_subscription_active BOOLEAN DEFAULT FALSE,
ADD COLUMN visibility_subscription_expires DATE,
ADD COLUMN credential_multiplier DECIMAL(3,2) DEFAULT 1.0, -- admin adjustable
ADD COLUMN admin_price_override DECIMAL(10,2); -- admin can manually set price
```

### **Update Table: `learner_profiles` & `parent_profiles`**
```sql
ALTER TABLE learner_profiles
ADD COLUMN preferred_schedule JSONB, -- from survey
ADD COLUMN preferred_session_frequency INT, -- from survey
ADD COLUMN preferred_location TEXT; -- from survey

ALTER TABLE parent_profiles
ADD COLUMN preferred_schedule JSONB,
ADD COLUMN preferred_session_frequency INT,
ADD COLUMN preferred_location TEXT;
```

---

## 🛠️ **IMPLEMENTATION BREAKDOWN**

### **Phase 1: Pricing Display (2 days)**
1. ✅ Create pricing calculation service
2. ✅ Update `TutorService` to calculate monthly estimates
3. ✅ Update tutor card UI in `find_tutors_screen.dart`
4. ✅ Add pricing breakdown to tutor detail page
5. ✅ Update sample tutor JSON with per-session rates
6. ✅ Test pricing calculations

### **Phase 2: Database Schema (1 day)**
7. ✅ Create migration SQL file
8. ✅ Add new tables: `session_requests`, `recurring_sessions`
9. ✅ Update existing tables: `tutor_profiles`, `learner_profiles`, `parent_profiles`
10. ✅ Add indexes for performance
11. ✅ Test schema with sample data

### **Phase 3: Booking Flow UI (3 days)**
12. ✅ Create `BookTutorScreen` with multi-step flow
13. ✅ Implement frequency selection
14. ✅ Implement days selection (prefilled from survey)
15. ✅ Implement time selection with tutor availability
16. ✅ Implement location preference
17. ✅ Implement review & payment plan selection
18. ✅ Create prefill logic from survey data

### **Phase 4: Request Management (2 days)**
19. ✅ Create "My Requests" screen for students/parents
20. ✅ Create "Pending Requests" section in tutor dashboard
21. ✅ Implement approve/reject/modify actions
22. ✅ Create request detail view
23. ✅ Add smart matching suggestions for tutors

### **Phase 5: Backend Integration (2 days)**
24. ✅ Create `BookingService` in Flutter
25. ✅ Implement request submission
26. ✅ Implement request fetching (student/parent/tutor views)
27. ✅ Implement approve/reject/modify actions
28. ✅ Add real-time updates (Supabase Realtime)

### **Phase 6: Credits & Payment Flow (linked to Week 4)**
29. ⏳ Integrate with Fapshi for credit purchases
30. ⏳ Implement credit deduction logic
31. ⏳ Handle payment plans (monthly/biweekly/weekly)
32. ⏳ Implement discount for upfront payment

---

## ✅ **ACCEPTANCE CRITERIA**

### **Pricing Display:**
- [x] All tutor cards show monthly estimates
- [x] Monthly estimate is calculated correctly
- [x] "based on X sessions/week" is visible
- [x] Verified badge uses primary blue color
- [x] Tutor detail page shows pricing breakdown

### **Booking Flow:**
- [ ] User can select session frequency
- [ ] Days are prefilled from survey data
- [ ] Times are prefilled from survey data
- [ ] Location preference is prefilled
- [ ] Tutor availability is checked
- [ ] Conflicts are highlighted
- [ ] Payment plan options are clear
- [ ] Monthly total is calculated correctly
- [ ] Discount for upfront payment is applied

### **Request Management:**
- [ ] Student/parent sees pending requests
- [ ] Tutor sees pending requests
- [ ] Tutor can approve/reject/modify
- [ ] Request details show all relevant info
- [ ] Status updates in real-time

### **Smart Matching:**
- [ ] Survey data is used for prefilling
- [ ] Tutor availability is checked
- [ ] Alternative times are suggested
- [ ] Conflicts are prevented

---

## 🎯 **SUCCESS METRICS**

- **80%+ booking completion rate** (users who start booking, complete it)
- **70%+ tutor acceptance rate** (tutors approve requests)
- **90%+ accuracy in prefilling** (survey data matches user needs)
- **<5% booking conflicts** (double-bookings or scheduling errors)
- **<3 clicks to book** (from tutor card to request sent)

---

## 📋 **TODO LIST UPDATES**

### **New TODOs (P0 - This Feature):**
1. ✅ **Update Pricing Display** - Show monthly estimates on tutor cards
2. ✅ **Create Pricing Calculation Service** - Algorithm for monthly pricing
3. ⏳ **Database Schema Migration** - Add booking & recurring session tables
4. ⏳ **Build Booking Flow UI** - Multi-step booking wizard
5. ⏳ **Implement Request Management** - Student/parent/tutor views
6. ⏳ **Add Smart Prefilling** - Use survey data to prefill booking
7. ⏳ **Backend Integration** - Connect booking to Supabase
8. ⏳ **Real-time Updates** - Live status for requests

### **Updated Existing TODOs:**
- **Ticket #6 (Session Request Flow)** → Replaced with comprehensive booking flow
- **Ticket #7 (Tutor Request Management)** → Enhanced with modify action
- **Ticket #8 (Confirmed Sessions)** → Linked to recurring sessions table

---

## 🚀 **NEXT STEPS**

1. ✅ Implement pricing display (Phase 1)
2. ✅ Update database schema (Phase 2)
3. ⏳ Build booking flow UI (Phase 3)
4. ⏳ Implement request management (Phase 4)
5. ⏳ Backend integration (Phase 5)
6. ⏳ Credits & payments (Phase 6 - Week 4)

---

**Estimated Total Time:** 10 days (2 weeks)  
**Dependencies:** Database access, Fapshi API (for Phase 6)  
**Risks:** Complex booking logic, time zone handling, availability conflicts

---

**Last Updated:** October 29, 2025  
**Status:** Planning Complete, Ready for Implementation 🚀

