# 🚀 PrepSkul Quick Reference

## 📁 **Current Codebase Structure**

### **Active Screens by Feature**

#### **Authentication** (`lib/features/auth/`)
- `beautiful_login_screen.dart` - Login with phone OTP
- `beautiful_signup_screen.dart` - Signup for all user types
- `forgot_password_screen.dart` - Password reset request
- `reset_password_screen.dart` - OTP + new password entry
- `otp_verification_screen.dart` - 6-digit OTP verification

#### **Onboarding** (`lib/features/onboarding/`)
- `simple_onboarding_screen.dart` - 3 slides intro

#### **Surveys** (`lib/features/profile/`)
- `tutor_onboarding_screen.dart` (in `features/tutor/`) - Full tutor profile (3k lines)
- `student_survey.dart` - Student learning preferences
- `parent_survey.dart` - Parent + child information

#### **Tutor Dashboard** (`lib/features/tutor/`)
- `tutor_home_screen.dart` - Home/pending approval
- `tutor_requests_screen.dart` - Student requests (placeholder)
- `tutor_students_screen.dart` - Current students (placeholder)

#### **Student/Parent Dashboard**
- `find_tutors_screen.dart` (in `features/discovery/`) - Search tutors (placeholder)
- `my_tutors_screen.dart` (in `features/sessions/`) - Connected tutors (placeholder)
- `profile_screen.dart` (in `features/profile/`) - User profile + settings

---

## 🔧 **Core Services**

### **Authentication** (`lib/core/services/auth_service.dart`)
```dart
// Send OTP
await AuthService.sendPasswordResetOTP(phone);

// Check login status
bool isLoggedIn = await AuthService.isLoggedIn();

// Get current user
Map<String, dynamic> user = await AuthService.getCurrentUser();

// Logout
await AuthService.logout();
```

### **Storage** (`lib/core/services/storage_service.dart`)
```dart
// Upload profile photo
String url = await StorageService.uploadProfilePhoto(
  userId: userId,
  imageFile: file,
);

// Upload document
String url = await StorageService.uploadDocument(
  userId: userId,
  documentFile: file,
  documentType: 'id_card_front',
);
```

### **Survey Repository** (`lib/core/services/survey_repository.dart`)
```dart
// Save tutor profile
await SurveyRepository.saveTutorSurvey(userId, profileData);

// Get tutor profile
TutorProfile? profile = await SurveyRepository.getTutorProfile(userId);
```

---

## 🎨 **Styling**

### **Theme** (`lib/core/theme/app_theme.dart`)
```dart
// Colors
AppTheme.primaryColor        // Deep blue
AppTheme.textDark           // Dark text
AppTheme.textMedium         // Medium gray
AppTheme.textLight          // Light gray
AppTheme.softBorder         // Border color

// Gradients
AppTheme.primaryGradient    // Blue gradient
```

### **Fonts (Google Fonts - Poppins)**
```dart
Text(
  'Hello',
  style: GoogleFonts.poppins(
    fontSize: 18,
    fontWeight: FontWeight.w600,
    color: AppTheme.textDark,
  ),
)
```

---

## 🧭 **Navigation**

### **Routes** (`lib/main.dart`)
```dart
// Static routes
/onboarding
/login
/forgot-password
/tutor-nav
/student-nav
/parent-nav

// Dynamic routes (with arguments)
/profile-setup      // args: {userRole: 'tutor'}
/reset-password     // args: {phone: '+237...'}
/otp-verification   // args: {phoneNumber, fullName, userRole}
```

### **Role-Based Bottom Nav** (`lib/core/navigation/main_navigation.dart`)
```dart
// Tutor tabs: Home, Requests, Students, Profile
// Student/Parent tabs: Find Tutors, My Tutors, Profile

Navigator.pushNamed(context, '/tutor-nav');
```

---

## 📊 **Data Models** (`lib/core/models/`)

### **User Profile** (`user_profile.dart`)
```dart
class UserProfile {
  final String id;
  final String? email;
  final String? phone;
  final String fullName;
  final String userType;  // 'tutor', 'student', 'parent'
  final bool surveyCompleted;
}
```

### **Tutor Profile** (`tutor_profile.dart`)
- Personal info (name, DOB, city, quarter, about)
- Academic background (education, institution, certifications)
- Experience (teaching experience, previous roles)
- Tutoring details (areas, levels, specializations)
- Availability (hours/week, time slots)
- Payment (method, rate, payment details)
- Verification (ID cards, video, social links)

### **Parent Profile** (`parent_profile.dart`)
- Relationship to child
- Children data (name, DOB, grade)
- Learning path (academic, skill, exam prep)
- Tutor preferences (gender, experience)
- Budget range

---

## 🧪 **Testing the App**

### **Run on macOS**
```bash
flutter run -d macos
```

### **Test Flows**
1. **First-Time User:**
   - Splash → Onboarding → Login/Signup → Survey → Dashboard

2. **Returning User (completed survey):**
   - Splash → Role-based Dashboard

3. **Tutor Flow:**
   - Signup → OTP → Tutor Onboarding (3k-line form) → Tutor Nav → Home (Pending Approval)

4. **Student/Parent Flow:**
   - Signup → OTP → Student/Parent Survey → Student Nav → Find Tutors

### **Test Auth**
- **Login:** Use existing phone number
- **Signup:** New phone → OTP → Survey
- **Forgot Password:** Phone → OTP → New Password
- **Logout:** Profile → Logout → Confirm

---

## 📦 **Database Schema** (`supabase/`)

### **Tables**
1. `profiles` - Base user data (phone, name, user_type, survey_completed)
2. `tutor_profiles` - Full tutor data
3. `learner_profiles` - Student data
4. `parent_profiles` - Parent data

### **Storage Buckets**
1. `profile-photos` - User profile pictures
2. `documents` - ID cards, certificates, etc.

---

## 🐛 **Known Issues/Warnings**

### **195 Warnings (Safe to Ignore)**
- Mostly unused fields in `tutor_onboarding_screen.dart`
- Won't affect functionality
- Will be cleaned up during V1 integration

### **macOS Deployment Target Warnings**
- Some pods have older deployment targets
- Doesn't prevent compilation
- Can be fixed later if needed

---

## 🚀 **What's Next?**

Check `V1_DEVELOPMENT_ROADMAP.md` for the full 50+ ticket V1 plan.

**Priority Features:**
1. Admin dashboard (tutor approval)
2. Tutor discovery (search/filter)
3. Booking system
4. Payments (Fapshi integration)
5. Messaging
6. Ratings/reviews

---

## 💡 **Quick Tips**

1. **Finding Files:** Use structure above - everything is organized by feature
2. **Adding New Features:** Create in `lib/features/[feature_name]/`
3. **Reusable Widgets:** Put in `lib/core/widgets/`
4. **Services:** Put in `lib/core/services/`
5. **Models:** Put in `lib/core/models/`

---

**Need help?** Check:
- `All mds/CLEANUP_COMPLETE.md` - Full cleanup summary
- `All mds/CODEBASE_CLEANUP_PLAN.md` - What was changed
- `V1_DEVELOPMENT_ROADMAP.md` - V1 feature roadmap


