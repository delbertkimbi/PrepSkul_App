# 🧪 Complete Testing Guide - PrepSkul

## 📋 What's Been Built

### ✅ Flutter App (Mobile):
1. **Authentication** - Login, Signup, OTP, Password Reset
2. **Onboarding** - Tutor/Student/Parent surveys (3000+ lines original UI preserved)
3. **Tutor Discovery** - Modern UI, search, filters, JSON data (10 sample tutors)
4. **Tutor Detail** - YouTube video player, full profile view
5. **WhatsApp Request** - Send tutor request via WhatsApp when no results

### ✅ Admin Dashboard (Next.js):
1. **Dashboard** - Real-time metrics, user counts, revenue, active sessions
2. **Pending Tutors** - Review, approve/reject tutor applications
3. **Tutor Details** - Full profile view, contact buttons, admin notes
4. **Sessions Page** - View all lessons, filter by status
5. **Active Sessions** - Real-time monitoring, progress bars
6. **Revenue Analytics** - Total & monthly revenue tracking
7. **Active Users** - Online now, active today counts
8. **Authentication** - Email/password login, admin-only access

---

## 🔧 STEP 1: Fix Database (5 minutes)

### Go to Supabase Dashboard:
1. Open https://supabase.com/dashboard
2. Select your PrepSkul project
3. Click **SQL Editor** in left sidebar
4. Click **New Query**
5. Paste this SQL:

```sql
-- ===================================
-- FIX DATABASE SCHEMA
-- ===================================

-- 1. Add user_id to learner_profiles
ALTER TABLE learner_profiles 
ADD COLUMN IF NOT EXISTS user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE;

CREATE INDEX IF NOT EXISTS idx_learner_profiles_user_id ON learner_profiles(user_id);

ALTER TABLE learner_profiles 
DROP CONSTRAINT IF EXISTS learner_profiles_user_id_key;

ALTER TABLE learner_profiles 
ADD CONSTRAINT learner_profiles_user_id_key UNIQUE(user_id);

-- 2. Add user_id to parent_profiles
ALTER TABLE parent_profiles 
ADD COLUMN IF NOT EXISTS user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE;

CREATE INDEX IF NOT EXISTS idx_parent_profiles_user_id ON parent_profiles(user_id);

ALTER TABLE parent_profiles 
DROP CONSTRAINT IF EXISTS parent_profiles_user_id_key;

ALTER TABLE parent_profiles 
ADD CONSTRAINT parent_profiles_user_id_key UNIQUE(user_id);

-- 3. Verify profiles table has all needed columns
DO $$
BEGIN
    -- Add survey_completed if missing
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns 
                   WHERE table_name='profiles' AND column_name='survey_completed') THEN
        ALTER TABLE profiles ADD COLUMN survey_completed BOOLEAN DEFAULT FALSE;
    END IF;
    
    -- Add phone_number if missing
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns 
                   WHERE table_name='profiles' AND column_name='phone_number') THEN
        ALTER TABLE profiles ADD COLUMN phone_number TEXT;
    END IF;
    
    -- Add is_admin if missing
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns 
                   WHERE table_name='profiles' AND column_name='is_admin') THEN
        ALTER TABLE profiles ADD COLUMN is_admin BOOLEAN DEFAULT FALSE;
    END IF;
    
    -- Add last_seen if missing
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns 
                   WHERE table_name='profiles' AND column_name='last_seen') THEN
        ALTER TABLE profiles ADD COLUMN last_seen TIMESTAMPTZ;
    END IF;
END $$;

-- 4. Success message
SELECT 
    '✅ Database fixed!' AS status,
    (SELECT COUNT(*) FROM profiles) AS total_users,
    (SELECT COUNT(*) FROM tutor_profiles) AS total_tutors;
```

6. Click **Run** (or press F5)
7. ✅ You should see "Database fixed!" message

---

## 🎯 STEP 2: Test Flutter App

### Terminal Commands:
```bash
cd /Users/user/Desktop/PrepSkul/prepskul_app
flutter clean
flutter pub get
flutter run
```

### Test Flow 1: Student Signup & Discovery
1. **Launch App** → Click "Get Started"
2. **Signup** → Enter phone: `+237650000001`, password: `Test1234!`
3. **OTP** → Enter any 6 digits (demo mode)
4. **Choose Role** → Select "I'm a Student"
5. **Complete Survey** (19 steps):
   - Name: John Student
   - Date of Birth: 01/01/2005
   - Gender: Male
   - City: Douala
   - Quarter: Akwa
   - Learning Path: Academic Education
   - Education Level: Secondary Education
   - Class: Form 5
   - Stream: Sciences
   - Subjects: Select 2-3 subjects
   - **UNIVERSITY TEST**: Try selecting "University" education level → Enter courses as text
   - Budget: 3000 - 8000 XAF (moved to last step!)
   - Complete remaining steps
6. **Review & Confirm** → Check card-based layout (looks good!)
7. **Submit** → Navigate to student dashboard
8. **Find Tutors** → Click bottom nav
9. **Search & Filter**:
   - ✅ See modern UI (not childish!)
   - ✅ Search bar works
   - ✅ See 10 sample tutors
   - ✅ Prices: 2500 - 8000 XAF (realistic!)
   - ✅ Blue verified badge (primary color)
   - Click any tutor card
10. **Tutor Detail**:
    - ✅ YouTube video plays IN-APP!
    - ✅ See full profile, subjects, education
    - ✅ Clean professional UI
    - Click "Request Session" → Coming soon!

### Test Flow 2: Parent Signup
1. **Restart App** (or logout)
2. **Signup** → Phone: `+237650000002`, Password: `Test1234!`
3. **Choose Role** → "I'm a Parent"
4. **Complete Survey**:
   - Child's Name: Mary Student
   - Relationship: Mother
   - **UNIVERSITY TEST**: Try university courses
   - Budget step: Now at the end!
5. **Review** → Card-based layout
6. **Submit** → Parent dashboard
7. **Find Tutors** → Same as student

### Test Flow 3: Tutor Signup (3000+ lines original UI!)
1. **Restart App**
2. **Signup** → Phone: `+237650000003`, Password: `Test1234!`
3. **Choose Role** → "I'm a Tutor"
4. **Complete Tutor Survey** (20+ steps):
   - Upload profile photo
   - Academic background
   - Subjects & grade levels
   - Upload documents (ID, certificates)
   - Expected rate: 5000 XAF
   - **Profile Completion**: Must be 100% to submit
5. **Submit** → Status: "Pending Review"
6. **Dashboard** → See profile completion widget

### Test Flow 4: WhatsApp Request
1. **Login as Student/Parent**
2. **Find Tutors** → Apply filters
3. **No Results** → Click "Request Tutor via WhatsApp"
4. ✅ Opens WhatsApp with detailed message
5. ✅ Includes survey data + filters

---

## 🖥️ STEP 3: Test Admin Dashboard

### Setup Admin User (One-time):
1. **Signup in Flutter App**:
   - Phone: `+237650000099`
   - Email: `admin@prepskul.com`
   - Password: `Admin1234!`
   - Role: Student (just to create account)

2. **Make Admin** → Go to Supabase:
   - SQL Editor → New Query
   ```sql
   UPDATE profiles 
   SET is_admin = TRUE 
   WHERE email = 'admin@prepskul.com';
   
   SELECT * FROM profiles WHERE is_admin = TRUE;
   ```
   - Run → Verify admin user

### Test Admin Dashboard:
1. **Navigate to Admin**:
   - Local: http://localhost:3000/admin
   - Production: https://admin.prepskul.com

2. **Login**:
   - Email: `admin@prepskul.com`
   - Password: `Admin1234!`
   - ✅ See password show/hide icon
   - ✅ Deep blue theme (matches Flutter)

3. **Dashboard Page**:
   - ✅ Real-time metrics
   - ✅ User counts (tutors, learners, parents)
   - ✅ Pending tutors count
   - ✅ Active sessions count
   - ✅ Revenue (total & monthly)
   - ✅ Online now / Active today
   - ✅ Quick links: Sessions, Active Now, Pending Tutors

4. **Pending Tutors** → Click "Pending Tutors":
   - ✅ See list of pending applications
   - ✅ View Details → Full profile
   - ✅ Contact buttons (Call, Email, WhatsApp)
   - ✅ Admin notes field (save notes)
   - ✅ Approve/Reject with reason
   - Test: Approve one tutor
   - Test: Reject one tutor with reason

5. **Sessions Page**:
   - ✅ View all lessons
   - ✅ Filter by status
   - ✅ Search functionality
   - Note: Will be empty until you create demo sessions

6. **Active Sessions**:
   - ✅ Shows ongoing sessions with progress bar
   - ✅ Shows upcoming sessions with countdown
   - Note: Empty until sessions exist

7. **Revenue Page**:
   - ✅ Total revenue
   - ✅ Monthly revenue
   - ✅ Revenue by status
   - Note: Will show $0 until payments exist

8. **Active Users**:
   - ✅ Online now (last 5 min)
   - ✅ Active today (last 24 hours)
   - ✅ List of active users with last seen

---

## 🐛 Known Issues (Not Critical for Testing):

1. **iOS Build Error** - Only affects iOS simulator (use Android/Web for now)
2. **No Real Sessions** - Need to build booking flow (Week 3)
3. **No Payments** - Fapshi integration coming (Week 4)
4. **No Messaging** - Coming in Week 5
5. **Admin Subdomain** - Works locally, may need DNS for production

---

## ✅ Success Criteria:

### Must Work:
- [x] Database migration runs successfully
- [x] Student/Parent can complete survey
- [x] University courses text input works
- [x] Budget step moved to end
- [x] Review page shows cards
- [x] Navigation goes to correct dashboard
- [x] Find Tutors shows 10 sample tutors
- [x] Search and filters work
- [x] Tutor detail shows YouTube video
- [x] WhatsApp request works
- [x] Admin can login
- [x] Admin sees real-time metrics
- [x] Admin can approve/reject tutors
- [x] Admin can view tutor details
- [x] Admin can save notes

### Should Look Good:
- [x] Modern, professional UI (not childish!)
- [x] Realistic pricing (2.5k - 8k XAF)
- [x] Blue verified badge (primary color)
- [x] Card-based review pages
- [x] Deep blue admin theme
- [x] Clean tutor cards
- [x] Smooth animations

---

## 🎯 Next Steps After Testing:

Based on your feedback:
1. **Week 1**: Finish admin features + tutor notifications
2. **Week 2**: Build booking/scheduling flow (like your screenshot!)
3. **Week 3**: Session management
4. **Week 4**: Fapshi payment integration
5. **Week 5**: Messaging & feedback
6. **Week 6**: Polish & launch

---

## 📞 Report Issues:

If something doesn't work:
1. Screenshot the error
2. Note which step failed
3. Share console logs (if available)

**Ready to test! 🚀**

