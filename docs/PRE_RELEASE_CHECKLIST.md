# 📦 Pre-Release Checklist - App Bundle Upload

**Current Version:** `1.0.0+10`  
**Date:** January 28, 2026

---

## ✅ Step 1: Fix Compilation Errors

- [x] **Fixed Agora video view compilation errors**
  - Added `sourceType` parameter to `AgoraVideoViewWidget`
  - Updated `local_video_pip.dart` to use correct parameter
  - Fixed VideoCanvas sourceType usage

---

## ✅ Step 2: Update Version Number

**Current:** `version: 1.0.0+10`

**Action Required:** Increment version before release
- **Option A (Patch):** `1.0.1+11` (bug fixes, minor improvements)
- **Option B (Minor):** `1.1.0+11` (new features, UI improvements)
- **Option C (Major):** `2.0.0+11` (major changes, breaking changes)

**Recommended:** `1.0.1+11` (since this includes bug fixes and UI improvements)

**To update:**
```yaml
# In pubspec.yaml
version: 1.0.1+11
```

---

## ✅ Step 3: Test Build Locally

Before uploading, test that the app builds successfully:

```bash
# Clean previous builds
flutter clean

# Get dependencies
flutter pub get

# Test Android build
flutter build appbundle --release

# Test iOS build (if applicable)
flutter build ios --release
```

**Check:**
- [ ] Build completes without errors
- [ ] No compilation warnings
- [ ] App size is reasonable

---

## ✅ Step 4: Critical Functionality Tests

Test these core features before release:

### Authentication & Onboarding
- [ ] User can sign up/login
- [ ] Onboarding flow works correctly
- [ ] Offline users see proper offline indicators (not 0% progress)

### Tutor Discovery
- [ ] Tutors load quickly (N+1 query fix verified)
- [ ] Tutor cards display correctly
- [ ] Tutor detail screen works
- [ ] Schedule preview shows correctly
- [ ] "View full schedule" navigates properly
- [ ] Tutor sharing works with rich link previews

### Booking & Sessions
- [ ] Trial session booking works
- [ ] Session cards differentiate online/onsite clearly
- [ ] Countdown timer works correctly
- [ ] Onsite tracking buttons work
- [ ] Session feedback flow works
- [ ] Feedback questions are specific (tutor vs student)

### Payments
- [ ] Payment history displays correctly
- [ ] Tutor earnings screen shows dismissible warning
- [ ] Payment flow completes successfully

### Messaging
- [ ] Notifications work correctly
- [ ] Messages send/receive properly
- [ ] Notification sorting tabs are correct size

---

## ✅ Step 5: Code Quality Checks

- [ ] No debug logs in production code
- [ ] No hardcoded secrets/API keys
- [ ] Error handling is proper
- [ ] No TODO comments for critical features
- [ ] All imports are used

---

## ✅ Step 6: Recent Changes Summary

### UI/UX Improvements
- ✅ Session cards differentiate online/onsite with colored borders
- ✅ Visual countdown timer for upcoming sessions
- ✅ Simplified availability display with "View More" link
- ✅ Tutor schedule page created
- ✅ Feedback flow improved with specific questions
- ✅ Next button size increased in feedback flow
- ✅ Custom request subject display size reduced
- ✅ Tutor payment UI improvements

### Performance Fixes
- ✅ Fixed N+1 query for tutor loading (24 queries → 1 query)
- ✅ Reduced excessive debug logging

### Bug Fixes
- ✅ Fixed quiz game screen compilation errors
- ✅ Fixed Agora video view sourceType parameter
- ✅ Fixed offline experience (users see dashboard, not onboarding)
- ✅ Fixed feedback navigation (single back press exits)

### Features
- ✅ Onsite presence check with selfie upload
- ✅ Tutor-specific feedback questions (what was taught, learner progress)
- ✅ Rich link previews for tutor sharing (like Preply)

---

## ✅ Step 7: Build App Bundle

Once all checks pass:

```bash
cd prepskul_app

# Clean
flutter clean
flutter pub get

# Build release bundle
flutter build appbundle --release

# The bundle will be at:
# build/app/outputs/bundle/release/app-release.aab
```

---

## ✅ Step 8: Pre-Upload Verification

- [ ] Bundle file exists and has reasonable size
- [ ] Version number matches what you want to release
- [ ] All recent changes are committed
- [ ] No sensitive data in bundle
- [ ] Test on a real device if possible

---

## ✅ Step 9: Upload to Play Console

1. Go to Google Play Console
2. Select your app
3. Go to "Production" or "Testing" track
4. Click "Create new release"
5. Upload the `.aab` file
6. Add release notes describing changes
7. Review and submit

---

## 📝 Release Notes Template

```
Version 1.0.1

New Features:
- Improved tutor schedule display with dedicated schedule page
- Enhanced session feedback with tutor-specific questions
- Rich link previews when sharing tutor profiles

Improvements:
- Faster tutor loading times
- Better offline experience
- Improved session card UI with clearer online/onsite distinction
- Visual countdown timer for upcoming sessions

Bug Fixes:
- Fixed various UI display issues
- Improved navigation flows
- Performance optimizations
```

---

## ⚠️ Important Notes

1. **Version Code:** Must increment with each upload (currently at 10, next should be 11)
2. **Testing:** Test on internal/closed testing track first before production
3. **Rollout:** Consider staged rollout (10% → 50% → 100%)
4. **Monitoring:** Watch for crashes/reports after release

---

**Status:** Ready to increment version and build ✅  
**Next Step:** Update version in `pubspec.yaml` to `1.0.1+11`
