# 🎯 PrepSkul Implementation Plan
## Combining 5-Day & 6-Week Roadmaps

---

## ✅ COMPLETED TODAY

### 1. Modern UI Redesign ✅
- ✅ Clean, professional tutor cards
- ✅ Full-page tutor detail screen
- ✅ In-app YouTube video player
- ✅ Modern search & filters
- ✅ Realistic pricing (2,500 - 8,000 XAF)
- ✅ Blue verified badge (primary color)
- ✅ Sample data with 10 diverse tutors

---

## 🔥 IMMEDIATE NEXT STEPS (Before anything else)

### Step 1: Fix Database (30 min)
**Run this SQL in Supabase NOW:**
```sql
-- Add user_id column to learner_profiles
ALTER TABLE learner_profiles 
ADD COLUMN IF NOT EXISTS user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE;

CREATE INDEX IF NOT EXISTS idx_learner_profiles_user_id ON learner_profiles(user_id);

-- Add user_id column to parent_profiles
ALTER TABLE parent_profiles 
ADD COLUMN IF NOT EXISTS user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE;

CREATE INDEX IF NOT EXISTS idx_parent_profiles_user_id ON parent_profiles(user_id);

SELECT '✅ Database fixed!' AS status;
```

### Step 2: Test the App (10 min)
- Run `flutter run`
- Sign up as student/parent
- Complete survey
- Navigate to Find Tutors
- Click a tutor → see video play in-app
- Test filters

---

## 📅 WEEK-BY-WEEK IMPLEMENTATION

---

## **WEEK 1: Admin System & Foundations** (Nov 4-8)

### Day 1: Admin Dashboard Setup (Mon)
**Time: 6-8 hours**

**Morning (4 hrs):**
1. ✅ Set up Next.js admin project
2. ✅ Configure Supabase connection
3. ✅ Build admin login page
4. ✅ Create admin layout with navigation

**Afternoon (2-4 hrs):**
5. ✅ Build pending tutors list page
6. ✅ Fetch tutors with status='pending'
7. ✅ Display tutor cards with key info

**Deliverable:** Admin can log in and see pending tutors

---

### Day 2: Tutor Review System (Tue)
**Time: 6-8 hours**

**Morning (4 hrs):**
1. ✅ Build tutor detail view for admin
2. ✅ Show all submitted documents
3. ✅ Display profile photo, ID, certificates
4. ✅ Add approve/reject buttons

**Afternoon (2-4 hrs):**
5. ✅ Create API route for approve action
6. ✅ Create API route for reject action
7. ✅ Update database status
8. ✅ Add admin notes field

**Database Changes:**
```sql
-- Already done in admin dashboard
ALTER TABLE tutor_profiles 
ADD COLUMN IF NOT EXISTS status TEXT DEFAULT 'pending';
ADD COLUMN IF NOT EXISTS admin_review_notes TEXT;
ADD COLUMN IF NOT EXISTS reviewed_by UUID;
ADD COLUMN IF NOT EXISTS reviewed_at TIMESTAMPTZ;
```

**Deliverable:** Admin can approve/reject tutors

---

### Day 3: Notifications & Tutor Dashboard (Wed)
**Time: 6-8 hours**

**Morning (4 hrs):**
1. ✅ Set up email service (SendGrid/Resend)
2. ✅ Create approval email template
3. ✅ Create rejection email template
4. ✅ Send email on status change

**Afternoon (2-4 hrs):**
5. ✅ Update Flutter tutor dashboard
6. ✅ Show "Pending Review" banner
7. ✅ Show "Approved" status
8. ✅ Show rejection reason if rejected
9. ✅ Hide features until approved

**Deliverable:** Tutors receive emails & see status in app

---

### Day 4: Testing & Bug Fixes (Thu)
**Time: 4-6 hours**

1. Test full tutor flow: signup → survey → review → approval
2. Fix any bugs in admin dashboard
3. Fix any bugs in Flutter app
4. Test email delivery
5. Test different approval/rejection scenarios

**Deliverable:** Week 1 features work end-to-end

---

### Day 5: Catch-up & Polish (Fri)
**Time: 4-6 hours**

1. Complete any incomplete tasks from Week 1
2. Polish admin UI
3. Polish tutor dashboard
4. Write documentation
5. Prepare for Week 2

---

## **WEEK 2: Discovery & Matching** (Nov 11-15)

### Day 1: Backend Setup (Mon)
**Time: 4-6 hours**

1. Create database indexes for search
2. Build search API endpoint
3. Test query performance
4. Optimize for speed

**Database:**
```sql
CREATE INDEX idx_tutor_profiles_subjects ON tutor_profiles USING GIN (subjects);
CREATE INDEX idx_tutor_profiles_city ON tutor_profiles (city);
CREATE INDEX idx_tutor_profiles_hourly_rate ON tutor_profiles (hourly_rate);
CREATE INDEX idx_tutor_profiles_status ON tutor_profiles (status);
```

---

### Day 2: Enhanced Search & Filters (Tue)
**Time: 6-8 hours**

1. ✅ Improve search algorithm (name, subjects)
2. Add location filter
3. Add experience level filter
4. Add availability filter
5. Test all filters together

---

### Day 3: Smart Matching Algorithm (Wed)
**Time: 6-8 hours**

1. Build matching algorithm
2. Match based on learner survey
3. Match subjects needed
4. Match budget range
5. Match location preferences
6. Display "Recommended for you" section

---

### Day 4: Tutor Profile Enhancements (Thu)
**Time: 6-8 hours**

1. Add availability calendar
2. Show tutor's schedule
3. Add "Request Session" button
4. Improve video player UX
5. Add social media links
6. Add reviews section (placeholder)

---

### Day 5: Testing & Polish (Fri)
**Time: 4-6 hours**

1. Test search performance
2. Test all filters
3. Test matching algorithm
4. Fix bugs
5. Polish UI

---

## **WEEK 3: Booking & Sessions** (Nov 18-22)

### Day 1: Session Request Flow (Mon-Tue)
**Time: 12 hours**

**Database:**
```sql
CREATE TABLE session_requests (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  tutor_id UUID REFERENCES auth.users(id),
  requester_id UUID REFERENCES auth.users(id),
  requester_type TEXT CHECK (requester_type IN ('student', 'parent')),
  learner_id UUID,
  subject TEXT NOT NULL,
  level TEXT NOT NULL,
  session_type TEXT CHECK (session_type IN ('tutoring', 'test_session')),
  requested_date DATE NOT NULL,
  requested_time TIME NOT NULL,
  duration_minutes INT DEFAULT 60,
  session_details TEXT,
  status TEXT DEFAULT 'pending',
  created_at TIMESTAMPTZ DEFAULT NOW()
);
```

**Features:**
1. Build booking screen
2. Show tutor availability
3. Date/time picker
4. Subject selection
5. Add session notes
6. Price calculation
7. Send request

---

### Day 2: Tutor Request Management (Wed)
**Time: 6-8 hours**

1. Build tutor requests screen
2. Show pending requests
3. Request detail view
4. Accept button
5. Reject button (with reason)
6. Notification to student/parent

---

### Day 3: Confirmed Sessions (Thu-Fri)
**Time: 12 hours**

**Database:**
```sql
CREATE TABLE sessions (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  tutor_id UUID REFERENCES auth.users(id),
  learner_id UUID REFERENCES auth.users(id),
  parent_id UUID,
  subject TEXT NOT NULL,
  scheduled_date DATE NOT NULL,
  scheduled_time TIME NOT NULL,
  duration_minutes INT DEFAULT 60,
  status TEXT DEFAULT 'scheduled',
  created_at TIMESTAMPTZ DEFAULT NOW()
);
```

**Features:**
1. Convert accepted request to session
2. Build "My Sessions" screen
3. Show upcoming sessions
4. Show past sessions
5. Session detail view
6. Countdown timer
7. Cancel session option

---

## **WEEK 4: Payments** (Nov 25-29)

### Day 1-2: Fapshi Integration (Mon-Tue)
**Time: 12-16 hours**

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
  status TEXT DEFAULT 'pending',
  platform_fee DECIMAL(10,2),
  tutor_earnings DECIMAL(10,2),
  created_at TIMESTAMPTZ DEFAULT NOW()
);
```

**Features:**
1. Research Fapshi API documentation
2. Get API credentials
3. Build payment service
4. Integrate MTN Mobile Money
5. Integrate Orange Money
6. Handle payment callbacks
7. Update session status on payment
8. Store transaction records

---

### Day 3-4: Credit System (Wed-Thu)
**Time: 12 hours**

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
  reference_id UUID,
  description TEXT,
  balance_after DECIMAL(10,2),
  created_at TIMESTAMPTZ DEFAULT NOW()
);
```

**Features:**
1. Build credit purchase flow
2. Show credit balance
3. Deduct credits for sessions
4. Refund on cancellation
5. Credit history view

---

### Day 5: Testing & Polish (Fri)
**Time: 6-8 hours**

1. Test payment flow end-to-end
2. Test credit system
3. Handle payment failures
4. Security audit
5. Fix bugs

---

## **WEEK 5: Session Management & Communication** (Dec 2-6)

### Day 1-2: Session Tracking (Mon-Tue)
**Time: 12 hours**

1. Track session start/end
2. Attendance confirmation
3. Handle no-shows
4. Auto-complete after duration
5. Session history

---

### Day 2-3: Feedback & Reviews (Tue-Wed)
**Time: 12 hours**

**Database:**
```sql
CREATE TABLE reviews (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  session_id UUID REFERENCES sessions(id),
  reviewer_id UUID REFERENCES auth.users(id),
  reviewee_id UUID REFERENCES auth.users(id),
  rating INT CHECK (rating BETWEEN 1 AND 5),
  review_text TEXT,
  tags TEXT[],
  created_at TIMESTAMPTZ DEFAULT NOW()
);
```

**Features:**
1. Build review screen
2. 5-star rating
3. Written feedback
4. Predefined tags
5. Display on tutor profile
6. Calculate average rating

---

### Day 4-5: Messaging System (Thu-Fri)
**Time: 12 hours**

**Option 1: Stream Chat (Recommended)**
- Sign up for Stream
- Integrate Stream Chat SDK
- Faster implementation

**Option 2: Custom with Supabase Realtime**
```sql
CREATE TABLE conversations (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  participant1_id UUID,
  participant2_id UUID,
  last_message_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE messages (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  conversation_id UUID,
  sender_id UUID,
  message TEXT,
  is_read BOOLEAN DEFAULT FALSE,
  created_at TIMESTAMPTZ DEFAULT NOW()
);
```

**Features:**
1. Messages list screen
2. Chat screen
3. Real-time messaging
4. Read receipts
5. Notification badges

---

## **WEEK 6: Final Polish & Launch** (Dec 9-13)

### Day 1-2: Notifications (Mon-Tue)
**Time: 12 hours**

1. Setup Firebase Cloud Messaging
2. Notification permission
3. Session request notifications
4. Approval notifications
5. Payment notifications
6. Session starting soon (30 min before)
7. Review reminders

---

### Day 3: Tutor Payouts (Wed)
**Time: 6-8 hours**

**Database:**
```sql
CREATE TABLE payouts (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  tutor_id UUID REFERENCES auth.users(id),
  amount DECIMAL(10,2) NOT NULL,
  status TEXT DEFAULT 'pending',
  requested_at TIMESTAMPTZ DEFAULT NOW(),
  processed_at TIMESTAMPTZ
);
```

**Features:**
1. View earnings
2. Request payout
3. Payout history
4. Admin processes payouts

---

### Day 4-5: Testing & Launch Prep (Thu-Fri)
**Time: 12-16 hours**

**End-to-End Testing:**
1. Tutor flow: signup → approval → sessions → payouts
2. Student flow: signup → discovery → booking → payment → session → review
3. Parent flow: signup → discovery → booking → payment → session → review
4. Admin flow: review tutors, process payouts

**Bug Fixes:**
1. Fix all critical bugs
2. Fix all high-priority bugs
3. Document known minor bugs for V1.1

**Performance:**
1. Optimize database queries
2. Add caching where needed
3. Test on slow connections
4. Test with many users

**Security:**
1. Audit RLS policies
2. Test authentication
3. Test payment security
4. Review API endpoints

**Analytics:**
1. Setup Firebase Analytics
2. Add Crashlytics
3. Setup key event tracking
4. Create monitoring dashboard

---

## 🎯 SUCCESS CRITERIA

### By End of Week 6:

**Users:**
- ✅ Tutors can sign up & get approved
- ✅ Students/parents can find tutors
- ✅ Users can book sessions
- ✅ Payments work smoothly
- ✅ Sessions are tracked
- ✅ Reviews are collected
- ✅ Messaging works
- ✅ Notifications delivered

**Technical:**
- ✅ < 2 sec app load time
- ✅ 99%+ uptime
- ✅ < 1% payment failure rate
- ✅ All critical features working
- ✅ No major bugs
- ✅ Analytics tracking

**Business:**
- ✅ 10+ approved tutors
- ✅ 50+ students/parents
- ✅ 20+ sessions completed
- ✅ 4.0+ avg rating
- ✅ Platform fee collected

---

## 📊 DAILY SCHEDULE (Example)

**Morning (9am - 1pm):** 4 hours
- Deep work on main feature
- Coding & implementation
- Database changes

**Afternoon (2pm - 6pm):** 4 hours
- Continue feature
- Testing
- Bug fixes
- Polish UI

**Evening (Optional):** 2-3 hours
- Catch-up if behind
- Documentation
- Planning next day

**Total per day:** 6-10 hours
**Total per week:** 30-50 hours

---

## 🚀 LET'S START!

### RIGHT NOW:
1. ✅ Run the SQL to fix database
2. ✅ Test the app
3. ✅ Verify everything works

### NEXT SESSION:
Choose one:
- **"Start Week 1 Day 1"** - Begin admin dashboard
- **"Fix database first"** - Make sure DB is perfect
- **"Test current features"** - Ensure what we have works

**What do you want to focus on first?** 🎯

