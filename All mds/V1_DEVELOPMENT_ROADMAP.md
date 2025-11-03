# 📋 PrepSkul V1 Development Roadmap

**Version:** 1.0.0  
**Target Launch:** 6-8 weeks  
**Last Updated:** October 28, 2025

---

## 🎯 **V1 CORE VISION**

**PrepSkul V1** is an MVP tutoring platform connecting Cameroonian tutors with students/parents through:
- ✅ Complete tutor verification system
- ✅ Smart matching based on needs
- ✅ In-platform payment processing
- ✅ Session tracking & feedback
- ✅ Basic messaging

**NOT in V1:**
- ❌ AI session monitoring
- ❌ Advanced analytics
- ❌ Multiple payment gateways (only Fapshi)
- ❌ In-app video conferencing

---

## ✅ **COMPLETED (Foundation)**

### **Phase 0: Core Infrastructure** ✅
- [x] Project setup (Flutter + Supabase)
- [x] Authentication (Phone OTP + Password)
- [x] User roles (Tutor, Student, Parent)
- [x] Database schema (profiles, tutor_profiles, learner_profiles, parent_profiles)
- [x] Supabase Storage setup (profile-photos, documents buckets)
- [x] File upload service (StorageService)
- [x] Image picker (camera/gallery/files)

### **Phase 1: Onboarding Flows** ✅
- [x] Beautiful splash & onboarding screens
- [x] Login/Signup with phone auth
- [x] Password reset flow
- [x] OTP verification
- [x] Tutor survey (10-step comprehensive form)
- [x] Student survey (dynamic, path-based)
- [x] Parent survey (dynamic, multi-child support)
- [x] Auto-save functionality
- [x] Profile completion tracking system ⭐ **NEW**
- [x] Submission validation (blocks until 100% complete) ⭐ **NEW**

### **Phase 2: Navigation & Dashboards** ✅
- [x] Role-based bottom navigation
- [x] Tutor home screen (with completion status)
- [x] Student home screen (placeholder)
- [x] Parent home screen (placeholder)
- [x] Profile screen (logout, settings)

---

## 🚧 **IN PROGRESS**

### **Current Sprint: Bug Fixes & iOS Build**
- [ ] Fix iOS build errors (Xcode build service issues)
- [ ] Test Profile Completion System end-to-end
- [ ] Fix UI overflow in tutor onboarding (line 2881)
- [ ] Test file uploads on iOS

---

## 📅 **6-WEEK DEVELOPMENT PLAN**

---

## **WEEK 1: Admin System & Tutor Verification**

### **Ticket #1: Admin Dashboard (Next.js)** 🎯
**Priority:** P0 - Critical  
**Estimate:** 3 days

**Requirements:**
- Admin authentication (Supabase)
- View pending tutor applications
- Review tutor profiles (all submitted data)
- Approve/Reject with reason
- Send email/SMS notifications

**Acceptance Criteria:**
- Admin can login securely
- See list of pending tutors
- View complete tutor profile
- Approve/reject tutors
- Tutor receives notification

**Database Changes:**
```sql
ALTER TABLE tutor_profiles 
ADD COLUMN status TEXT DEFAULT 'pending' CHECK (status IN ('pending', 'approved', 'rejected'));

ADD COLUMN admin_review_notes TEXT;
ADD COLUMN reviewed_by UUID REFERENCES auth.users(id);
ADD COLUMN reviewed_at TIMESTAMPTZ;
```

---

### **Ticket #2: Tutor Verification Email/SMS** 🎯
**Priority:** P0 - Critical  
**Estimate:** 1 day

**Requirements:**
- Setup email service (SendGrid/Resend)
- Setup SMS service (Twilio)
- Email templates (approved/rejected)
- SMS templates (approved/rejected)

**Acceptance Criteria:**
- Tutor receives email on approval
- Tutor receives SMS notification
- Templates are professional

---

### **Ticket #3: Tutor Dashboard Updates** 🎯
**Priority:** P1 - High  
**Estimate:** 1 day

**Requirements:**
- Show "Approved" status
- Enable tutor features after approval
- Hide "Pending" banner
- Show active sessions
- Show earnings (placeholder)

**Acceptance Criteria:**
- Approved tutors see full dashboard
- Pending tutors see limited view
- Rejected tutors see rejection reason

---

## **WEEK 2: Discovery & Matching**

### **Ticket #4: Tutor Discovery for Students/Parents** 🎯
**Priority:** P0 - Critical  
**Estimate:** 3 days

**Requirements:**
- Search tutors by subject/level
- Filter by location, rate, experience
- View tutor profiles
- Smart matching based on learner profile
- "Recommended Tutors" section

**UI Components:**
- Search bar with filters
- Tutor cards (photo, name, subjects, rate, rating)
- Filter sheet (subject, level, location, price range)
- Tutor detail page

**Acceptance Criteria:**
- Students can search for tutors
- Parents can search for tutors
- Filters work correctly
- Recommended tutors show at top
- Tutor profiles display correctly

**Database:**
```sql
CREATE INDEX idx_tutor_profiles_tutoring_areas 
ON tutor_profiles USING GIN (tutoring_areas);

CREATE INDEX idx_tutor_profiles_city 
ON tutor_profiles (city);

CREATE INDEX idx_tutor_profiles_hourly_rate 
ON tutor_profiles (hourly_rate);
```

---

### **Ticket #5: Tutor Profile Page** 🎯
**Priority:** P0 - Critical  
**Estimate:** 2 days

**Requirements:**
- Display all tutor information
- Show profile photo
- Show subjects & levels
- Show hourly rate
- Show availability calendar
- Show intro video (YouTube)
- "Request Session" button
- Reviews/ratings (placeholder)

**Acceptance Criteria:**
- All tutor info displays correctly
- YouTube video plays inline
- Availability is clear
- CTA button is prominent

---

## **WEEK 3: Booking & Sessions**

### **Ticket #6: Session Request Flow** 🎯
**Priority:** P0 - Critical  
**Estimate:** 3 days

**Requirements:**
- Student/parent selects tutor
- Choose subject, level, type (tutoring/test)
- Select date & time from tutor availability
- Add session details (goals, needs)
- Send request to tutor

**Database:**
```sql
CREATE TABLE session_requests (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  tutor_id UUID REFERENCES auth.users(id),
  requester_id UUID REFERENCES auth.users(id),
  requester_type TEXT CHECK (requester_type IN ('student', 'parent')),
  learner_id UUID REFERENCES auth.users(id), -- if parent
  subject TEXT NOT NULL,
  level TEXT NOT NULL,
  session_type TEXT CHECK (session_type IN ('tutoring', 'test_session')),
  requested_date DATE NOT NULL,
  requested_time TIME NOT NULL,
  duration_minutes INT DEFAULT 60,
  session_details TEXT,
  status TEXT DEFAULT 'pending' CHECK (status IN ('pending', 'accepted', 'rejected', 'cancelled')),
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);
```

**Acceptance Criteria:**
- User can select available slot
- All details are captured
- Request is saved to database
- Tutor receives notification

---

### **Ticket #7: Tutor Request Management** 🎯
**Priority:** P0 - Critical  
**Estimate:** 2 days

**Requirements:**
- Tutor sees pending requests
- Can accept/reject requests
- Can propose different time
- Can add notes

**Acceptance Criteria:**
- Tutor sees all requests
- Can accept/reject with reason
- Student/parent gets notification

---

### **Ticket #8: Confirmed Sessions** 🎯
**Priority:** P0 - Critical  
**Estimate:** 2 days

**Requirements:**
- Convert accepted request to session
- Show in "My Sessions" for both parties
- Display session details
- Countdown to session
- Join session button (placeholder)

**Database:**
```sql
CREATE TABLE sessions (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  tutor_id UUID REFERENCES auth.users(id),
  learner_id UUID REFERENCES auth.users(id),
  parent_id UUID REFERENCES auth.users(id), -- nullable
  subject TEXT NOT NULL,
  level TEXT NOT NULL,
  session_type TEXT NOT NULL,
  scheduled_date DATE NOT NULL,
  scheduled_time TIME NOT NULL,
  duration_minutes INT DEFAULT 60,
  status TEXT DEFAULT 'scheduled' CHECK (status IN ('scheduled', 'in_progress', 'completed', 'cancelled', 'no_show')),
  session_notes TEXT,
  tutor_joined_at TIMESTAMPTZ,
  learner_joined_at TIMESTAMPTZ,
  ended_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);
```

**Acceptance Criteria:**
- Session displays correctly
- Both parties can see it
- Status updates in real-time
- Can cancel session

---

## **WEEK 4: Payments Integration**

### **Ticket #9: Fapshi Payment Integration** 🎯
**Priority:** P0 - Critical  
**Estimate:** 3 days

**Requirements:**
- Integrate Fapshi API
- Student/parent pays before session
- Funds held in escrow
- Release to tutor after session
- Handle payment failures
- Transaction records

**Database:**
```sql
CREATE TABLE transactions (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  session_id UUID REFERENCES sessions(id),
  payer_id UUID REFERENCES auth.users(id),
  receiver_id UUID REFERENCES auth.users(id),
  amount DECIMAL(10,2) NOT NULL,
  currency TEXT DEFAULT 'XAF',
  payment_method TEXT DEFAULT 'mobile_money',
  fapshi_transaction_id TEXT,
  status TEXT DEFAULT 'pending' CHECK (status IN ('pending', 'processing', 'completed', 'failed', 'refunded')),
  platform_fee DECIMAL(10,2),
  tutor_earnings DECIMAL(10,2),
  payment_initiated_at TIMESTAMPTZ,
  payment_completed_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ DEFAULT NOW()
);
```

**Acceptance Criteria:**
- User can initiate payment
- Fapshi API processes payment
- Payment status tracked
- Funds held until session complete
- Receipt generated

---

### **Ticket #10: Credit System** 🎯
**Priority:** P1 - High  
**Estimate:** 2 days

**Requirements:**
- Students/parents can buy credits
- Credits deducted for sessions
- View credit balance
- Credit purchase history
- Refund to credits if session cancelled

**Database:**
```sql
CREATE TABLE user_credits (
  user_id UUID PRIMARY KEY REFERENCES auth.users(id),
  balance DECIMAL(10,2) DEFAULT 0,
  total_purchased DECIMAL(10,2) DEFAULT 0,
  total_spent DECIMAL(10,2) DEFAULT 0,
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE credit_transactions (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id UUID REFERENCES auth.users(id),
  amount DECIMAL(10,2) NOT NULL,
  type TEXT CHECK (type IN ('purchase', 'deduction', 'refund', 'bonus')),
  reference_id UUID, -- session_id or transaction_id
  description TEXT,
  balance_after DECIMAL(10,2),
  created_at TIMESTAMPTZ DEFAULT NOW()
);
```

**Acceptance Criteria:**
- User can buy credits
- Credits deducted correctly
- Balance updates in real-time
- History is accurate

---

## **WEEK 5: Session Management & Feedback**

### **Ticket #11: Session Tracking** 🎯
**Priority:** P0 - Critical  
**Estimate:** 3 days

**Requirements:**
- Track session start/end times
- Both parties confirm attendance
- Handle no-shows
- Auto-complete after duration
- Session duration tracking

**Acceptance Criteria:**
- Session starts on time
- Both parties can mark present
- No-shows handled correctly
- Duration tracked accurately
- Auto-completes after time

---

### **Ticket #12: Post-Session Feedback** 🎯
**Priority:** P0 - Critical  
**Estimate:** 2 days

**Requirements:**
- Rating system (1-5 stars)
- Written review
- Predefined tags (knowledgeable, patient, clear, etc.)
- Both tutor and learner can review
- Display on tutor profile

**Database:**
```sql
CREATE TABLE reviews (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  session_id UUID REFERENCES sessions(id),
  reviewer_id UUID REFERENCES auth.users(id),
  reviewee_id UUID REFERENCES auth.users(id),
  reviewer_type TEXT CHECK (reviewer_type IN ('tutor', 'learner', 'parent')),
  rating INT CHECK (rating BETWEEN 1 AND 5),
  review_text TEXT,
  tags TEXT[], -- ['patient', 'knowledgeable', 'clear']
  would_recommend BOOLEAN,
  created_at TIMESTAMPTZ DEFAULT NOW()
);
```

**Acceptance Criteria:**
- User can leave review after session
- Rating and text captured
- Reviews display on profile
- Average rating calculated

---

### **Ticket #13: Messaging System** 🎯
**Priority:** P1 - High  
**Estimate:** 2 days

**Requirements:**
- In-app chat between tutor and student/parent
- Text messages only (V1)
- Read receipts
- Notification badges
- Message history

**Tech Stack:** Stream Chat Flutter

**Acceptance Criteria:**
- Users can send/receive messages
- Messages persist
- Notifications work
- Chat UI is clean

---

## **WEEK 6: Polish & Launch Prep**

### **Ticket #14: Notifications** 🎯
**Priority:** P0 - Critical  
**Estimate:** 2 days

**Requirements:**
- Push notifications (Firebase Cloud Messaging)
- In-app notifications
- Email notifications
- Notification settings

**Notification Types:**
- Session request
- Request accepted/rejected
- Payment received
- Session starting soon (30 min)
- Session completed
- Review received

**Acceptance Criteria:**
- All notification types work
- User can enable/disable types
- Notifications are timely

---

### **Ticket #15: Tutor Earnings & Payouts** 🎯
**Priority:** P1 - High  
**Estimate:** 2 days

**Requirements:**
- View earnings by session
- Total earnings
- Pending payouts
- Request payout
- Payout history

**Database:**
```sql
CREATE TABLE payouts (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  tutor_id UUID REFERENCES auth.users(id),
  amount DECIMAL(10,2) NOT NULL,
  payment_method TEXT,
  payment_details JSONB,
  status TEXT DEFAULT 'pending' CHECK (status IN ('pending', 'processing', 'completed', 'failed')),
  requested_at TIMESTAMPTZ DEFAULT NOW(),
  processed_at TIMESTAMPTZ,
  fapshi_transaction_id TEXT
);
```

**Acceptance Criteria:**
- Tutor sees accurate earnings
- Can request payout
- Payout processed via Fapshi
- Transaction history visible

---

### **Ticket #16: Testing & Bug Fixes** 🎯
**Priority:** P0 - Critical  
**Estimate:** 3 days

**Requirements:**
- End-to-end testing (all user flows)
- Fix all critical bugs
- Performance optimization
- Security audit
- Database optimization

**Test Cases:**
- Tutor signup → approval → discovery → session → payment → payout
- Student signup → discovery → booking → payment → session → review
- Parent signup → discovery → booking for child → payment → session → review

---

### **Ticket #17: Analytics & Monitoring** 🎯
**Priority:** P1 - High  
**Estimate:** 1 day

**Requirements:**
- Firebase Analytics
- Crash reporting (Firebase Crashlytics)
- Performance monitoring
- User behavior tracking

**Key Metrics:**
- User signups (by type)
- Session requests
- Session completions
- Payment success rate
- Average session rating

---

### **Ticket #18: Admin Analytics Dashboard** 🎯
**Priority:** P2 - Medium  
**Estimate:** 2 days

**Requirements:**
- Total users (tutors, students, parents)
- Active sessions
- Revenue (total, this month)
- Top tutors
- User growth charts

---

## 📊 **V1 FEATURE SUMMARY**

| Feature | Status | Priority |
|---------|--------|----------|
| **Authentication** | ✅ Complete | P0 |
| **User Onboarding** | ✅ Complete | P0 |
| **Profile Completion** | ✅ Complete | P0 |
| **Admin Dashboard** | 🔲 To Do | P0 |
| **Tutor Verification** | 🔲 To Do | P0 |
| **Discovery/Search** | 🔲 To Do | P0 |
| **Session Booking** | 🔲 To Do | P0 |
| **Payment (Fapshi)** | 🔲 To Do | P0 |
| **Session Tracking** | 🔲 To Do | P0 |
| **Reviews/Ratings** | 🔲 To Do | P0 |
| **Messaging** | 🔲 To Do | P1 |
| **Notifications** | 🔲 To Do | P0 |
| **Tutor Payouts** | 🔲 To Do | P1 |
| **Analytics** | 🔲 To Do | P1 |

---

## 🎯 **SUCCESS METRICS (V1 Launch)**

### **User Metrics:**
- 50+ verified tutors
- 200+ students/parents registered
- 100+ sessions completed
- 4.0+ average tutor rating

### **Technical Metrics:**
- < 2 sec app load time
- 99.5% uptime
- < 1% payment failure rate
- < 5% session no-show rate

### **Business Metrics:**
- 10,000+ XAF in transactions
- 15% platform fee
- 80% tutor approval rate
- 70% session request acceptance rate

---

## 🚀 **POST-V1 (Future Versions)**

### **V1.1 (Month 2)**
- In-app video conferencing (Jitsi Meet)
- Multiple payment gateways
- Advanced search filters
- Tutor certifications

### **V1.2 (Month 3)**
- AI matching algorithm
- Session recordings
- Advanced analytics
- Loyalty/referral program

### **V2.0 (Month 6)**
- AI session monitoring (PrepSkul AI Bot)
- Speech-to-text session notes
- Learning path recommendations
- Group sessions
- Tutor marketplace (resources, worksheets)

---

## 📞 **CONTACT & SUPPORT**

**Development Team:**
- Lead Developer: [Your Name]
- Backend: Supabase
- Frontend: Flutter
- Payments: Fapshi API
- Admin: Next.js

**External Services:**
- Auth: Supabase
- Database: PostgreSQL (Supabase)
- Storage: Supabase Storage
- SMS: Twilio
- Email: SendGrid/Resend
- Push: Firebase Cloud Messaging
- Chat: Stream Chat Flutter
- Payments: Fapshi

---

## 📝 **NOTES**

1. **Focus on MVP:** Get core features working perfectly before adding bells and whistles
2. **User Experience First:** Every feature should be intuitive and delightful
3. **Payment Security:** All transactions go through the platform - no bypassing
4. **Quality over Quantity:** Better to have 50 great tutors than 500 mediocre ones
5. **Iterate Fast:** Launch, learn, improve

---

**Last Updated:** October 28, 2025  
**Version:** 1.0  
**Status:** Foundation Complete, Week 1 Starting  

🚀 **Let's build PrepSkul V1!**
