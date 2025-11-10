# 🧪 Comprehensive Testing Guide for PrepSkul

**Date:** January 25, 2025

---

## 🎯 Overview

This guide provides step-by-step instructions for testing all Phase 1.2 features and ensuring the UI is modern, responsive, and user-friendly.

---

## 📱 **SETUP: Running the App**

### **Option 1: Flutter Web (Easiest for Quick Testing)**
```bash
cd /Users/user/Desktop/PrepSkul/prepskul_app
flutter run -d chrome
```

### **Option 2: Flutter Desktop (macOS)**
```bash
flutter run -d macos
```

### **Option 3: Mobile Device/Emulator**
```bash
# List available devices
flutter devices

# Run on specific device
flutter run -d <device-id>
```

### **Option 4: Hot Reload (During Development)**
- Press `r` in terminal for hot reload
- Press `R` for hot restart
- Press `q` to quit

---

## 🎨 **UI QUALITY CHECKLIST**

### **Modern Design Principles:**
- ✅ **Rounded Corners** - All cards use `BorderRadius.circular(12-20)`
- ✅ **Soft Shadows** - Subtle `BoxShadow` for depth
- ✅ **Consistent Spacing** - Using `SizedBox` with standard sizes (8, 12, 16, 24, 32)
- ✅ **Color Palette** - Using `AppTheme` for consistency
- ✅ **Typography** - Google Fonts (Poppins) with proper weights
- ✅ **Smooth Animations** - Page transitions and button presses
- ✅ **Responsive Layout** - Works on different screen sizes

### **Check These UI Elements:**
1. **Cards** - Should have rounded corners, subtle shadows
2. **Buttons** - Should have proper padding, rounded corners, clear labels
3. **Dialogs** - Should be centered, have proper spacing, clear actions
4. **Forms** - Should have clear labels, proper input fields
5. **Navigation** - Should be smooth, intuitive
6. **Colors** - Should be consistent across screens
7. **Text** - Should be readable, proper sizes, good contrast

---

## 🧪 **FEATURE TESTING GUIDE**

### **TEST 1: Post-Trial Dialog & Conversion Flow**

#### **Prerequisites:**
- Have a completed trial session in the database
- Or manually set a trial session status to "completed"

#### **Steps:**
1. **Open the App**
   ```bash
   flutter run -d chrome
   ```

2. **Login as Student/Parent**
   - Use existing account or create new one
   - Complete onboarding if needed

3. **Navigate to "My Requests"**
   - Should be in bottom navigation bar
   - Tap "My Requests" tab

4. **Check for Dialog**
   - If you have a completed trial, dialog should appear automatically
   - Dialog should show:
     - ✅ "Trial Session Completed!" header
     - ✅ Tutor name and subject
     - ✅ "Would you like to continue with this tutor?" question
     - ✅ "Not Now" button (left)
     - ✅ "Continue with Tutor" button (right, larger)

5. **Test Dialog Actions:**
   - **Tap "Not Now"** → Dialog should close, nothing happens
   - **Tap "Continue with Tutor"** → Should navigate to conversion screen

6. **Check Trial Session Card:**
   - Go to "Trial Sessions" tab
   - Find completed trial
   - Should see "Continue with Tutor" button at bottom
   - Button should be full-width, primary color

7. **Test Conversion Screen:**
   - Should have 4-step wizard
   - Step 1: Frequency selection (1x, 2x, 3x, 4x per week)
   - Step 2: Days selection (Monday-Sunday)
   - Step 3: Location selection (Online/Onsite/Hybrid)
   - Step 4: Review & Payment plan
   - All steps should have smooth transitions
   - Progress indicator at top should show current step

#### **Expected Results:**
- ✅ Dialog appears automatically for completed trials
- ✅ Dialog is modern, centered, with proper spacing
- ✅ Buttons are clear and easy to tap
- ✅ Conversion screen is intuitive and easy to navigate
- ✅ All form fields work correctly
- ✅ Can go back/forward between steps
- ✅ Final submission creates booking request

---

### **TEST 2: Trial Session Booking**

#### **Steps:**
1. **Navigate to "Find Tutors"**
   - Should be in bottom navigation
   - Browse or search for a tutor

2. **Select a Tutor**
   - Tap on tutor card
   - Should see tutor detail screen

3. **Tap "Book Trial Session"**
   - Should open trial booking screen
   - Should be a 3-step wizard

4. **Step 1: Subject & Duration**
   - Select subject from dropdown
   - Choose duration (30 or 60 minutes)
   - Should see fee update automatically

5. **Step 2: Date & Time**
   - Calendar should show available dates
   - Select a date
   - Select a time slot
   - Should see selected date/time highlighted

6. **Step 3: Goals & Review**
   - Enter learning goals (optional)
   - Enter challenges (optional)
   - Review all details
   - Location should be pre-filled from survey

7. **Submit Trial Request**
   - Tap "Submit" button
   - Should see success message
   - Should navigate back or to requests screen

#### **Expected Results:**
- ✅ All steps are clear and easy to follow
- ✅ Calendar is easy to use
- ✅ Time slots are clearly visible
- ✅ Form validation works (required fields)
- ✅ Success message appears after submission
- ✅ Trial appears in "My Requests" → "Trial Sessions"

---

### **TEST 3: Payment Flow (When Implemented)**

#### **Steps:**
1. **Complete Trial Booking** (from Test 2)
2. **Tutor Approves Trial** (need tutor account or admin)
3. **Navigate to Trial Payment**
   - Should see payment screen
   - Or notification to pay

4. **Enter Phone Number**
   - Should be pre-filled if available
   - Input field should be clear

5. **Initiate Payment**
   - Tap "Pay Now" button
   - Should show loading state
   - Should initiate Fapshi payment

6. **Payment Status**
   - Should show "Pending" status
   - Should poll for status updates
   - Should show "Success" when paid
   - Should show "Failed" if payment fails

#### **Expected Results:**
- ✅ Payment screen is clear and easy to use
- ✅ Phone number input works correctly
- ✅ Payment status updates in real-time
- ✅ Success/failure messages are clear
- ✅ Meet link appears after successful payment

---

### **TEST 4: My Requests Screen**

#### **Steps:**
1. **Navigate to "My Requests"**
   - Should be in bottom navigation

2. **Check All Tabs:**
   - **"All"** - Shows all requests
   - **"Pending Approval"** - Shows pending requests only
   - **"Custom Requests"** - Shows custom tutor requests
   - **"Trial Sessions"** - Shows trial sessions
   - **"Bookings"** - Shows regular booking requests

3. **Test Empty States:**
   - Each tab should show appropriate empty state
   - Empty state should have icon, title, subtitle
   - Should be centered and clear

4. **Test Request Cards:**
   - Each request type should have distinct card design
   - Cards should show all relevant information
   - Status chips should be color-coded
   - Should be able to tap cards to see details

5. **Test "Request a Tutor" Button:**
   - Should appear in empty states
   - Should navigate to request flow

#### **Expected Results:**
- ✅ All tabs work correctly
- ✅ Empty states are clear and helpful
- ✅ Request cards are well-designed
- ✅ Status indicators are clear
- ✅ Navigation works smoothly

---

### **TEST 5: UI Responsiveness**

#### **Test on Different Screen Sizes:**
1. **Chrome Browser** - Resize window to test different widths
2. **Mobile Emulator** - Test on phone-sized screen
3. **Tablet Emulator** - Test on tablet-sized screen

#### **Check:**
- ✅ Text is readable at all sizes
- ✅ Buttons are easy to tap
- ✅ Cards don't overflow
- ✅ Forms are usable
- ✅ Navigation is accessible
- ✅ Dialogs are properly sized

---

## 🐛 **COMMON ISSUES & FIXES**

### **Issue: App Won't Start**
```bash
# Clean and rebuild
flutter clean
flutter pub get
flutter run -d chrome
```

### **Issue: Hot Reload Not Working**
- Press `R` for hot restart instead of `r`
- Or stop and restart the app

### **Issue: Can't See Changes**
- Clear browser cache (Chrome: Cmd+Shift+Delete)
- Or use incognito mode
- Or restart the app

### **Issue: Database Errors**
- Check Supabase connection
- Verify environment variables in `.env`
- Check migration status in Supabase dashboard

### **Issue: UI Looks Old/Broken**
- Check if `AppTheme` is being used consistently
- Verify all imports are correct
- Check for missing dependencies

---

## 📊 **TESTING CHECKLIST**

### **UI/UX Testing:**
- [ ] All screens load without errors
- [ ] All buttons are clickable and responsive
- [ ] All forms validate correctly
- [ ] All dialogs appear and dismiss correctly
- [ ] All navigation works smoothly
- [ ] All empty states are clear
- [ ] All error messages are helpful
- [ ] All success messages are clear
- [ ] Colors are consistent across screens
- [ ] Typography is readable and consistent
- [ ] Spacing is consistent
- [ ] Shadows and borders are subtle
- [ ] Animations are smooth

### **Functionality Testing:**
- [ ] Trial booking flow works end-to-end
- [ ] Post-trial dialog appears for completed trials
- [ ] Conversion screen works correctly
- [ ] Payment flow works (when implemented)
- [ ] Request cards display correctly
- [ ] Status updates work
- [ ] Navigation between screens works
- [ ] Data persists correctly

### **Responsiveness Testing:**
- [ ] Works on mobile (phone)
- [ ] Works on tablet
- [ ] Works on desktop/web
- [ ] Works in different orientations
- [ ] Text is readable at all sizes
- [ ] Buttons are easy to tap
- [ ] Forms are usable

---

## 🚀 **QUICK START TESTING**

### **Fastest Way to Test UI:**
1. **Start the app:**
   ```bash
   cd /Users/user/Desktop/PrepSkul/prepskul_app
   flutter run -d chrome
   ```

2. **Login as Student:**
   - Use existing account or create new one

3. **Navigate to "My Requests":**
   - Check if UI loads correctly
   - Check if tabs work
   - Check if empty states look good

4. **Try Booking a Trial:**
   - Go to "Find Tutors"
   - Select a tutor
   - Tap "Book Trial Session"
   - Go through the flow
   - Check if UI is modern and responsive

5. **Check Completed Trial:**
   - If you have a completed trial, check if dialog appears
   - Check if "Continue with Tutor" button appears
   - Test the conversion flow

---

## 📝 **REPORTING ISSUES**

When you find issues, note:
1. **What you were testing** (e.g., "Post-trial dialog")
2. **What you expected** (e.g., "Dialog should appear")
3. **What actually happened** (e.g., "Dialog didn't appear")
4. **Steps to reproduce** (e.g., "1. Login, 2. Go to My Requests")
5. **Screenshots** (if possible)
6. **Device/Browser** (e.g., "Chrome on macOS")

---

## ✅ **SUMMARY**

**To test the UI:**
1. Run `flutter run -d chrome`
2. Login and navigate around
3. Check if everything looks modern and works smoothly
4. Test each feature flow
5. Report any issues

**UI should be:**
- ✅ Modern (rounded corners, soft shadows)
- ✅ Responsive (works on all screen sizes)
- ✅ Consistent (same colors, fonts, spacing)
- ✅ User-friendly (clear labels, easy navigation)
- ✅ Smooth (animations, transitions)

**Ready to test!** 🚀






