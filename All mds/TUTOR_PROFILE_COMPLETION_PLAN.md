# 📋 TUTOR PROFILE COMPLETION PLAN

## 🎯 **Your Concern:**
> "We are skipping so many important things in the onboarding process of the tutor. Please ensure while they are waiting for approval they must finish them up."

## ✅ **SOLUTION: Multi-Stage Tutor Onboarding**

---

## 📊 **Current Status**

### **What Tutors Submit Now:**
1. ✅ Personal Info (name, DOB, city, quarter, about me)
2. ✅ Academic Background (education, institution, certifications)
3. ✅ Experience (teaching history, motivation)
4. ✅ Tutoring Details (areas, levels, specializations)
5. ✅ Availability (hours/week, schedule)
6. ✅ Payment (method, rate, details)
7. ⚠️ **Verification (ID, video, socials)** - Often skipped/incomplete
8. ⚠️ **Profile Photo** - Optional but important
9. ⚠️ **Documents** - Sometimes not uploaded

### **The Problem:**
- Tutors can skip video upload
- Documents might not be complete
- They submit for review with incomplete profiles
- **No way to complete missing items while "Pending Approval"**

---

## 🎯 **PROPOSED SOLUTION**

### **Stage 1: Initial Application (Current Flow)**
**Goal:** Collect basic info to create tutor account

**Required Fields:**
- ✅ Personal Info
- ✅ Academic Background  
- ✅ Experience
- ✅ Tutoring Details
- ✅ Availability
- ✅ Payment Details

**Optional/Can Skip:**
- Profile Photo → Can add later
- ID Cards → Can upload later
- Certificates → Can upload later
- Video Intro → Can add later
- Social Links → Can add later

**Result:** Tutor profile created with status = `incomplete`

---

### **Stage 2: Profile Completion (NEW!)**
**Goal:** Complete all required verification items before admin review

**Dashboard Shows:**
```
┌─────────────────────────────────────────────┐
│  🚧 Complete Your Profile                  │
│                                             │
│  Your application is saved! Complete the   │
│  remaining items to submit for review.     │
│                                             │
│  ✅ Basic Information          (100%)      │
│  ✅ Academic Background         (100%)      │
│  ✅ Teaching Experience         (100%)      │
│  ⚠️  Verification Documents     (60%)       │
│     ├─ ✅ Profile Photo                    │
│     ├─ ❌ ID Card (Front)      [Upload]    │
│     ├─ ❌ ID Card (Back)       [Upload]    │
│     └─ ⚠️  Certificates (2/3)  [Add More]  │
│  ❌ Video Introduction          (0%)        │
│     └─ [Record/Upload Video]               │
│  ⚠️  Social Profiles            (50%)       │
│     ├─ ✅ LinkedIn                         │
│     └─ ❌ YouTube               [Add Link]  │
│                                             │
│  📊 Profile Completion: 75%                │
│                                             │
│  [Complete Profile] [Save & Continue Later]│
└─────────────────────────────────────────────┘
```

**Required to Submit:**
- ✅ Profile Photo (must have)
- ✅ ID Card Front (must have)
- ✅ ID Card Back (must have)
- ✅ At least 1 certificate (if applicable)
- ✅ Video Introduction (must have)

**Optional:**
- Social links (recommended but not required)

---

### **Stage 3: Pending Admin Review**
**Status:** `pending_review`

**Dashboard Shows:**
```
┌─────────────────────────────────────────────┐
│  ⏳ Application Under Review                │
│                                             │
│  Your profile is being reviewed by our     │
│  admin team. This usually takes 24-48 hrs. │
│                                             │
│  📊 Profile Completion: 100%               │
│  📅 Submitted: Oct 28, 2025                │
│                                             │
│  While you wait, you can:                  │
│  • Update your availability                │
│  • Add more certificates                   │
│  • Update your rate                        │
│  • Add social profiles                     │
│                                             │
│  [Edit Profile] [View Preview]             │
└─────────────────────────────────────────────┘
```

**Tutor Can Still:**
- ✅ Update availability
- ✅ Upload additional certificates
- ✅ Update payment rate
- ✅ Add/edit social links
- ✅ Update "About Me"

**Tutor Cannot:**
- ❌ Change verification documents (ID cards, video)
- ❌ Change academic credentials
- ❌ Submit for review again (already submitted)

---

### **Stage 4: Approved/Active**
**Status:** `approved`

**Dashboard Shows:**
```
┌─────────────────────────────────────────────┐
│  ✅ Profile Approved!                       │
│                                             │
│  Congratulations! You can now start        │
│  receiving student requests.               │
│                                             │
│  📊 Active Students: 0                     │
│  💰 Total Earnings: 0 XAF                  │
│  ⭐ Rating: New Tutor                      │
│                                             │
│  [Find Students] [Edit Profile]            │
└─────────────────────────────────────────────┘
```

---

## 🔧 **IMPLEMENTATION PLAN**

### **Database Changes:**

```sql
ALTER TABLE tutor_profiles 
ADD COLUMN profile_completion_percentage INTEGER DEFAULT 0,
ADD COLUMN can_submit_for_review BOOLEAN DEFAULT false,
ADD COLUMN submitted_for_review_at TIMESTAMP;

-- Update verification_status to include new states
-- 'incomplete' → 'pending_completion' → 'pending_review' → 'approved' / 'rejected'
```

### **Code Changes:**

#### **1. Profile Completion Calculator**
```dart
// lib/core/services/profile_completion_service.dart

class ProfileCompletionService {
  static int calculateCompletion(TutorProfile profile) {
    int totalPoints = 100;
    int earned = 0;
    
    // Basic Info (20 points)
    if (profile.fullName != null) earned += 5;
    if (profile.dateOfBirth != null) earned += 5;
    if (profile.city != null) earned += 5;
    if (profile.aboutMe != null && profile.aboutMe!.isNotEmpty) earned += 5;
    
    // Academic (15 points)
    if (profile.education != null) earned += 10;
    if (profile.certifications != null && profile.certifications!.isNotEmpty) earned += 5;
    
    // Experience (15 points)
    if (profile.teachingExperience != null) earned += 10;
    if (profile.previousRoles != null && profile.previousRoles!.isNotEmpty) earned += 5;
    
    // Tutoring Details (15 points)
    if (profile.tutoringAreas != null && profile.tutoringAreas!.isNotEmpty) earned += 8;
    if (profile.learnerLevels != null && profile.learnerLevels!.isNotEmpty) earned += 7;
    
    // Availability (10 points)
    if (profile.hoursPerWeek != null) earned += 5;
    if (profile.availability != null) earned += 5;
    
    // Payment (10 points)
    if (profile.paymentMethod != null) earned += 5;
    if (profile.hourlyRate != null) earned += 5;
    
    // Verification (15 points) - CRITICAL
    if (profile.profilePhotoUrl != null) earned += 3;
    if (profile.idCardFrontUrl != null) earned += 4;
    if (profile.idCardBackUrl != null) earned += 4;
    if (profile.videoIntroUrl != null) earned += 4;
    
    return (earned * 100) ~/ totalPoints;
  }
  
  static bool canSubmitForReview(TutorProfile profile) {
    // Must have all critical verification items
    return profile.profilePhotoUrl != null &&
           profile.idCardFrontUrl != null &&
           profile.idCardBackUrl != null &&
           profile.videoIntroUrl != null &&
           calculateCompletion(profile) >= 80; // At least 80% complete
  }
}
```

#### **2. Tutor Dashboard with Completion Status**
```dart
// lib/features/tutor/screens/tutor_home_screen.dart

class TutorHomeScreen extends StatefulWidget {
  @override
  Widget build(BuildContext context) {
    return FutureBuilder<TutorProfile>(
      future: _loadTutorProfile(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return CircularProgressIndicator();
        
        final profile = snapshot.data!;
        final completion = ProfileCompletionService.calculateCompletion(profile);
        final canSubmit = ProfileCompletionService.canSubmitForReview(profile);
        
        // Show different UI based on status
        if (profile.verificationStatus == 'incomplete') {
          return _buildIncompleteProfileUI(profile, completion, canSubmit);
        } else if (profile.verificationStatus == 'pending_review') {
          return _buildPendingReviewUI(profile);
        } else if (profile.verificationStatus == 'approved') {
          return _buildApprovedDashboardUI(profile);
        }
      },
    );
  }
}
```

#### **3. Profile Completion Checklist Widget**
```dart
// lib/features/tutor/widgets/profile_completion_checklist.dart

class ProfileCompletionChecklist extends StatelessWidget {
  final TutorProfile profile;
  
  Widget build(BuildContext context) {
    return Card(
      child: Column(
        children: [
          _buildChecklistItem(
            title: 'Profile Photo',
            isComplete: profile.profilePhotoUrl != null,
            onTap: () => _navigateToUpload('profile_photo'),
          ),
          _buildChecklistItem(
            title: 'ID Card (Front)',
            isComplete: profile.idCardFrontUrl != null,
            onTap: () => _navigateToUpload('id_front'),
          ),
          _buildChecklistItem(
            title: 'ID Card (Back)',
            isComplete: profile.idCardBackUrl != null,
            onTap: () => _navigateToUpload('id_back'),
          ),
          _buildChecklistItem(
            title: 'Video Introduction',
            isComplete: profile.videoIntroUrl != null,
            onTap: () => _navigateToUpload('video'),
          ),
          // ... more items
        ],
      ),
    );
  }
}
```

---

## 🎯 **WHAT NEEDS TO BE IMPLEMENTED**

### **Priority 1 (Critical):**
1. ✅ Profile completion calculator
2. ✅ Updated tutor dashboard with completion status
3. ✅ Checklist widget for missing items
4. ✅ Ability to upload missing items from dashboard
5. ✅ "Submit for Review" button (only enabled when 100% complete)

### **Priority 2 (Important):**
6. Admin review interface (separate ticket)
7. Email/SMS notifications (when submitted, approved, rejected)
8. Rejection handling (admin can request changes)

### **Priority 3 (Nice to Have):**
9. Profile preview mode
10. Progress tracking analytics
11. Reminder notifications (24hr, 48hr after signup)

---

## 📝 **NEXT STEPS**

**Would you like me to:**

**A)** Implement the profile completion system now? (2-3 hours)
- Create `ProfileCompletionService`
- Update `TutorHomeScreen` to show completion status
- Add checklist widget
- Enable upload from dashboard

**B)** First run the app with clean build to see current state?
- Run `flutter run -d macos`
- Test what's working
- Identify exact missing pieces

**C)** Create detailed tickets for V1 roadmap?
- Break down into small tasks
- Estimate time for each
- Prioritize by importance

---

**My Recommendation:** Option B → Test current state, then Option A → Implement completion system.

This ensures tutors **cannot submit incomplete profiles** and **must finish all required items while waiting for approval**! 🎯


