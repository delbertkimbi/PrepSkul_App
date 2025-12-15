# 🗓️ NEXT 5 DAYS - PREPSKUL ROADMAP

## 📅 **DAY 1: Complete Core Infrastructure**

### **Morning (3-4 hours):**

#### ✅ **1. Fix Onboarding Overflow** (30 min)
- Make onboarding screen responsive
- Add proper scrolling
- Test on different screen sizes

#### ✅ **2. Add Database Error Handling** (1 hour)
- Add try-catch to all `SurveyRepository` methods
- Add user feedback (SnackBars)
- Handle network errors gracefully

#### ✅ **3. Setup Supabase Storage** (1.5 hours)
- Create buckets: `profile-photos`, `documents`, `videos`
- Configure RLS policies for secure access
- Test bucket permissions

#### ✅ **4. Create File Upload Service** (1 hour)
- Build `storage_service.dart`
- Add image picker integration
- Add document picker integration
- Handle upload progress

### **Afternoon (2-3 hours):**

#### ✅ **5. Admin Tutor Validation System** (2 hours)
- Create admin approval workflow
- Add "approved/rejected" status updates
- Send notification to tutor on status change
- Update tutor dashboard based on status

#### ✅ **6. Bottom Navigation Bar** (1 hour)
- Create `BottomNavBar` widget
- 5 tabs: Home, Browse, Bookings, Messages, Profile
- Different nav for tutor/student/parent
- Implement navigation logic

---

## 📅 **DAY 2: Student/Parent Features**

### **Morning (3-4 hours):**

#### ✅ **1. Tutor Discovery/List Screen** (2 hours)
- Create `TutorListScreen`
- Fetch approved tutors from Supabase
- Display tutor cards (photo, name, subjects, rating, price)
- Add search bar
- Add filter options (subject, price, rating)

#### ✅ **2. Tutor Profile Detail Page** (2 hours)
- Create `TutorDetailScreen`
- Show full tutor info (bio, experience, reviews)
- Show availability calendar
- Add "Book Session" button
- Show social media links

### **Afternoon (2-3 hours):**

#### ✅ **3. Student Browse Section** (1.5 hours)
- Integrate tutor list in student dashboard
- Add "Find Tutors" functionality
- Show recommended tutors based on survey
- Implement navigation to tutor profiles

#### ✅ **4. Parent Browse Section** (1.5 hours)
- Similar to student browse
- Filter by child's needs
- Show tutors matching child's grade/subjects
- Add "Book for [Child Name]" functionality

---

## 📅 **DAY 3: Booking & Scheduling System**

### **Morning (3-4 hours):**

#### ✅ **1. Booking Flow** (2 hours)
- Create `BookingScreen`
- Show tutor availability
- Select date & time
- Add session details (subject, duration)
- Payment summary

#### ✅ **2. Session Confirmation** (1 hour)
- Send booking request to tutor
- Show pending status
- Add cancellation option
- Email/SMS notifications (using Supabase)

#### ✅ **3. My Schedule Screen** (1 hour)
- Create `ScheduleScreen`
- Show upcoming sessions
- Show past sessions
- Add session status (pending, confirmed, completed, cancelled)

### **Afternoon (2-3 hours):**

#### ✅ **4. Tutor Schedule Management** (2 hours)
- Tutor can view booking requests
- Accept/reject bookings
- View upcoming sessions
- Mark sessions as completed

#### ✅ **5. Calendar Integration** (1 hour)
- Visual calendar view
- Color-coded sessions
- Quick actions (reschedule, cancel)

---

## 📅 **DAY 4: Messaging & Communication**

### **Morning (3-4 hours):**

#### ✅ **1. Chat System Setup** (2 hours)
- Use Supabase Realtime for messaging
- Create `messages` table in database
- Create `ChatService`
- Setup message listeners

#### ✅ **2. Messages List Screen** (1.5 hours)
- Create `MessagesListScreen`
- Show all conversations
- Show last message & timestamp
- Unread message indicators
- Search conversations

### **Afternoon (2-3 hours):**

#### ✅ **3. Chat Screen** (2 hours)
- Create `ChatScreen`
- Real-time message display
- Send text messages
- Show message status (sent, delivered, read)
- Message timestamps

#### ✅ **4. Notifications** (1 hour)
- Setup push notifications (Firebase Cloud Messaging)
- Notify on new message
- Notify on booking confirmation
- Notify on tutor approval

---

## 📅 **DAY 5: Payments & Polish**

### **Morning (3-4 hours):**

#### ✅ **1. Payment Integration** (2.5 hours)
- Integrate MTN Mobile Money
- Integrate Orange Money
- Add payment confirmation screen
- Store payment records in database
- Show payment history

#### ✅ **2. Wallet/Earnings System** (1.5 hours)
- Create tutor earnings tracker
- Show payment breakdown
- Add withdrawal request system
- Payment analytics

### **Afternoon (2-3 hours):**

#### ✅ **3. Reviews & Ratings** (1.5 hours)
- Create `ReviewsScreen`
- Allow students/parents to rate tutors
- Add review comments
- Display reviews on tutor profile
- Calculate average rating

#### ✅ **4. Final Polish** (1.5 hours)
- Fix any UI issues
- Add loading states everywhere
- Error handling review
- Test complete user flows
- Performance optimization

---

## 📊 **DETAILED BREAKDOWN BY FEATURE:**

### **🔐 A. Admin/Tutor Validation System**

**Database Changes:**
```sql
-- Add to tutor_profiles table
ALTER TABLE tutor_profiles 
ADD COLUMN verification_status VARCHAR(20) DEFAULT 'pending';
-- Options: pending, approved, rejected

ADD COLUMN verification_notes TEXT;
ADD COLUMN verified_at TIMESTAMP;
ADD COLUMN verified_by UUID;
```

**Features:**
- Admin dashboard (separate app or web portal)
- Review tutor documents
- Approve/reject with notes
- Auto-email notification to tutor
- Update tutor dashboard status

---

### **🧭 B. Bottom Navigation Bar**

**Structure:**
```
Tutor Nav:
├── Home (Dashboard)
├── My Students
├── Schedule
├── Messages
└── Profile

Student Nav:
├── Home (Dashboard)
├── Browse Tutors
├── My Sessions
├── Messages
└── Profile

Parent Nav:
├── Home (Dashboard)
├── Find Tutors
├── Sessions
├── Messages
└── My Children
```

**Features:**
- Active tab highlighting
- Badge for notifications/messages
- Smooth transitions
- Persistent across screens

---

### **👥 C. Student/Parent Browse Sections**

**Features:**
- **Filter Options:**
  - Subject
  - Price range
  - Rating (4+ stars, 5 stars)
  - Availability
  - Experience level
  - Location (online/in-person)

- **Search:**
  - By name
  - By subject
  - By specialization

- **Tutor Cards Display:**
  - Profile photo
  - Name & title
  - Rating & review count
  - Subjects taught
  - Price per hour
  - "View Profile" button

- **Recommended Section:**
  - Based on survey responses
  - Match subjects student needs
  - Match budget range
  - Match schedule preferences

---

### **📅 D. Booking System**

**Flow:**
1. Student/Parent clicks "Book Session"
2. Select date from tutor's available times
3. Choose session duration (1hr, 1.5hr, 2hr)
4. Add session notes/goals
5. See price calculation
6. Confirm booking
7. Make payment
8. Booking request sent to tutor
9. Wait for tutor confirmation

**Database Tables:**
```sql
CREATE TABLE bookings (
  id UUID PRIMARY KEY,
  tutor_id UUID REFERENCES tutor_profiles(user_id),
  student_id UUID REFERENCES learner_profiles(user_id),
  session_date TIMESTAMP,
  duration INTEGER, -- in minutes
  subject VARCHAR(100),
  notes TEXT,
  status VARCHAR(20), -- pending, confirmed, completed, cancelled
  price DECIMAL(10,2),
  payment_status VARCHAR(20), -- pending, paid, refunded
  created_at TIMESTAMP DEFAULT NOW()
);
```

---

### **💬 E. Messaging System**

**Database Tables:**
```sql
CREATE TABLE conversations (
  id UUID PRIMARY KEY,
  participant1_id UUID REFERENCES profiles(id),
  participant2_id UUID REFERENCES profiles(id),
  last_message_at TIMESTAMP,
  created_at TIMESTAMP DEFAULT NOW()
);

CREATE TABLE messages (
  id UUID PRIMARY KEY,
  conversation_id UUID REFERENCES conversations(id),
  sender_id UUID REFERENCES profiles(id),
  message TEXT,
  is_read BOOLEAN DEFAULT FALSE,
  created_at TIMESTAMP DEFAULT NOW()
);
```

**Features:**
- Real-time messaging using Supabase Realtime
- Message read receipts
- Typing indicators
- Message timestamps
- Image sharing (future)

---

### **💰 F. Payment Integration**

**Options:**
1. **MTN Mobile Money**
   - MTN MoMo API
   - Phone number payment
   - Instant confirmation

2. **Orange Money**
   - Orange Money API
   - Phone number payment
   - Instant confirmation

**Flow:**
1. Student confirms booking
2. Payment screen shows amount
3. Student enters Mobile Money number
4. Payment initiated
5. Student confirms on phone
6. Payment verified
7. Booking confirmed
8. Tutor notified

**Security:**
- Store payment records
- Never store payment credentials
- Use Supabase RLS for payment data
- Transaction IDs for tracking

---

### **📦 G. File Upload & Storage**

**Buckets:**
```
profile-photos/
├── {user_id}/avatar.jpg
└── {user_id}/cover.jpg

documents/
├── tutors/{user_id}/
│   ├── id_front.pdf
│   ├── id_back.pdf
│   ├── degree.pdf
│   └── certificate.pdf
└── verification/

videos/
└── tutors/{user_id}/intro.mp4
```

**RLS Policies:**
```sql
-- Users can upload to their own folder
CREATE POLICY "Users can upload own files"
ON storage.objects FOR INSERT
TO authenticated
WITH CHECK (auth.uid()::text = (storage.foldername(name))[2]);

-- Users can read their own files
CREATE POLICY "Users can read own files"
ON storage.objects FOR SELECT
TO authenticated
USING (auth.uid()::text = (storage.foldername(name))[2]);

-- Everyone can read profile photos
CREATE POLICY "Public can read profile photos"
ON storage.objects FOR SELECT
TO public
USING (bucket_id = 'profile-photos');
```

---

## 🎯 **PRIORITY ORDER:**

### **MUST HAVE (Week 1):**
1. ✅ Bottom Navigation
2. ✅ Tutor validation system
3. ✅ Browse tutors (search & filter)
4. ✅ Tutor profile details
5. ✅ Basic booking flow
6. ✅ File upload service

### **IMPORTANT (Week 2):**
1. ✅ Messaging system
2. ✅ Schedule management
3. ✅ Payment integration
4. ✅ Reviews & ratings
5. ✅ Notifications

### **NICE TO HAVE (Week 3+):**
1. ⏭️ Advanced analytics
2. ⏭️ Video call integration
3. ⏭️ Homework assignments
4. ⏭️ Progress tracking
5. ⏭️ Certificates

---

## 📈 **SUCCESS METRICS:**

By end of 5 days, you'll have:
- ✅ Complete user flows for all 3 roles
- ✅ Working booking system
- ✅ Real-time messaging
- ✅ Payment integration
- ✅ File uploads
- ✅ Admin validation
- ✅ Professional, polished UI

---

## 💡 **IMPLEMENTATION TIPS:**

### **For File Upload:**
```dart
// Use image_picker package
final ImagePicker _picker = ImagePicker();
final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
```

### **For Messaging:**
```dart
// Use Supabase Realtime
Supabase.instance.client
  .from('messages')
  .stream(primaryKey: ['id'])
  .listen((data) {
    // Update UI with new messages
  });
```

### **For Payments:**
```dart
// Integrate with MTN/Orange APIs
// Use http package for API calls
// Store transaction references
```

---

## 🚀 **READY TO START?**

Choose your starting point:
1. **"start day 1"** - Begin with infrastructure tasks
2. **"bottom nav first"** - Start with navigation
3. **"tutor validation"** - Setup admin approval system
4. **"browse tutors"** - Build discovery feature
5. **"custom order"** - Tell me what you want first!

**What's your priority?** 🎯



## 📅 **DAY 1: Complete Core Infrastructure**

### **Morning (3-4 hours):**

#### ✅ **1. Fix Onboarding Overflow** (30 min)
- Make onboarding screen responsive
- Add proper scrolling
- Test on different screen sizes

#### ✅ **2. Add Database Error Handling** (1 hour)
- Add try-catch to all `SurveyRepository` methods
- Add user feedback (SnackBars)
- Handle network errors gracefully

#### ✅ **3. Setup Supabase Storage** (1.5 hours)
- Create buckets: `profile-photos`, `documents`, `videos`
- Configure RLS policies for secure access
- Test bucket permissions

#### ✅ **4. Create File Upload Service** (1 hour)
- Build `storage_service.dart`
- Add image picker integration
- Add document picker integration
- Handle upload progress

### **Afternoon (2-3 hours):**

#### ✅ **5. Admin Tutor Validation System** (2 hours)
- Create admin approval workflow
- Add "approved/rejected" status updates
- Send notification to tutor on status change
- Update tutor dashboard based on status

#### ✅ **6. Bottom Navigation Bar** (1 hour)
- Create `BottomNavBar` widget
- 5 tabs: Home, Browse, Bookings, Messages, Profile
- Different nav for tutor/student/parent
- Implement navigation logic

---

## 📅 **DAY 2: Student/Parent Features**

### **Morning (3-4 hours):**

#### ✅ **1. Tutor Discovery/List Screen** (2 hours)
- Create `TutorListScreen`
- Fetch approved tutors from Supabase
- Display tutor cards (photo, name, subjects, rating, price)
- Add search bar
- Add filter options (subject, price, rating)

#### ✅ **2. Tutor Profile Detail Page** (2 hours)
- Create `TutorDetailScreen`
- Show full tutor info (bio, experience, reviews)
- Show availability calendar
- Add "Book Session" button
- Show social media links

### **Afternoon (2-3 hours):**

#### ✅ **3. Student Browse Section** (1.5 hours)
- Integrate tutor list in student dashboard
- Add "Find Tutors" functionality
- Show recommended tutors based on survey
- Implement navigation to tutor profiles

#### ✅ **4. Parent Browse Section** (1.5 hours)
- Similar to student browse
- Filter by child's needs
- Show tutors matching child's grade/subjects
- Add "Book for [Child Name]" functionality

---

## 📅 **DAY 3: Booking & Scheduling System**

### **Morning (3-4 hours):**

#### ✅ **1. Booking Flow** (2 hours)
- Create `BookingScreen`
- Show tutor availability
- Select date & time
- Add session details (subject, duration)
- Payment summary

#### ✅ **2. Session Confirmation** (1 hour)
- Send booking request to tutor
- Show pending status
- Add cancellation option
- Email/SMS notifications (using Supabase)

#### ✅ **3. My Schedule Screen** (1 hour)
- Create `ScheduleScreen`
- Show upcoming sessions
- Show past sessions
- Add session status (pending, confirmed, completed, cancelled)

### **Afternoon (2-3 hours):**

#### ✅ **4. Tutor Schedule Management** (2 hours)
- Tutor can view booking requests
- Accept/reject bookings
- View upcoming sessions
- Mark sessions as completed

#### ✅ **5. Calendar Integration** (1 hour)
- Visual calendar view
- Color-coded sessions
- Quick actions (reschedule, cancel)

---

## 📅 **DAY 4: Messaging & Communication**

### **Morning (3-4 hours):**

#### ✅ **1. Chat System Setup** (2 hours)
- Use Supabase Realtime for messaging
- Create `messages` table in database
- Create `ChatService`
- Setup message listeners

#### ✅ **2. Messages List Screen** (1.5 hours)
- Create `MessagesListScreen`
- Show all conversations
- Show last message & timestamp
- Unread message indicators
- Search conversations

### **Afternoon (2-3 hours):**

#### ✅ **3. Chat Screen** (2 hours)
- Create `ChatScreen`
- Real-time message display
- Send text messages
- Show message status (sent, delivered, read)
- Message timestamps

#### ✅ **4. Notifications** (1 hour)
- Setup push notifications (Firebase Cloud Messaging)
- Notify on new message
- Notify on booking confirmation
- Notify on tutor approval

---

## 📅 **DAY 5: Payments & Polish**

### **Morning (3-4 hours):**

#### ✅ **1. Payment Integration** (2.5 hours)
- Integrate MTN Mobile Money
- Integrate Orange Money
- Add payment confirmation screen
- Store payment records in database
- Show payment history

#### ✅ **2. Wallet/Earnings System** (1.5 hours)
- Create tutor earnings tracker
- Show payment breakdown
- Add withdrawal request system
- Payment analytics

### **Afternoon (2-3 hours):**

#### ✅ **3. Reviews & Ratings** (1.5 hours)
- Create `ReviewsScreen`
- Allow students/parents to rate tutors
- Add review comments
- Display reviews on tutor profile
- Calculate average rating

#### ✅ **4. Final Polish** (1.5 hours)
- Fix any UI issues
- Add loading states everywhere
- Error handling review
- Test complete user flows
- Performance optimization

---

## 📊 **DETAILED BREAKDOWN BY FEATURE:**

### **🔐 A. Admin/Tutor Validation System**

**Database Changes:**
```sql
-- Add to tutor_profiles table
ALTER TABLE tutor_profiles 
ADD COLUMN verification_status VARCHAR(20) DEFAULT 'pending';
-- Options: pending, approved, rejected

ADD COLUMN verification_notes TEXT;
ADD COLUMN verified_at TIMESTAMP;
ADD COLUMN verified_by UUID;
```

**Features:**
- Admin dashboard (separate app or web portal)
- Review tutor documents
- Approve/reject with notes
- Auto-email notification to tutor
- Update tutor dashboard status

---

### **🧭 B. Bottom Navigation Bar**

**Structure:**
```
Tutor Nav:
├── Home (Dashboard)
├── My Students
├── Schedule
├── Messages
└── Profile

Student Nav:
├── Home (Dashboard)
├── Browse Tutors
├── My Sessions
├── Messages
└── Profile

Parent Nav:
├── Home (Dashboard)
├── Find Tutors
├── Sessions
├── Messages
└── My Children
```

**Features:**
- Active tab highlighting
- Badge for notifications/messages
- Smooth transitions
- Persistent across screens

---

### **👥 C. Student/Parent Browse Sections**

**Features:**
- **Filter Options:**
  - Subject
  - Price range
  - Rating (4+ stars, 5 stars)
  - Availability
  - Experience level
  - Location (online/in-person)

- **Search:**
  - By name
  - By subject
  - By specialization

- **Tutor Cards Display:**
  - Profile photo
  - Name & title
  - Rating & review count
  - Subjects taught
  - Price per hour
  - "View Profile" button

- **Recommended Section:**
  - Based on survey responses
  - Match subjects student needs
  - Match budget range
  - Match schedule preferences

---

### **📅 D. Booking System**

**Flow:**
1. Student/Parent clicks "Book Session"
2. Select date from tutor's available times
3. Choose session duration (1hr, 1.5hr, 2hr)
4. Add session notes/goals
5. See price calculation
6. Confirm booking
7. Make payment
8. Booking request sent to tutor
9. Wait for tutor confirmation

**Database Tables:**
```sql
CREATE TABLE bookings (
  id UUID PRIMARY KEY,
  tutor_id UUID REFERENCES tutor_profiles(user_id),
  student_id UUID REFERENCES learner_profiles(user_id),
  session_date TIMESTAMP,
  duration INTEGER, -- in minutes
  subject VARCHAR(100),
  notes TEXT,
  status VARCHAR(20), -- pending, confirmed, completed, cancelled
  price DECIMAL(10,2),
  payment_status VARCHAR(20), -- pending, paid, refunded
  created_at TIMESTAMP DEFAULT NOW()
);
```

---

### **💬 E. Messaging System**

**Database Tables:**
```sql
CREATE TABLE conversations (
  id UUID PRIMARY KEY,
  participant1_id UUID REFERENCES profiles(id),
  participant2_id UUID REFERENCES profiles(id),
  last_message_at TIMESTAMP,
  created_at TIMESTAMP DEFAULT NOW()
);

CREATE TABLE messages (
  id UUID PRIMARY KEY,
  conversation_id UUID REFERENCES conversations(id),
  sender_id UUID REFERENCES profiles(id),
  message TEXT,
  is_read BOOLEAN DEFAULT FALSE,
  created_at TIMESTAMP DEFAULT NOW()
);
```

**Features:**
- Real-time messaging using Supabase Realtime
- Message read receipts
- Typing indicators
- Message timestamps
- Image sharing (future)

---

### **💰 F. Payment Integration**

**Options:**
1. **MTN Mobile Money**
   - MTN MoMo API
   - Phone number payment
   - Instant confirmation

2. **Orange Money**
   - Orange Money API
   - Phone number payment
   - Instant confirmation

**Flow:**
1. Student confirms booking
2. Payment screen shows amount
3. Student enters Mobile Money number
4. Payment initiated
5. Student confirms on phone
6. Payment verified
7. Booking confirmed
8. Tutor notified

**Security:**
- Store payment records
- Never store payment credentials
- Use Supabase RLS for payment data
- Transaction IDs for tracking

---

### **📦 G. File Upload & Storage**

**Buckets:**
```
profile-photos/
├── {user_id}/avatar.jpg
└── {user_id}/cover.jpg

documents/
├── tutors/{user_id}/
│   ├── id_front.pdf
│   ├── id_back.pdf
│   ├── degree.pdf
│   └── certificate.pdf
└── verification/

videos/
└── tutors/{user_id}/intro.mp4
```

**RLS Policies:**
```sql
-- Users can upload to their own folder
CREATE POLICY "Users can upload own files"
ON storage.objects FOR INSERT
TO authenticated
WITH CHECK (auth.uid()::text = (storage.foldername(name))[2]);

-- Users can read their own files
CREATE POLICY "Users can read own files"
ON storage.objects FOR SELECT
TO authenticated
USING (auth.uid()::text = (storage.foldername(name))[2]);

-- Everyone can read profile photos
CREATE POLICY "Public can read profile photos"
ON storage.objects FOR SELECT
TO public
USING (bucket_id = 'profile-photos');
```

---

## 🎯 **PRIORITY ORDER:**

### **MUST HAVE (Week 1):**
1. ✅ Bottom Navigation
2. ✅ Tutor validation system
3. ✅ Browse tutors (search & filter)
4. ✅ Tutor profile details
5. ✅ Basic booking flow
6. ✅ File upload service

### **IMPORTANT (Week 2):**
1. ✅ Messaging system
2. ✅ Schedule management
3. ✅ Payment integration
4. ✅ Reviews & ratings
5. ✅ Notifications

### **NICE TO HAVE (Week 3+):**
1. ⏭️ Advanced analytics
2. ⏭️ Video call integration
3. ⏭️ Homework assignments
4. ⏭️ Progress tracking
5. ⏭️ Certificates

---

## 📈 **SUCCESS METRICS:**

By end of 5 days, you'll have:
- ✅ Complete user flows for all 3 roles
- ✅ Working booking system
- ✅ Real-time messaging
- ✅ Payment integration
- ✅ File uploads
- ✅ Admin validation
- ✅ Professional, polished UI

---

## 💡 **IMPLEMENTATION TIPS:**

### **For File Upload:**
```dart
// Use image_picker package
final ImagePicker _picker = ImagePicker();
final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
```

### **For Messaging:**
```dart
// Use Supabase Realtime
Supabase.instance.client
  .from('messages')
  .stream(primaryKey: ['id'])
  .listen((data) {
    // Update UI with new messages
  });
```

### **For Payments:**
```dart
// Integrate with MTN/Orange APIs
// Use http package for API calls
// Store transaction references
```

---

## 🚀 **READY TO START?**

Choose your starting point:
1. **"start day 1"** - Begin with infrastructure tasks
2. **"bottom nav first"** - Start with navigation
3. **"tutor validation"** - Setup admin approval system
4. **"browse tutors"** - Build discovery feature
5. **"custom order"** - Tell me what you want first!

**What's your priority?** 🎯

