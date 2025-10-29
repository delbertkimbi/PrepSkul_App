# 🔗 Survey Integration Guide

## Quick Integration Steps

For each survey screen, we need to:
1. Import the SurveyRepository
2. Replace the `_completeSurvey()` or `_submitApplication()` method
3. Add loading states
4. Navigate to home after successful save

---

## ✅ Files to Update:

1. `lib/features/profile/screens/student_survey.dart` - Line 2335
2. `lib/features/profile/screens/parent_survey.dart` - Line 2430  
3. `lib/features/tutor/screens/tutor_onboarding_screen.dart` - Line 2879

---

## 📝 Integration Code Snippets:

### **1. Add Import (Top of each file):**

```dart
import 'package:prepskul/core/services/survey_repository.dart';
```

### **2. Add Loading State (In State class):**

```dart
bool _isSaving = false;
```

### **3. Update Button to Show Loading:**

```dart
child: _isSaving
    ? const SizedBox(
        width: 24,
        height: 24,
        child: CircularProgressIndicator(
          color: Colors.white,
          strokeWidth: 2,
        ),
      )
    : Text(
        _currentStep == _steps.length - 1 ? 'Complete' : 'Next',
        style: GoogleFonts.poppins(
          fontSize: 16,
          fontWeight: FontWeight.w600,
        ),
      ),
```

---

## 🎯 Replacement Methods:

Due to the complexity of mapping all survey fields, I'll provide the exact replacement code for each file in separate focused updates.

**Next Step:** Run the command below to apply all integrations automatically.

Or manually update each `_completeSurvey()` method following the pattern in the next section.



## Quick Integration Steps

For each survey screen, we need to:
1. Import the SurveyRepository
2. Replace the `_completeSurvey()` or `_submitApplication()` method
3. Add loading states
4. Navigate to home after successful save

---

## ✅ Files to Update:

1. `lib/features/profile/screens/student_survey.dart` - Line 2335
2. `lib/features/profile/screens/parent_survey.dart` - Line 2430  
3. `lib/features/tutor/screens/tutor_onboarding_screen.dart` - Line 2879

---

## 📝 Integration Code Snippets:

### **1. Add Import (Top of each file):**

```dart
import 'package:prepskul/core/services/survey_repository.dart';
```

### **2. Add Loading State (In State class):**

```dart
bool _isSaving = false;
```

### **3. Update Button to Show Loading:**

```dart
child: _isSaving
    ? const SizedBox(
        width: 24,
        height: 24,
        child: CircularProgressIndicator(
          color: Colors.white,
          strokeWidth: 2,
        ),
      )
    : Text(
        _currentStep == _steps.length - 1 ? 'Complete' : 'Next',
        style: GoogleFonts.poppins(
          fontSize: 16,
          fontWeight: FontWeight.w600,
        ),
      ),
```

---

## 🎯 Replacement Methods:

Due to the complexity of mapping all survey fields, I'll provide the exact replacement code for each file in separate focused updates.

**Next Step:** Run the command below to apply all integrations automatically.

Or manually update each `_completeSurvey()` method following the pattern in the next section.

