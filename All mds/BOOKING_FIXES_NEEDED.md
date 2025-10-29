# 🔧 Booking System Fixes Needed

**Date**: October 29, 2025  
**Status**: 🚧 **IN PROGRESS**

---

## 🎯 **Issues to Address:**

### **1. Trial Session Booking** ❌ NOT YET IMPLEMENTED
**Problem**: User can book a tutor but not a trial session  
**Requirements**:
- Trial sessions are typically online
- Use existing calendar UI for time slot selection
- Different from regular booking (single session, not recurring)
- Needs separate flow or modal

**Files to Create/Modify**:
- `lib/features/booking/screens/book_trial_session_screen.dart` (new)
- `lib/features/booking/models/trial_session_model.dart` (new)
- `lib/features/tutor/screens/tutor_detail_screen.dart` (add trial booking button)

---

### **2. Pre-fill Address from Survey** ⚠️ PARTIALLY WORKING
**Problem**: User's address from onboarding not being pre-filled in booking  
**Current State**: Code exists but surveys don't save to database  
**Requirements**:
- Fetch city & quarter from learner_profiles/parent_profiles
- Pre-fill in location selector
- Allow editing but default to survey data

**Files to Modify**:
- ✅ `lib/features/booking/screens/book_tutor_flow_screen.dart` (already has logic)
- ❌ `lib/features/profile/screens/student_survey.dart` (needs to save to DB)
- ❌ `lib/features/profile/screens/parent_survey.dart` (needs to save to DB)

---

### **3. Payment Plan Default Selection** ✅ FIXED
**Problem**: Monthly was pre-selected by default, disabling "Send Request" button  
**Fix Applied**: Changed `initialPaymentPlan ?? 'monthly'` to just `initialPaymentPlan`  
**Result**: User must explicitly select a payment plan

**Files Modified**:
- ✅ `lib/features/booking/widgets/booking_review.dart`

---

### **4. Survey Data Not Syncing to Database** ❌ CRITICAL
**Problem**: Student/Parent surveys save to SharedPreferences only, not Supabase  
**Impact**: Can't pre-fill booking data, profile incomplete, data lost on device change  
**Requirements**:
- Save all survey data to `learner_profiles` or `parent_profiles` table
- Update `profiles.survey_completed = true`
- Fetch and use this data in booking flow

**Files to Modify**:
- `lib/features/profile/screens/student_survey.dart`
- `lib/features/profile/screens/parent_survey.dart`
- `lib/core/services/survey_repository.dart` (create student/parent save methods)

---

## 📋 **Implementation Plan:**

### **PHASE 1: Fix Survey Database Sync** (Priority: HIGH)
This unlocks pre-filling and proper data management.

#### **Step 1: Create Survey Save Methods**
```dart
// In survey_repository.dart

static Future<void> saveStudentSurvey({
  required Map<String, dynamic> data,
}) async {
  final userId = client.auth.currentUser?.id;
  if (userId == null) throw Exception('User not authenticated');

  // Update profiles table
  await client.from('profiles').update({
    'survey_completed': true,
    'full_name': data['student_name'],
  }).eq('id', userId);

  // Insert or update learner_profiles
  await client.from('learner_profiles').upsert({
    'user_id': userId,
    'city': data['city'],
    'quarter': data['quarter'],
    'preferred_location': data['preferred_location'],
    'preferred_schedule': data['preferred_schedule'],
    'learning_path': data['learning_path'],
    'education_level': data['education_level'],
    'subjects': data['subjects'],
    'budget_min': data['min_budget'],
    'budget_max': data['max_budget'],
    'learning_goals': data['learning_goals'],
    'challenges': data['challenges'],
    'payment_plan_preferences': {
      'preferred_plan': 'monthly', // default
    },
  });
}
```

#### **Step 2: Update Student Survey Completion**
```dart
// In student_survey.dart _completeSurvey()

await SurveyRepository.saveStudentSurvey(data: {
  'student_name': _studentName,
  'city': _selectedCity,
  'quarter': _isCustomQuarter ? _customQuarter : _selectedQuarter,
  'preferred_location': _preferredLocation,
  'learning_path': _selectedLearningPath,
  'education_level': _selectedEducationLevel,
  'subjects': _selectedSubjects,
  'min_budget': _minBudget,
  'max_budget': _maxBudget,
  'learning_goals': _learningGoals,
  'challenges': _challenges,
});
```

#### **Step 3: Update Parent Survey Similarly**

---

### **PHASE 2: Implement Trial Session Booking** (Priority: HIGH)

#### **Step 1: Create Trial Session Model**
```dart
class TrialSession {
  final String id;
  final String studentId;
  final String tutorId;
  final DateTime scheduledTime;
  final int durationMinutes; // 30, 60, or 90
  final double cost;
  final String status; // pending, confirmed, completed, cancelled
  final String? meetingLink;
  final String? trialGoal;
  
  // ... rest of model
}
```

#### **Step 2: Update Database Schema**
```sql
CREATE TABLE IF NOT EXISTS public.trial_sessions (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  student_id UUID REFERENCES public.profiles(id) NOT NULL,
  tutor_id UUID REFERENCES public.profiles(id) NOT NULL,
  scheduled_time TIMESTAMP WITH TIME ZONE NOT NULL,
  duration_minutes INTEGER NOT NULL CHECK (duration_minutes IN (30, 60, 90)),
  cost DECIMAL(10, 2) NOT NULL,
  status TEXT NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'confirmed', 'completed', 'cancelled')),
  meeting_link TEXT,
  trial_goal TEXT,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);
```

#### **Step 3: Create Trial Booking Screen**
- Simplified flow (no multi-step wizard)
- Calendar UI for time selection
- Duration selector (30/60/90 min)
- Trial goal/reason input
- Pricing display
- Immediate booking

---

### **PHASE 3: Test & Polish** (Priority: MEDIUM)

#### **Test Scenarios**:
1. Complete student survey → Data saves to DB ✅
2. Start booking → Address pre-fills ✅
3. Book trial → Success, tutor sees request ✅
4. Book tutor → Success, tutor sees request ✅
5. Edit address → Saves custom address ✅

---

## 🚀 **Quick Win: Address Pre-filling**

Since the code already exists in `book_tutor_flow_screen.dart`, we just need to:
1. Save survey data to database
2. The existing pre-fill logic will work automatically

**Current Code (Lines 48-76)**:
```dart
void _prefillFromSurvey() {
  if (widget.surveyData == null) return;
  
  // Pre-fill address (if onsite)
  if (survey['city'] != null && survey['quarter'] != null) {
    _onsiteAddress = '${survey['city']}, ${survey['quarter']}';
  }
}
```

**This works if `widget.surveyData` contains city/quarter!**

---

## 📝 **Files Created/Modified:**

### **To Create**:
- `lib/features/booking/screens/book_trial_session_screen.dart`
- `lib/features/booking/models/trial_session_model.dart`
- `supabase/migrations/004_trial_sessions.sql`

### **To Modify**:
- ✅ `lib/features/booking/widgets/booking_review.dart` (fixed)
- ⏳ `lib/features/profile/screens/student_survey.dart`
- ⏳ `lib/features/profile/screens/parent_survey.dart`
- ⏳ `lib/core/services/survey_repository.dart`
- ⏳ `lib/features/discovery/screens/tutor_detail_screen.dart`

---

## ✅ **What's Working Now:**

- [x] Payment plan requires user selection (not pre-selected)
- [x] Booking flow saves to database
- [x] Tutor can approve/reject
- [x] Navigation works
- [x] Pre-fill logic exists (just needs data)

## ❌ **What Needs Work:**

- [ ] Survey data saves to database
- [ ] Trial session booking
- [ ] Address actually pre-fills (blocked by survey save)
- [ ] User can edit pre-filled address

---

## 🎯 **Next Steps:**

1. **Fix Survey Database Sync** (30 min)
   - Update student_survey.dart
   - Update parent_survey.dart
   - Test data saves

2. **Verify Address Pre-fill** (10 min)
   - Complete survey as student
   - Start booking
   - Confirm address appears

3. **Build Trial Session Booking** (60 min)
   - Create model & screen
   - Add database table
   - Wire up to tutor detail

4. **Test Everything** (30 min)
   - End-to-end both flows
   - Fix any bugs

**Total Estimated Time: 2 hours**

---

**Ready to proceed?** Let me know which phase to start with!

