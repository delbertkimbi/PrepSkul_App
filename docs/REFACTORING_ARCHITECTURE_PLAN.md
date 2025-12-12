# 🏗️ Tutor Onboarding Refactoring - Clean Architecture

**Current:** 3,100 lines in ONE file ❌  
**Target:** Organized, modular, professional structure ✅  
**Time:** 2-3 hours  
**Status:** IN PROGRESS

---

## 📁 **NEW FOLDER STRUCTURE**

```
lib/features/tutor/
├── screens/
│   └── tutor_onboarding_screen.dart (MAIN - just orchestration, ~200 lines)
│
├── widgets/
│   ├── onboarding/
│   │   ├── personal_info_step.dart
│   │   ├── academic_background_step.dart
│   │   ├── experience_step.dart
│   │   ├── tutoring_details_step.dart
│   │   ├── availability_step.dart
│   │   ├── payment_step.dart
│   │   ├── verification_step.dart
│   │   └── review_step.dart
│   │
│   ├── file_uploads/
│   │   ├── profile_photo_upload.dart
│   │   ├── document_upload_card.dart
│   │   ├── certificate_upload_section.dart
│   │   └── upload_progress_indicator.dart
│   │
│   └── common/
│       ├── selection_card.dart
│       ├── toggle_option.dart
│       ├── input_field.dart
│       ├── availability_calendar.dart
│       └── step_indicator.dart
│
├── models/
│   └── tutor_onboarding_data.dart (All state in one place)
│
└── services/
    └── tutor_onboarding_service.dart (Save/load logic)
```

---

## 🎯 **BENEFITS OF THIS STRUCTURE**

### **1. Separation of Concerns**
- Each step = One file (~200-300 lines)
- Easy to find and edit specific sections
- Clear responsibility for each widget

### **2. Reusability**
- File upload widgets can be used elsewhere
- Common widgets (selection cards, toggles) reused across steps
- DRY principle (Don't Repeat Yourself)

### **3. Testability**
- Each widget can be tested independently
- Mock data easily injected
- Unit tests for state management

### **4. Maintainability**
- New developer can understand structure quickly
- Changes to one step don't affect others
- Easy to add/remove steps

### **5. Team Collaboration**
- Multiple developers can work on different steps
- Reduced merge conflicts
- Clear file ownership

---

## 📦 **FILE BREAKDOWN**

### **Main Screen (tutor_onboarding_screen.dart) - ~200 lines**
```dart
class TutorOnboardingScreen extends StatefulWidget {
  // Just orchestration - manages PageController and navigation
}

class _TutorOnboardingScreenState extends State<TutorOnboardingScreen> {
  final PageController _pageController = PageController();
  final TutorOnboardingData _data = TutorOnboardingData(); // State holder
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: _buildAppBar(),
      body: PageView(
        controller: _pageController,
        physics: NeverScrollableScrollPhysics(),
        children: [
          PersonalInfoStep(data: _data, onNext: _goToNext),
          AcademicBackgroundStep(data: _data, onNext: _goToNext),
          ExperienceStep(data: _data, onNext: _goToNext),
          TutoringDetailsStep(data: _data, onNext: _goToNext),
          AvailabilityStep(data: _data, onNext: _goToNext),
          PaymentStep(data: _data, onNext: _goToNext),
          VerificationStep(data: _data, onNext: _goToNext),
          ReviewStep(data: _data, onSubmit: _submitProfile),
        ],
      ),
    );
  }
}
```

### **Step Widgets - Each ~200-300 lines**

#### **1. PersonalInfoStep**
- Name, DOB, Location, City, Quarter
- Profile photo upload
- About me

#### **2. AcademicBackgroundStep**
- Highest education
- Institution
- Field of study
- Certifications

#### **3. ExperienceStep**
- Teaching experience (yes/no)
- Duration
- Previous roles
- Motivation

#### **4. TutoringDetailsStep**
- Tutoring areas
- Learner levels
- Specializations
- Teaching approaches

#### **5. AvailabilityStep**
- Availability calendar
- Preferred session types
- Hours per week

#### **6. PaymentStep**
- Payment method
- Rate
- Payment details (MTN/Orange)
- Policy agreement

#### **7. VerificationStep**
- ID card uploads (front/back)
- Certificate uploads
- Video introduction
- Social media links
- Verification agreement

#### **8. ReviewStep**
- Summary of all entered data
- Edit buttons for each section
- Final submission

---

## 🎨 **FILE UPLOAD WIDGETS**

### **ProfilePhotoUpload Widget**
```dart
class ProfilePhotoUpload extends StatefulWidget {
  final File? currentPhoto;
  final String? currentUrl;
  final Function(File file, String url) onPhotoUploaded;
  
  @override
  Widget build(BuildContext context) {
    // Circle avatar preview
    // Upload button
    // Progress indicator
  }
}
```

### **DocumentUploadCard Widget**
```dart
class DocumentUploadCard extends StatelessWidget {
  final String title;
  final String description;
  final String documentType;
  final File? file;
  final String? url;
  final Function(File file, String url) onUploaded;
  
  @override
  Widget build(BuildContext context) {
    // Document icon
    // Title & description
    // Upload button
    // Status indicator
  }
}
```

---

## 📊 **STATE MANAGEMENT**

### **TutorOnboardingData Model**
```dart
class TutorOnboardingData {
  // Personal Info
  String? fullName;
  DateTime? dateOfBirth;
  String? city;
  String? quarter;
  
  // Files
  File? profilePhotoFile;
  String? profilePhotoUrl;
  File? idCardFrontFile;
  String? idCardFrontUrl;
  File? idCardBackFile;
  String? idCardBackUrl;
  Map<String, File> certificateFiles = {};
  Map<String, String> certificateUrls = {};
  
  // Academic
  String? selectedEducation;
  String? institution;
  String? fieldOfStudy;
  List<Certification> certifications = [];
  
  // ... all other fields
  
  // Methods
  Map<String, dynamic> toJson() { /* ... */ }
  void fromJson(Map<String, dynamic> json) { /* ... */ }
  
  Future<void> save() async {
    // Save to SharedPreferences
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('tutor_onboarding', jsonEncode(toJson()));
  }
  
  Future<void> load() async {
    // Load from SharedPreferences
    final prefs = await SharedPreferences.getInstance();
    final data = prefs.getString('tutor_onboarding');
    if (data != null) fromJson(jsonDecode(data));
  }
}
```

---

## 🔄 **IMPLEMENTATION STEPS**

### **Phase 1: Create Folder Structure (5 mins)**
```bash
mkdir -p lib/features/tutor/widgets/onboarding
mkdir -p lib/features/tutor/widgets/file_uploads
mkdir -p lib/features/tutor/widgets/common
mkdir -p lib/features/tutor/models
mkdir -p lib/features/tutor/services
```

### **Phase 2: Create State Model (15 mins)**
- Create `tutor_onboarding_data.dart`
- Define all fields
- Add `toJson()` and `fromJson()`
- Add `save()` and `load()` methods

### **Phase 3: Create Common Widgets (30 mins)**
- `selection_card.dart` - Reusable selection cards
- `toggle_option.dart` - Yes/No toggles
- `input_field.dart` - Text input fields
- `availability_calendar.dart` - Calendar grid
- `step_indicator.dart` - Progress indicator

### **Phase 4: Create File Upload Widgets (30 mins)**
- `profile_photo_upload.dart`
- `document_upload_card.dart`
- `certificate_upload_section.dart`
- `upload_progress_indicator.dart`

### **Phase 5: Create Step Widgets (1-2 hours)**
- Extract each step from the monolithic file
- Use common widgets
- Connect to state model
- Test each step

### **Phase 6: Update Main Screen (30 mins)**
- Simplify to just orchestration
- PageView with step widgets
- Navigation logic
- Progress tracking

### **Phase 7: Test Everything (30 mins)**
- Test each step individually
- Test full flow
- Test auto-save
- Test file uploads
- Verify data in database

---

## ✅ **READY TO START?**

This refactoring will make the codebase:
- ✅ Professional
- ✅ Maintainable
- ✅ Scalable
- ✅ Easy to understand
- ✅ Easy to test
- ✅ Ready for team collaboration

**Let's do this properly!** 🚀

**Shall I start creating the new structure?**

