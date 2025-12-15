# 🧪 PrepSkul App - Testing Guide

**Date:** October 28, 2025  
**Version:** Pre-V1 (Foundation Complete)  
**Status:** ✅ Ready for Testing

---

## 🎯 **WHAT TO TEST**

### **1. TUTOR FLOW** 🎓

#### **Step 1: Signup**
1. Open app → Should show onboarding screens
2. Tap "Get Started" → Navigate to Login/Signup
3. Tap "Sign Up"
4. Fill in:
   - Full Name: `Test Tutor`
   - Phone Number: `674208573` (without +237)
   - Select Role: **Tutor**
   - Password: `test123`
   - Confirm Password: `test123`
5. Tap "Sign Up" → Navigate to OTP screen

#### **Step 2: OTP Verification**
1. **For Testing (Supabase Test Number):**
   - Enter OTP: `987654`
   - Tap "Verify"
   
2. **For Real Phone:**
   - Check SMS for 6-digit code
   - Enter code
   - Tap "Verify"

3. Should navigate to **Tutor Onboarding Survey**

#### **Step 3: Tutor Onboarding**
1. Complete all survey steps:
   - Personal Information
   - Academic Background
   - Experience
   - Tutoring Details
   - Availability
   - Payment Information
   - Video Introduction (optional - can skip)
   - Verification Documents

2. **Auto-Save Feature:**
   - Exit app mid-survey
   - Re-login
   - Should resume from where you stopped

3. After completing survey → Navigate to **Tutor Navigation**

#### **Step 4: Tutor Dashboard**
**Expected UI:**
- ✅ Bottom Navigation: Home | Requests | Students | Profile
- ✅ Home Tab: "Pending Approval" card (beautiful gradient)
- ✅ Info cards: "Next Steps" and "In the Meantime"
- ✅ Requests Tab: "No requests yet" empty state
- ✅ Students Tab: "No students yet" empty state
- ✅ Profile Tab: Avatar with first letter, name, phone, settings, logout

#### **Step 5: Profile & Logout**
1. Tap **Profile** tab
2. Should see:
   - Large circular avatar with first letter
   - Full name and phone number
   - "Tutor" badge
   - Settings options (Edit Profile, Notifications, Language, Help, About)
   - Red "Logout" button
3. Tap "Logout" → Confirm → Return to Login screen

---

### **2. STUDENT FLOW** 📚

#### **Step 1: Signup**
1. Open app → Onboarding → Signup
2. Fill in:
   - Full Name: `Test Student`
   - Phone Number: `677123456`
   - Select Role: **Student**
   - Password: `test123`
   - Confirm Password: `test123`
3. Tap "Sign Up" → Navigate to OTP screen

#### **Step 2: OTP Verification**
- Same as tutor flow
- Should navigate to **Student Survey**

#### **Step 3: Student Survey**
1. Complete survey:
   - Basic Information (DOB, Location, City, Quarter)
   - Learning Path Selection (Academic/Skill/Exam Prep)
   - Dynamic questions based on path
   - Learning Preferences (subjects, schedule, budget)
   - Tutor Preferences
   - Learning Goals

2. After completion → Navigate to **Student Navigation**

#### **Step 4: Student Dashboard**
**Expected UI:**
- ✅ Bottom Navigation: Find Tutors | My Tutors | Profile
- ✅ Find Tutors Tab: "Coming Soon!" card with feature preview
- ✅ Features list: Smart Search, Advanced Filters, Verified Tutors, Easy Booking
- ✅ My Tutors Tab: "No tutors yet" empty state
- ✅ Profile Tab: Avatar, name, phone, "Student" badge, settings, logout

---

### **3. PARENT FLOW** 👨‍👩‍👧

#### **Step 1: Signup**
1. Open app → Onboarding → Signup
2. Fill in:
   - Full Name: `Test Parent`
   - Phone Number: `678234567`
   - Select Role: **Parent**
   - Password: `test123`
   - Confirm Password: `test123`
3. Tap "Sign Up" → Navigate to OTP screen

#### **Step 2: OTP Verification**
- Same as above
- Should navigate to **Parent Survey**

#### **Step 3: Parent Survey**
1. Complete survey:
   - Basic Information (Relationship to child, child's info)
   - Learning Path Selection (for child)
   - Dynamic questions
   - Budget Range (2,500 - 15,000 XAF slider)
   - Tutor Preferences

2. After completion → Navigate to **Parent Navigation**

#### **Step 4: Parent Dashboard**
**Expected UI:**
- ✅ Bottom Navigation: Find Tutors | My Tutors | Profile (same as student)
- ✅ Find Tutors Tab: "Coming Soon!" card
- ✅ My Tutors Tab: "No tutors yet" empty state
- ✅ Profile Tab: Avatar, name, phone, "Parent" badge, settings, logout

---

## ✅ **EXPECTED BEHAVIORS**

### **Auto-Save**
- ✅ Survey progress saved automatically
- ✅ Can exit app and resume later
- ✅ No data loss

### **Navigation**
- ✅ Bottom nav works smoothly
- ✅ Selected tab highlighted in blue
- ✅ Can switch between tabs without issues

### **Profile**
- ✅ Shows correct user info
- ✅ Avatar displays first letter of name
- ✅ Correct role badge (Tutor/Student/Parent)
- ✅ Settings options work (show "Coming soon!" snackbar)
- ✅ Logout works (returns to login screen)

### **Re-Login**
- ✅ Existing users with completed survey → Go to role-based navigation
- ✅ Users with incomplete survey → Resume survey
- ✅ New users → Start onboarding

---

## 🚫 **WHAT SHOULD NOT HAPPEN**

### **NO More:**
- ❌ "Welcome to PrepSkul!" ugly home screen
- ❌ Compilation errors
- ❌ Duplicate code errors
- ❌ Navigation issues
- ❌ Data loss on exit

### **Should NOT See:**
- ❌ Any error screens
- ❌ Blank pages
- ❌ Broken navigation
- ❌ Missing bottom nav
- ❌ Incorrect role dashboards

---

## 🐛 **TESTING CHECKLIST**

### **Critical Tests**
- [ ] Tutor signup → OTP → Survey → Dashboard → Logout → Login
- [ ] Student signup → OTP → Survey → Dashboard → Logout → Login
- [ ] Parent signup → OTP → Survey → Dashboard → Logout → Login
- [ ] Exit app mid-survey → Re-login → Resume survey
- [ ] Complete survey → Exit app → Re-login → Go to dashboard (not survey)
- [ ] Logout → Login with existing credentials → Go to dashboard
- [ ] Switch between all bottom nav tabs (no crashes)
- [ ] Profile screen displays correct info
- [ ] All "Coming soon!" snackbars work

### **UI Tests**
- [ ] No overflow errors
- [ ] All text readable (proper colors on backgrounds)
- [ ] Buttons work and look good
- [ ] Loading indicators show during async operations
- [ ] Bottom nav looks professional
- [ ] Profile avatar displays correctly
- [ ] Empty states are beautiful and informative

### **Edge Cases**
- [ ] Try invalid phone number → Should show error
- [ ] Try mismatched passwords → Should show error
- [ ] Try empty fields → Should show error
- [ ] Try expired OTP → Should show error
- [ ] Try wrong OTP → Should show error

---

## 📱 **PLATFORMS TO TEST**

### **Priority 1 (Must Test):**
- ✅ macOS Desktop (for development)
- ✅ Android (real device or emulator)

### **Priority 2 (Should Test):**
- 🔄 iOS (simulator or device)
- 🔄 Web (Chrome/Safari)

### **Priority 3 (Nice to Test):**
- 🔄 Different screen sizes
- 🔄 Tablet layouts

---

## 🎯 **SUCCESS CRITERIA**

**The app is ready for V1 development if:**

1. ✅ All 3 user flows work end-to-end
2. ✅ No compilation errors
3. ✅ No crashes during normal use
4. ✅ Auto-save works correctly
5. ✅ Navigation is smooth and intuitive
6. ✅ Profile and logout work
7. ✅ Re-login works correctly
8. ✅ UI looks professional and modern
9. ✅ No ugly "Welcome" screen
10. ✅ All empty states are beautiful

---

## 🚀 **TESTING COMMANDS**

### **Run on macOS:**
```bash
cd /Users/user/Desktop/PrepSkul/prepskul_app
flutter run -d macos
```

### **Run on Android Emulator:**
```bash
flutter run -d emulator
```

### **Run on Web:**
```bash
flutter run -d chrome
```

### **Check for Errors:**
```bash
flutter analyze --no-fatal-infos
```

### **Clean Build (if issues):**
```bash
flutter clean
flutter pub get
flutter run
```

---

## 📝 **REPORTING ISSUES**

If you find bugs, note:
1. **User Type:** Tutor/Student/Parent
2. **Step:** Where in the flow did it happen?
3. **Expected:** What should have happened?
4. **Actual:** What actually happened?
5. **Screenshot/Error:** If possible

---

## ✨ **NEXT STEPS AFTER TESTING**

If all tests pass:
1. ✅ Mark Foundation as **COMPLETE**
2. ✅ Start **WEEK 1: Admin Dashboard + Payments**
3. ✅ Follow `V1_DEVELOPMENT_ROADMAP.md`

**Ready to build the REAL features!** 🚀

