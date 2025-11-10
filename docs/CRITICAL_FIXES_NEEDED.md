# Critical Fixes Needed

## ✅ Fixed
1. **`about_me` column error** - Removed `about_me` field from `_prepareTutorData()` (line 4721)

## 🔧 Need to Fix

### 1. Image Preview for ID Cards
**Issue:** ID card images not showing when loaded from DB
**Fix:** Enhanced `_buildDocumentPreview()` to check multiple sources for URLs
**Location:** Line ~3147

### 2. Certificate Loading
**Issue:** Certificates not loading from database
**Fix:** Added debug logging and ensured proper loading
**Location:** Line ~457

### 3. Availability Loading
**Issue:** Availability not loading for both services
**Fix:** Need to check normalization and ensure both `tutoring_availability` and `test_session_availability` load correctly
**Location:** Line ~261

### 4. Font Sizes
**Issue:** Fonts too large, need iOS/Android standard sizes
**Fix:** Replace custom font sizes with Flutter default text styles
**Standard sizes:**
- Body text: 14sp (iOS), 14sp (Android)
- Headings: 17sp (iOS), 16sp (Android)
- Subheadings: 15sp (iOS), 14sp (Android)
- Captions: 12sp (iOS), 12sp (Android)

### 5. Text Wrapping
**Issue:** "Tutoring Sessions" text wrapping on small screens
**Fix:** Use `FittedBox` or smaller font size for small screens
**Location:** Line ~1905

### 6. Admin Dashboard
**Issue:** Need to display all fields (social links, preferences, payment expectations, digital readiness)
**Location:** PrepSkul_Web app

