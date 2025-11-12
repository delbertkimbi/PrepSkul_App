# Tutor Features and Capabilities

## Overview
This document outlines what tutors can do in the PrepSkul app, when features should be displayed, and what data is needed to support these features.

---

## 🎯 **Core Tutor Features**

### **1. Profile Management**
**Status:** ✅ Implemented
- **Edit Profile**: Update name, phone, email, profile picture
- **Profile Picture**: Upload and display profile photo
- **Location**: View location (editable through onboarding)
- **Availability**: Set tutoring and test session availability
- **Pricing**: View and update session pricing
- **Documents**: Upload certificates and credentials

**When to Show:**
- Always available in Profile screen
- Edit button accessible from profile picture

---

### **2. Booking Management**
**Status:** ✅ Partially Implemented
- **View Booking Requests**: See incoming booking requests from students/parents
- **Approve/Reject Requests**: Accept or decline booking requests
- **View Booking Details**: See student info, subject, schedule, location
- **Conflict Detection**: System checks for scheduling conflicts

**When to Show:**
- Show "Requests" tab when tutor is approved
- Show notification badge when new requests arrive
- Display in "My Requests" screen

---

### **3. Session Management**
**Status:** ⏳ Not Implemented
- **View Upcoming Sessions**: Calendar/list of scheduled sessions
- **Start/End Sessions**: Mark session start and end times
- **Session History**: View past completed sessions
- **Reschedule Sessions**: Request to reschedule if needed
- **Cancel Sessions**: Cancel with appropriate notice

**When to Show:**
- Show "Sessions" tab when tutor is approved
- Display upcoming sessions on home screen
- Show session reminders (24h, 1h before)

---

### **4. PrepSkul Wallet & Earnings**
**Status:** ⏳ Not Implemented (Placeholder Added)
- **Active Balance**: Earnings available for withdrawal
- **Pending Balance**: Earnings awaiting session completion
- **Transaction History**: View all earnings and payouts
- **Payout Requests**: Request withdrawal to mobile money
- **Earnings Breakdown**: See per-session earnings, platform fees (15%)

**When to Show:**
- Show wallet section on home screen when tutor is approved
- Display after first completed session
- Show "0 XAF" until sessions are completed

**Payment Flow:**
1. Student pays for session → Payment held by PrepSkul
2. Session completed → 85% moved to "Pending Balance"
3. After 24-48h (dispute period) → Moved to "Active Balance"
4. Tutor requests payout → Processed via Mobile Money (MTN/Orange)

---

### **5. Student Management**
**Status:** ⏳ Not Implemented
- **My Students**: List of all students currently booked
- **Student Profiles**: View student information and learning goals
- **Session History per Student**: Track progress with each student
- **Communication**: In-app messaging with students/parents

**When to Show:**
- Show "My Students" when tutor has at least one active booking
- Display student count in Quick Stats

---

### **6. Reviews & Ratings**
**Status:** ⏳ Not Implemented
- **View Reviews**: See all reviews from students/parents
- **Average Rating**: Display overall rating on profile
- **Review Responses**: Respond to reviews (optional)
- **Rating Breakdown**: See distribution of ratings

**When to Show:**
- Show reviews section after first completed session
- Display average rating on profile and home screen
- Show "No reviews yet" if no reviews exist

---

### **7. Analytics & Insights**
**Status:** ⏳ Not Implemented
- **Earnings Overview**: Total earnings, monthly trends
- **Session Statistics**: Sessions completed, hours taught, students helped
- **Popular Subjects**: Which subjects are most requested
- **Peak Times**: When most sessions are booked

**When to Show:**
- Show analytics section after tutor has completed sessions
- Display on home screen or dedicated analytics tab

---

### **8. Notifications**
**Status:** ✅ Implemented
- **Booking Requests**: Notified when new booking request arrives
- **Session Reminders**: 24h and 1h before session
- **Payment Updates**: When earnings are available
- **Profile Updates**: Approval, rejection, improvement requests
- **Messages**: New messages from students/parents

**When to Show:**
- Always available via notification bell
- Show unread count badge
- Deep link to relevant sections

---

## 📊 **Feature Display Logic**

### **Home Screen Sections (In Order):**

1. **Welcome Header** - Always shown
2. **Approval Status Card** - Show if:
   - Status is 'approved' AND not dismissed, OR
   - Status is 'pending', 'needs_improvement', 'rejected', 'blocked', 'suspended'
3. **PrepSkul Wallet** - Show if:
   - Status is 'approved'
   - (Will show real data when wallet system is implemented)
4. **Quick Stats** - Always shown
   - Students count (from active bookings)
   - Sessions count (total completed + upcoming)
5. **Upcoming Sessions** - Show if:
   - Status is 'approved' AND has upcoming sessions
6. **Recent Activity** - Show if:
   - Has recent bookings, earnings, or reviews

---

## 💰 **Wallet & Earnings Details**

### **Balance Types:**
- **Active Balance**: Available for immediate withdrawal
  - Earnings from completed sessions (after dispute period)
  - Ready to be paid out
- **Pending Balance**: Earnings awaiting completion
  - From sessions just completed (24-48h hold)
  - Will move to Active after dispute period

### **Earnings Calculation:**
- **Gross Amount**: Full session price paid by student
- **Platform Fee**: 15% of gross (PrepSkul commission)
- **Net Amount**: 85% of gross (tutor earnings)

### **Example:**
- Session Price: 10,000 XAF
- Platform Fee (15%): 1,500 XAF
- Tutor Earnings: 8,500 XAF

---

## 🎓 **Tutor Journey**

### **Phase 1: Onboarding** ✅
- Complete profile
- Upload documents
- Set availability
- Submit for approval

### **Phase 2: Approval** ✅
- Wait for admin review
- Receive approval/rejection/improvement request
- Profile goes live (if approved)

### **Phase 3: Active Tutoring** ⏳
- Receive booking requests
- Accept/reject requests
- Conduct sessions
- Earn money
- Get reviews

### **Phase 4: Growth** ⏳
- Build student base
- Improve ratings
- Increase earnings
- Request payouts

---

## 🔄 **What Tutors Can Do (By Status)**

### **Pending Approval:**
- ✅ Edit profile
- ✅ View profile
- ❌ Receive bookings
- ❌ See wallet
- ❌ View sessions

### **Approved:**
- ✅ Edit profile
- ✅ View profile
- ✅ Receive bookings
- ✅ See wallet (placeholder)
- ✅ View sessions (when implemented)
- ✅ Start earning

### **Needs Improvement:**
- ✅ Edit profile (with pre-filled data)
- ✅ View admin feedback
- ✅ Resubmit for approval
- ❌ Receive bookings
- ❌ See wallet

### **Rejected:**
- ✅ View rejection reasons
- ✅ Edit profile
- ✅ Reapply
- ❌ Receive bookings

---

## 📱 **Navigation Structure**

### **Tutor Bottom Navigation:**
1. **Home** - Dashboard with stats, wallet, upcoming sessions
2. **Requests** - Incoming booking requests
3. **Sessions** - Upcoming and past sessions
4. **Profile** - Profile management and settings

### **Additional Screens:**
- **Wallet/Earnings** - Detailed earnings and payout requests
- **My Students** - List of current students
- **Reviews** - All reviews and ratings
- **Analytics** - Performance insights
- **Messages** - In-app messaging

---

## 🚀 **Next Steps for Implementation**

### **Priority 1: Wallet System**
1. Create database tables (wallets, tutor_earnings, payouts)
2. Implement earnings calculation (15% platform fee)
3. Add wallet service and UI
4. Integrate with payment system

### **Priority 2: Session Management**
1. Session start/end tracking
2. Session history
3. Reschedule/cancel functionality
4. Calendar view

### **Priority 3: Student Management**
1. My Students screen
2. Student profiles
3. Per-student session history

### **Priority 4: Reviews & Analytics**
1. Review display and responses
2. Rating calculations
3. Analytics dashboard

---

## 📝 **Notes**

- All features should respect tutor's approval status
- Wallet shows "0 XAF" until payment system is integrated
- Placeholder UI is in place for wallet section
- Features should gracefully handle empty states
- All monetary values in XAF (Central African Franc)





## Overview
This document outlines what tutors can do in the PrepSkul app, when features should be displayed, and what data is needed to support these features.

---

## 🎯 **Core Tutor Features**

### **1. Profile Management**
**Status:** ✅ Implemented
- **Edit Profile**: Update name, phone, email, profile picture
- **Profile Picture**: Upload and display profile photo
- **Location**: View location (editable through onboarding)
- **Availability**: Set tutoring and test session availability
- **Pricing**: View and update session pricing
- **Documents**: Upload certificates and credentials

**When to Show:**
- Always available in Profile screen
- Edit button accessible from profile picture

---

### **2. Booking Management**
**Status:** ✅ Partially Implemented
- **View Booking Requests**: See incoming booking requests from students/parents
- **Approve/Reject Requests**: Accept or decline booking requests
- **View Booking Details**: See student info, subject, schedule, location
- **Conflict Detection**: System checks for scheduling conflicts

**When to Show:**
- Show "Requests" tab when tutor is approved
- Show notification badge when new requests arrive
- Display in "My Requests" screen

---

### **3. Session Management**
**Status:** ⏳ Not Implemented
- **View Upcoming Sessions**: Calendar/list of scheduled sessions
- **Start/End Sessions**: Mark session start and end times
- **Session History**: View past completed sessions
- **Reschedule Sessions**: Request to reschedule if needed
- **Cancel Sessions**: Cancel with appropriate notice

**When to Show:**
- Show "Sessions" tab when tutor is approved
- Display upcoming sessions on home screen
- Show session reminders (24h, 1h before)

---

### **4. PrepSkul Wallet & Earnings**
**Status:** ⏳ Not Implemented (Placeholder Added)
- **Active Balance**: Earnings available for withdrawal
- **Pending Balance**: Earnings awaiting session completion
- **Transaction History**: View all earnings and payouts
- **Payout Requests**: Request withdrawal to mobile money
- **Earnings Breakdown**: See per-session earnings, platform fees (15%)

**When to Show:**
- Show wallet section on home screen when tutor is approved
- Display after first completed session
- Show "0 XAF" until sessions are completed

**Payment Flow:**
1. Student pays for session → Payment held by PrepSkul
2. Session completed → 85% moved to "Pending Balance"
3. After 24-48h (dispute period) → Moved to "Active Balance"
4. Tutor requests payout → Processed via Mobile Money (MTN/Orange)

---

### **5. Student Management**
**Status:** ⏳ Not Implemented
- **My Students**: List of all students currently booked
- **Student Profiles**: View student information and learning goals
- **Session History per Student**: Track progress with each student
- **Communication**: In-app messaging with students/parents

**When to Show:**
- Show "My Students" when tutor has at least one active booking
- Display student count in Quick Stats

---

### **6. Reviews & Ratings**
**Status:** ⏳ Not Implemented
- **View Reviews**: See all reviews from students/parents
- **Average Rating**: Display overall rating on profile
- **Review Responses**: Respond to reviews (optional)
- **Rating Breakdown**: See distribution of ratings

**When to Show:**
- Show reviews section after first completed session
- Display average rating on profile and home screen
- Show "No reviews yet" if no reviews exist

---

### **7. Analytics & Insights**
**Status:** ⏳ Not Implemented
- **Earnings Overview**: Total earnings, monthly trends
- **Session Statistics**: Sessions completed, hours taught, students helped
- **Popular Subjects**: Which subjects are most requested
- **Peak Times**: When most sessions are booked

**When to Show:**
- Show analytics section after tutor has completed sessions
- Display on home screen or dedicated analytics tab

---

### **8. Notifications**
**Status:** ✅ Implemented
- **Booking Requests**: Notified when new booking request arrives
- **Session Reminders**: 24h and 1h before session
- **Payment Updates**: When earnings are available
- **Profile Updates**: Approval, rejection, improvement requests
- **Messages**: New messages from students/parents

**When to Show:**
- Always available via notification bell
- Show unread count badge
- Deep link to relevant sections

---

## 📊 **Feature Display Logic**

### **Home Screen Sections (In Order):**

1. **Welcome Header** - Always shown
2. **Approval Status Card** - Show if:
   - Status is 'approved' AND not dismissed, OR
   - Status is 'pending', 'needs_improvement', 'rejected', 'blocked', 'suspended'
3. **PrepSkul Wallet** - Show if:
   - Status is 'approved'
   - (Will show real data when wallet system is implemented)
4. **Quick Stats** - Always shown
   - Students count (from active bookings)
   - Sessions count (total completed + upcoming)
5. **Upcoming Sessions** - Show if:
   - Status is 'approved' AND has upcoming sessions
6. **Recent Activity** - Show if:
   - Has recent bookings, earnings, or reviews

---

## 💰 **Wallet & Earnings Details**

### **Balance Types:**
- **Active Balance**: Available for immediate withdrawal
  - Earnings from completed sessions (after dispute period)
  - Ready to be paid out
- **Pending Balance**: Earnings awaiting completion
  - From sessions just completed (24-48h hold)
  - Will move to Active after dispute period

### **Earnings Calculation:**
- **Gross Amount**: Full session price paid by student
- **Platform Fee**: 15% of gross (PrepSkul commission)
- **Net Amount**: 85% of gross (tutor earnings)

### **Example:**
- Session Price: 10,000 XAF
- Platform Fee (15%): 1,500 XAF
- Tutor Earnings: 8,500 XAF

---

## 🎓 **Tutor Journey**

### **Phase 1: Onboarding** ✅
- Complete profile
- Upload documents
- Set availability
- Submit for approval

### **Phase 2: Approval** ✅
- Wait for admin review
- Receive approval/rejection/improvement request
- Profile goes live (if approved)

### **Phase 3: Active Tutoring** ⏳
- Receive booking requests
- Accept/reject requests
- Conduct sessions
- Earn money
- Get reviews

### **Phase 4: Growth** ⏳
- Build student base
- Improve ratings
- Increase earnings
- Request payouts

---

## 🔄 **What Tutors Can Do (By Status)**

### **Pending Approval:**
- ✅ Edit profile
- ✅ View profile
- ❌ Receive bookings
- ❌ See wallet
- ❌ View sessions

### **Approved:**
- ✅ Edit profile
- ✅ View profile
- ✅ Receive bookings
- ✅ See wallet (placeholder)
- ✅ View sessions (when implemented)
- ✅ Start earning

### **Needs Improvement:**
- ✅ Edit profile (with pre-filled data)
- ✅ View admin feedback
- ✅ Resubmit for approval
- ❌ Receive bookings
- ❌ See wallet

### **Rejected:**
- ✅ View rejection reasons
- ✅ Edit profile
- ✅ Reapply
- ❌ Receive bookings

---

## 📱 **Navigation Structure**

### **Tutor Bottom Navigation:**
1. **Home** - Dashboard with stats, wallet, upcoming sessions
2. **Requests** - Incoming booking requests
3. **Sessions** - Upcoming and past sessions
4. **Profile** - Profile management and settings

### **Additional Screens:**
- **Wallet/Earnings** - Detailed earnings and payout requests
- **My Students** - List of current students
- **Reviews** - All reviews and ratings
- **Analytics** - Performance insights
- **Messages** - In-app messaging

---

## 🚀 **Next Steps for Implementation**

### **Priority 1: Wallet System**
1. Create database tables (wallets, tutor_earnings, payouts)
2. Implement earnings calculation (15% platform fee)
3. Add wallet service and UI
4. Integrate with payment system

### **Priority 2: Session Management**
1. Session start/end tracking
2. Session history
3. Reschedule/cancel functionality
4. Calendar view

### **Priority 3: Student Management**
1. My Students screen
2. Student profiles
3. Per-student session history

### **Priority 4: Reviews & Analytics**
1. Review display and responses
2. Rating calculations
3. Analytics dashboard

---

## 📝 **Notes**

- All features should respect tutor's approval status
- Wallet shows "0 XAF" until payment system is integrated
- Placeholder UI is in place for wallet section
- Features should gracefully handle empty states
- All monetary values in XAF (Central African Franc)



# Tutor Features and Capabilities

## Overview
This document outlines what tutors can do in the PrepSkul app, when features should be displayed, and what data is needed to support these features.

---

## 🎯 **Core Tutor Features**

### **1. Profile Management**
**Status:** ✅ Implemented
- **Edit Profile**: Update name, phone, email, profile picture
- **Profile Picture**: Upload and display profile photo
- **Location**: View location (editable through onboarding)
- **Availability**: Set tutoring and test session availability
- **Pricing**: View and update session pricing
- **Documents**: Upload certificates and credentials

**When to Show:**
- Always available in Profile screen
- Edit button accessible from profile picture

---

### **2. Booking Management**
**Status:** ✅ Partially Implemented
- **View Booking Requests**: See incoming booking requests from students/parents
- **Approve/Reject Requests**: Accept or decline booking requests
- **View Booking Details**: See student info, subject, schedule, location
- **Conflict Detection**: System checks for scheduling conflicts

**When to Show:**
- Show "Requests" tab when tutor is approved
- Show notification badge when new requests arrive
- Display in "My Requests" screen

---

### **3. Session Management**
**Status:** ⏳ Not Implemented
- **View Upcoming Sessions**: Calendar/list of scheduled sessions
- **Start/End Sessions**: Mark session start and end times
- **Session History**: View past completed sessions
- **Reschedule Sessions**: Request to reschedule if needed
- **Cancel Sessions**: Cancel with appropriate notice

**When to Show:**
- Show "Sessions" tab when tutor is approved
- Display upcoming sessions on home screen
- Show session reminders (24h, 1h before)

---

### **4. PrepSkul Wallet & Earnings**
**Status:** ⏳ Not Implemented (Placeholder Added)
- **Active Balance**: Earnings available for withdrawal
- **Pending Balance**: Earnings awaiting session completion
- **Transaction History**: View all earnings and payouts
- **Payout Requests**: Request withdrawal to mobile money
- **Earnings Breakdown**: See per-session earnings, platform fees (15%)

**When to Show:**
- Show wallet section on home screen when tutor is approved
- Display after first completed session
- Show "0 XAF" until sessions are completed

**Payment Flow:**
1. Student pays for session → Payment held by PrepSkul
2. Session completed → 85% moved to "Pending Balance"
3. After 24-48h (dispute period) → Moved to "Active Balance"
4. Tutor requests payout → Processed via Mobile Money (MTN/Orange)

---

### **5. Student Management**
**Status:** ⏳ Not Implemented
- **My Students**: List of all students currently booked
- **Student Profiles**: View student information and learning goals
- **Session History per Student**: Track progress with each student
- **Communication**: In-app messaging with students/parents

**When to Show:**
- Show "My Students" when tutor has at least one active booking
- Display student count in Quick Stats

---

### **6. Reviews & Ratings**
**Status:** ⏳ Not Implemented
- **View Reviews**: See all reviews from students/parents
- **Average Rating**: Display overall rating on profile
- **Review Responses**: Respond to reviews (optional)
- **Rating Breakdown**: See distribution of ratings

**When to Show:**
- Show reviews section after first completed session
- Display average rating on profile and home screen
- Show "No reviews yet" if no reviews exist

---

### **7. Analytics & Insights**
**Status:** ⏳ Not Implemented
- **Earnings Overview**: Total earnings, monthly trends
- **Session Statistics**: Sessions completed, hours taught, students helped
- **Popular Subjects**: Which subjects are most requested
- **Peak Times**: When most sessions are booked

**When to Show:**
- Show analytics section after tutor has completed sessions
- Display on home screen or dedicated analytics tab

---

### **8. Notifications**
**Status:** ✅ Implemented
- **Booking Requests**: Notified when new booking request arrives
- **Session Reminders**: 24h and 1h before session
- **Payment Updates**: When earnings are available
- **Profile Updates**: Approval, rejection, improvement requests
- **Messages**: New messages from students/parents

**When to Show:**
- Always available via notification bell
- Show unread count badge
- Deep link to relevant sections

---

## 📊 **Feature Display Logic**

### **Home Screen Sections (In Order):**

1. **Welcome Header** - Always shown
2. **Approval Status Card** - Show if:
   - Status is 'approved' AND not dismissed, OR
   - Status is 'pending', 'needs_improvement', 'rejected', 'blocked', 'suspended'
3. **PrepSkul Wallet** - Show if:
   - Status is 'approved'
   - (Will show real data when wallet system is implemented)
4. **Quick Stats** - Always shown
   - Students count (from active bookings)
   - Sessions count (total completed + upcoming)
5. **Upcoming Sessions** - Show if:
   - Status is 'approved' AND has upcoming sessions
6. **Recent Activity** - Show if:
   - Has recent bookings, earnings, or reviews

---

## 💰 **Wallet & Earnings Details**

### **Balance Types:**
- **Active Balance**: Available for immediate withdrawal
  - Earnings from completed sessions (after dispute period)
  - Ready to be paid out
- **Pending Balance**: Earnings awaiting completion
  - From sessions just completed (24-48h hold)
  - Will move to Active after dispute period

### **Earnings Calculation:**
- **Gross Amount**: Full session price paid by student
- **Platform Fee**: 15% of gross (PrepSkul commission)
- **Net Amount**: 85% of gross (tutor earnings)

### **Example:**
- Session Price: 10,000 XAF
- Platform Fee (15%): 1,500 XAF
- Tutor Earnings: 8,500 XAF

---

## 🎓 **Tutor Journey**

### **Phase 1: Onboarding** ✅
- Complete profile
- Upload documents
- Set availability
- Submit for approval

### **Phase 2: Approval** ✅
- Wait for admin review
- Receive approval/rejection/improvement request
- Profile goes live (if approved)

### **Phase 3: Active Tutoring** ⏳
- Receive booking requests
- Accept/reject requests
- Conduct sessions
- Earn money
- Get reviews

### **Phase 4: Growth** ⏳
- Build student base
- Improve ratings
- Increase earnings
- Request payouts

---

## 🔄 **What Tutors Can Do (By Status)**

### **Pending Approval:**
- ✅ Edit profile
- ✅ View profile
- ❌ Receive bookings
- ❌ See wallet
- ❌ View sessions

### **Approved:**
- ✅ Edit profile
- ✅ View profile
- ✅ Receive bookings
- ✅ See wallet (placeholder)
- ✅ View sessions (when implemented)
- ✅ Start earning

### **Needs Improvement:**
- ✅ Edit profile (with pre-filled data)
- ✅ View admin feedback
- ✅ Resubmit for approval
- ❌ Receive bookings
- ❌ See wallet

### **Rejected:**
- ✅ View rejection reasons
- ✅ Edit profile
- ✅ Reapply
- ❌ Receive bookings

---

## 📱 **Navigation Structure**

### **Tutor Bottom Navigation:**
1. **Home** - Dashboard with stats, wallet, upcoming sessions
2. **Requests** - Incoming booking requests
3. **Sessions** - Upcoming and past sessions
4. **Profile** - Profile management and settings

### **Additional Screens:**
- **Wallet/Earnings** - Detailed earnings and payout requests
- **My Students** - List of current students
- **Reviews** - All reviews and ratings
- **Analytics** - Performance insights
- **Messages** - In-app messaging

---

## 🚀 **Next Steps for Implementation**

### **Priority 1: Wallet System**
1. Create database tables (wallets, tutor_earnings, payouts)
2. Implement earnings calculation (15% platform fee)
3. Add wallet service and UI
4. Integrate with payment system

### **Priority 2: Session Management**
1. Session start/end tracking
2. Session history
3. Reschedule/cancel functionality
4. Calendar view

### **Priority 3: Student Management**
1. My Students screen
2. Student profiles
3. Per-student session history

### **Priority 4: Reviews & Analytics**
1. Review display and responses
2. Rating calculations
3. Analytics dashboard

---

## 📝 **Notes**

- All features should respect tutor's approval status
- Wallet shows "0 XAF" until payment system is integrated
- Placeholder UI is in place for wallet section
- Features should gracefully handle empty states
- All monetary values in XAF (Central African Franc)





