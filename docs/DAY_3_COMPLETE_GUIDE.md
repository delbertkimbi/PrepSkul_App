# 📚 Day 3 Complete Guide - Database & Models

## ✅ What's Been Built

### 1. **Database Schema** (Supabase)
Complete tables for all user types with RLS policies

### 2. **Data Models** (Type-safe Dart classes)
- `UserProfile` - Base user information
- `TutorProfile` - 30+ fields for tutors
- `StudentProfile` - Learning preferences & goals
- `ParentProfile` - Parent & children data

### 3. **Survey Repository** (Data persistence)
Methods to save/retrieve all survey data

---

## 🗄️ **STEP 1: Run Database Schema**

### Copy & Paste this into Supabase SQL Editor:

Go to: **Supabase Dashboard** → **SQL Editor** → **New Query**

```sql
-- COPY THE FIXED SCHEMA FROM THE PREVIOUS MESSAGE
-- (The one that starts with "CREATE OR REPLACE FUNCTION update_modified_column()")
```

Click **"Run this query"** (accept the destructive operation warning - it's safe!)

---

## 📦 **STEP 2: Verify Your Models**

All models are ready in `/lib/core/models/`:

```dart
// Import all models at once
import 'package:prepskul/core/models/models.dart';

// Now you can use:
UserProfile user = UserProfile.fromJson(json);
TutorProfile tutor = TutorProfile.fromJson(json);
StudentProfile student = StudentProfile.fromJson(json);
ParentProfile parent = ParentProfile.fromJson(json);
```

### **Key Features:**
✅ **Type-safe** - All fields properly typed
✅ **Null-safe** - Optional fields marked with `?`
✅ **JSON serialization** - `fromJson()` and `toJson()` methods
✅ **Nested models** - Certifications, Social Links, Child Data
✅ **Date handling** - Proper DateTime parsing
✅ **Number parsing** - Handles decimal conversions

---

## 🧪 **STEP 3: Test The Complete Flow**

### **Test 1: Tutor Signup & Survey**
1. Open app → Skip onboarding
2. **Create account**:
   - Name: `John Tutor`
   - Phone: `674208573`
   - Password: `test1234`
   - Role: **Tutor**
3. **Enter OTP**: `987654`
4. **Complete Tutor Survey** (fill all pages)
5. **Check Supabase**:
   - profiles table: ✅ Row with `user_type='tutor'`
   - tutor_profiles table: ✅ Row with all survey data

### **Test 2: Student Signup & Survey**
1. **Create account**:
   - Name: `Jane Student`
   - Phone: `674208574` (different number!)
   - Password: `test1234`
   - Role: **Student**
2. **Enter OTP**: `987654`
3. **Complete Student Survey**
4. **Check Supabase**:
   - profiles table: ✅ Row with `user_type='student'`
   - learner_profiles table: ✅ Row with survey data

### **Test 3: Parent Signup & Survey**
1. **Create account**:
   - Name: `Mary Parent`
   - Phone: `674208575`
   - Password: `test1234`
   - Role: **Parent**
2. **Enter OTP**: `987654`
3. **Complete Parent Survey**
4. **Check Supabase**:
   - profiles table: ✅ Row with `user_type='parent'`
   - parent_profiles table: ✅ Row with survey data

---

## 🔍 **Verify Data in Supabase**

After each test, check:

1. **Table Editor** → **profiles**
   - Should see the user with correct `user_type`
   - `survey_completed` should be `true`

2. **Table Editor** → **tutor_profiles** / **learner_profiles** / **parent_profiles**
   - Should see the survey data
   - All fields properly populated

---

## 🎯 **Using Models in Your App**

### **Fetch User Profile:**
```dart
import 'package:prepskul/core/models/models.dart';
import 'package:prepskul/core/services/survey_repository.dart';
import 'package:prepskul/core/services/auth_service.dart';

// Get current user's tutor profile
final userId = await AuthService.getUserId();
final tutorData = await SurveyRepository.getTutorProfile(userId!);
if (tutorData != null) {
  final tutor = TutorProfile.fromJson(tutorData);
  print('Tutor: ${tutor.highestEducation}');
  print('Rate: ${tutor.hourlyRate} ${tutor.currency}');
  print('Rating: ${tutor.rating}');
}
```

### **Save Survey Data:**
```dart
// From tutor onboarding screen
await SurveyRepository.saveTutorSurvey({
  'highest_education': 'Bachelor\'s Degree',
  'institution': 'University of Yaoundé',
  'field_of_study': 'Mathematics',
  'tutoring_area': ['Mathematics', 'Physics'],
  'hourly_rate': 5000.0,
  // ... all other fields
});
```

### **Update Profile:**
```dart
await SurveyRepository.updateTutorProfile(
  userId,
  {'bio': 'Updated bio text'},
);
```

---

## 🚀 **Next Steps (Day 4)**

Once schema is running and you've tested:

1. **Integrate SurveyRepository** into survey screens
2. **Build Dashboards** to display user data
3. **Add Profile Editing** functionality
4. **Implement File Uploads** (photos, documents)

---

## 📋 **Troubleshooting**

### **"Function update_modified_column does not exist"**
✅ **Fixed!** The new schema creates the function first

### **"Policy already exists"**
✅ **Fixed!** Uses `DROP POLICY IF EXISTS` before creating

### **Data not saving**
- Check console logs for `✅ Survey saved` message
- Verify user is authenticated (`AuthService.getUserId()`)
- Check Supabase logs in Dashboard → Logs

---

## ✅ **Day 3 Checklist**

- [ ] Run database schema in Supabase
- [ ] Verify all tables created
- [ ] Test tutor signup → survey → save
- [ ] Test student signup → survey → save  
- [ ] Test parent signup → survey → save
- [ ] Check data appears in Supabase tables
- [ ] Models compile without errors

**Once all checked, Day 3 is COMPLETE!** 🎉



## ✅ What's Been Built

### 1. **Database Schema** (Supabase)
Complete tables for all user types with RLS policies

### 2. **Data Models** (Type-safe Dart classes)
- `UserProfile` - Base user information
- `TutorProfile` - 30+ fields for tutors
- `StudentProfile` - Learning preferences & goals
- `ParentProfile` - Parent & children data

### 3. **Survey Repository** (Data persistence)
Methods to save/retrieve all survey data

---

## 🗄️ **STEP 1: Run Database Schema**

### Copy & Paste this into Supabase SQL Editor:

Go to: **Supabase Dashboard** → **SQL Editor** → **New Query**

```sql
-- COPY THE FIXED SCHEMA FROM THE PREVIOUS MESSAGE
-- (The one that starts with "CREATE OR REPLACE FUNCTION update_modified_column()")
```

Click **"Run this query"** (accept the destructive operation warning - it's safe!)

---

## 📦 **STEP 2: Verify Your Models**

All models are ready in `/lib/core/models/`:

```dart
// Import all models at once
import 'package:prepskul/core/models/models.dart';

// Now you can use:
UserProfile user = UserProfile.fromJson(json);
TutorProfile tutor = TutorProfile.fromJson(json);
StudentProfile student = StudentProfile.fromJson(json);
ParentProfile parent = ParentProfile.fromJson(json);
```

### **Key Features:**
✅ **Type-safe** - All fields properly typed
✅ **Null-safe** - Optional fields marked with `?`
✅ **JSON serialization** - `fromJson()` and `toJson()` methods
✅ **Nested models** - Certifications, Social Links, Child Data
✅ **Date handling** - Proper DateTime parsing
✅ **Number parsing** - Handles decimal conversions

---

## 🧪 **STEP 3: Test The Complete Flow**

### **Test 1: Tutor Signup & Survey**
1. Open app → Skip onboarding
2. **Create account**:
   - Name: `John Tutor`
   - Phone: `674208573`
   - Password: `test1234`
   - Role: **Tutor**
3. **Enter OTP**: `987654`
4. **Complete Tutor Survey** (fill all pages)
5. **Check Supabase**:
   - profiles table: ✅ Row with `user_type='tutor'`
   - tutor_profiles table: ✅ Row with all survey data

### **Test 2: Student Signup & Survey**
1. **Create account**:
   - Name: `Jane Student`
   - Phone: `674208574` (different number!)
   - Password: `test1234`
   - Role: **Student**
2. **Enter OTP**: `987654`
3. **Complete Student Survey**
4. **Check Supabase**:
   - profiles table: ✅ Row with `user_type='student'`
   - learner_profiles table: ✅ Row with survey data

### **Test 3: Parent Signup & Survey**
1. **Create account**:
   - Name: `Mary Parent`
   - Phone: `674208575`
   - Password: `test1234`
   - Role: **Parent**
2. **Enter OTP**: `987654`
3. **Complete Parent Survey**
4. **Check Supabase**:
   - profiles table: ✅ Row with `user_type='parent'`
   - parent_profiles table: ✅ Row with survey data

---

## 🔍 **Verify Data in Supabase**

After each test, check:

1. **Table Editor** → **profiles**
   - Should see the user with correct `user_type`
   - `survey_completed` should be `true`

2. **Table Editor** → **tutor_profiles** / **learner_profiles** / **parent_profiles**
   - Should see the survey data
   - All fields properly populated

---

## 🎯 **Using Models in Your App**

### **Fetch User Profile:**
```dart
import 'package:prepskul/core/models/models.dart';
import 'package:prepskul/core/services/survey_repository.dart';
import 'package:prepskul/core/services/auth_service.dart';

// Get current user's tutor profile
final userId = await AuthService.getUserId();
final tutorData = await SurveyRepository.getTutorProfile(userId!);
if (tutorData != null) {
  final tutor = TutorProfile.fromJson(tutorData);
  print('Tutor: ${tutor.highestEducation}');
  print('Rate: ${tutor.hourlyRate} ${tutor.currency}');
  print('Rating: ${tutor.rating}');
}
```

### **Save Survey Data:**
```dart
// From tutor onboarding screen
await SurveyRepository.saveTutorSurvey({
  'highest_education': 'Bachelor\'s Degree',
  'institution': 'University of Yaoundé',
  'field_of_study': 'Mathematics',
  'tutoring_area': ['Mathematics', 'Physics'],
  'hourly_rate': 5000.0,
  // ... all other fields
});
```

### **Update Profile:**
```dart
await SurveyRepository.updateTutorProfile(
  userId,
  {'bio': 'Updated bio text'},
);
```

---

## 🚀 **Next Steps (Day 4)**

Once schema is running and you've tested:

1. **Integrate SurveyRepository** into survey screens
2. **Build Dashboards** to display user data
3. **Add Profile Editing** functionality
4. **Implement File Uploads** (photos, documents)

---

## 📋 **Troubleshooting**

### **"Function update_modified_column does not exist"**
✅ **Fixed!** The new schema creates the function first

### **"Policy already exists"**
✅ **Fixed!** Uses `DROP POLICY IF EXISTS` before creating

### **Data not saving**
- Check console logs for `✅ Survey saved` message
- Verify user is authenticated (`AuthService.getUserId()`)
- Check Supabase logs in Dashboard → Logs

---

## ✅ **Day 3 Checklist**

- [ ] Run database schema in Supabase
- [ ] Verify all tables created
- [ ] Test tutor signup → survey → save
- [ ] Test student signup → survey → save  
- [ ] Test parent signup → survey → save
- [ ] Check data appears in Supabase tables
- [ ] Models compile without errors

**Once all checked, Day 3 is COMPLETE!** 🎉

