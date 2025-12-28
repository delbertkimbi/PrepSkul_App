zs. # 📋 PrepSkul Development - Collaboration TODO List

**Last Updated:** January 2025  
**Purpose:** Comprehensive task list for team collaboration, testing, and development  
**Status Legend:**
- ✅ **Completed** - Feature implemented and verified
- 🔄 **In Progress** - Currently being worked on
- ⚠️ **Needs Improvement** - Implemented but needs refinement/testing
- ❌ **Not Started** - Not yet implemented

---

## 📊 **Quick Status Overview**

- **Total Tasks:** 130+
- **Completed:** ~40 tasks
- **In Progress:** ~10 tasks
- **Needs Improvement:** ~15 tasks
- **Not Started:** ~65 tasks

---

## 🎮 **skulMate Games - High Priority**

### ✅ **Completed Features**

1. ✅ **Phase 1 Features Applied to All Game Types**
   - Confetti animations on correct answers
   - XP system integration
   - Streak counter
   - Animated progress bars
   - Smooth transitions
   - Results screen integration
   - **Files:** `quiz_game_screen.dart`, `flashcard_game_screen.dart`, `matching_game_screen.dart`, `fill_blank_game_screen.dart`

2. ✅ **Game Library Core Features**
   - Game statistics (total games played, best scores, average time)
   - "Recently Played" section with sorting
   - Favorites functionality
   - Game search improvements
   - Game preview (first question/item)
   - Game sharing
   - Game deletion with confirmation
   - Sorting options (Most Recent, Recently Played, A-Z)
   - **Files:** `game_library_screen.dart`, `game_storage_service.dart`

3. ✅ **Social Features - Phase 1**
   - Leaderboards (global, daily/weekly/monthly/all-time)
   - Share results on social media
   - Challenge friends to beat your score
   - Friend system (add friends, see their progress)
   - Database schema (`friendships`, `leaderboards`, `challenges` tables)
   - UI screens (Leaderboard, Friends, Challenges)
   - Friend search functionality
   - Create challenge dialog UI
   - **Files:** `social_service.dart`, `leaderboard_screen.dart`, `friends_screen.dart`, `challenges_screen.dart`

4. ✅ **Game Generation - Basic Implementation**
   - AI-powered game generation from text
   - Document upload support (PDF, Word, Text)
   - Image upload support
   - Multiple game types (quiz, flashcards, matching, fill-blank)
   - **Files:** `skulmate_service.dart`, `game_generation_screen.dart`, `skulmate_upload_screen.dart`

### ⚠️ **Needs Improvement**

1. ⚠️ **Game Generation Error Handling**
   - **Status:** Basic error handling exists but needs refinement
   - **Issues:**
     - Error messages need to be more user-friendly (partially fixed)
     - API endpoint fallback logic needs testing
     - Image URL handling needs verification
   - **Priority:** High
   - **Files:** `skulmate_service.dart`, `game_generation_screen.dart`

2. ⚠️ **Game Library Enhancements**
   - **Status:** Core features complete, missing polish
   - **Needs:**
     - Game difficulty indicators
     - Game categories/tags
   - **Priority:** Medium
   - **Files:** `game_library_screen.dart`, `game_model.dart`

3. ⚠️ **Social Features - Remaining**
   - **Status:** Core complete, missing advanced features
   - **Needs:**
     - Compare stats with friends
     - Achievement showcase (show unlocked achievements)
     - Daily/weekly challenges (system-generated)
     - Challenge notifications
   - **Priority:** Medium
   - **Files:** `social_service.dart`, `challenges_screen.dart`

### ❌ **Not Started**

1. ❌ **Game Generation Improvements**
   - Improve AI prompt for better game quality
   - Add difficulty selection (Easy, Medium, Hard)
   - Add topic/subject tagging
   - Add game customization (number of questions, time limit)
   - Add batch generation (generate multiple games at once)
   - Add game templates (pre-made game structures)
   - Add generation progress indicators
   - **Priority:** Medium
   - **Estimated Time:** 2-3 days

2. ❌ **New Game Modes**
   - Wordle-Style: Guess the concept in 6 tries
   - Trivia Royale: Battle royale with multiple choice
   - Memory Palace: Spatial memory game
   - Speed Challenge: Answer as many as possible in time limit
   - Daily Challenge: One special game per day
   - Story Mode: Learn through narrative journey
   - **Priority:** Low (Future Enhancement)
   - **Estimated Time:** 5-7 days per game mode

---

## 📱 **App-Wide Features**

### ✅ **Completed Features**

1. ✅ **Tutor Onboarding**
   - Availability validation (1 trial + 1 weekly slot required)
   - All fields validated
   - Media links & video separated into dedicated page
   - Document upload blocker
   - Specializations tabbed UI
   - Web uploads fixed
   - **Files:** `tutor_onboarding_screen.dart`

2. ✅ **Auth & Navigation**
   - Email and phone authentication
   - Email confirmation flow with deep links
   - Forgot password functionality
   - Bottom navigation by role
   - Profile screens
   - **Files:** `auth_service.dart`, `navigation_service.dart`

3. ✅ **Discovery & Booking**
   - Tutor discovery with filters
   - Booking flow (trial & regular)
   - Request management for tutors
   - WhatsApp integration
   - **Files:** `find_tutors_screen.dart`, `booking_service.dart`

4. ✅ **Admin Dashboard**
   - Admin dashboard (Next.js)
   - Tutor approval/rejection workflow
   - Real-time metrics
   - **Files:** `PrepSkul_Web/app/admin/`

5. ✅ **Session Management - Core**
   - Session creation without requiring Google Calendar
   - "Add to Calendar" button
   - Session reminder notifications (24h, 1h, 15min before)
   - **Files:** `recurring_session_service.dart`, `my_sessions_screen.dart`

6. ✅ **Payment Integration - Core**
   - Fapshi payment initiation (trial & regular sessions)
   - Payment status polling with retry logic
   - Webhook handling for all payment types
   - Meet link auto-generation after payment
   - Payment success/failure notifications
   - Tutor earnings calculation (85% of session fee)
   - **Files:** `fapshi_service.dart`, `fapshi_webhook_service.dart`

7. ✅ **Notifications - Core**
   - In-app notifications
   - Push notifications (Firebase Admin service created)
   - Email notifications (Resend integration)
   - Notification deep linking
   - Role-based notification filtering
   - **Files:** `notification_helper_service.dart`, `notification_navigation_service.dart`

8. ✅ **Tutor Dashboard Status**
   - "Approved" badge display
   - Rejection reason display
   - Status cards
   - **Files:** `tutor_home_screen.dart`

9. ✅ **Tutor Earnings & Payouts**
   - View earnings by session
   - Wallet balance calculation
   - Request payout service
   - Payout UI screen
   - Transaction history
   - **Files:** `tutor_payout_service.dart`, `tutor_earnings_screen.dart`

10. ✅ **Session Feedback System**
    - Session feedback UI screens
    - Rating calculation and display
    - Feedback reminder scheduling
    - Deep linking to feedback
    - Tutor notification on new review
    - **Files:** `session_feedback_service.dart`, `session_feedback_screen.dart`

### ⚠️ **Needs Improvement**

1. ⚠️ **Push Notifications**
   - **Status:** Service created, needs testing
   - **Issues:**
     - Requires Firebase service account key in production
     - Backend API integration needs verification
     - Testing needed on real devices
   - **Priority:** High
   - **Files:** `PrepSkul_Web/lib/services/firebase-admin.ts`, `notification_helper_service.dart`

2. ⚠️ **Payment System**
   - **Status:** Core working, missing advanced features
   - **Needs:**
     - Refund processing (Fapshi API pending)
     - Wallet balance reversal (wallet system pending)
   - **Priority:** Medium (depends on external APIs)
   - **Files:** `fapshi_webhook_service.dart`, `session_payment_service.dart`

3. ⚠️ **Tutor Payouts**
   - **Status:** UI and service complete, missing disbursement
   - **Needs:**
     - Fapshi disbursement integration (API not yet available)
   - **Priority:** Medium (depends on external API)
   - **Files:** `tutor_payout_service.dart`

4. ⚠️ **Session Management**
   - **Status:** Basic features complete, missing advanced
   - **Needs:**
     - Google Meet integration verification
     - Session start/end tracking improvements
     - Video call quality indicators
     - Session recording (optional, with consent)
     - Session notes (tutor can add notes during/after)
     - Session history improvements (better UI, filters)
     - Reschedule/cancel flow improvements
   - **Priority:** High
   - **Files:** `meet_service.dart`, `session_lifecycle_service.dart`

### ❌ **Not Started - High Priority**

1. ❌ **Testing & Quality Assurance** ⚠️ **CRITICAL**
   - End-to-end testing of booking flow
   - Test notification deep linking
   - Test payment flows (trial, recurring)
   - Test session feedback system
   - Test tutor approval workflow
   - Test profile completion system
   - Test file uploads (all types)
   - Test on iOS devices (not just simulator)
   - Test on Android devices
   - Performance testing (slow networks, large files)
   - Error handling testing (network failures, API errors)
   - **Priority:** CRITICAL - Must complete before launch
   - **Estimated Time:** 1-2 weeks
   - **Assigned To:** QA Team / All Developers

2. ❌ **User Experience Improvements**
   - Loading states (skeleton screens, progress indicators)
   - Empty states (better messaging, CTAs)
   - Error messages (user-friendly, actionable) - *Partially done*
   - Offline mode (cache data, show offline indicator)
   - Pull-to-refresh (where applicable)
   - Search improvements (fuzzy search, filters)
   - Image optimization (compress before upload)
   - App performance (reduce bundle size, optimize images)
   - Accessibility (screen readers, larger text options)
   - **Priority:** High
   - **Estimated Time:** 1-2 weeks

3. ❌ **Notifications & Communication Enhancements**
   - In-app messaging (tutor-student chat)
   - Push notification improvements (better targeting, rich notifications)
   - Email notifications (session reminders, updates) - *Partially done*
   - SMS notifications (optional, for important events)
   - Notification preferences (granular control)
   - Notification history (see all notifications)
   - Mark as read/unread
   - Notification grouping
   - **Priority:** Medium
   - **Estimated Time:** 3-4 days

4. ❌ **Tutor Discovery & Matching Improvements**
   - Advanced filters (price range, availability, ratings)
   - Search improvements (by name, subject, location)
   - Sort options (price, rating, distance, availability)
   - Tutor comparison (side-by-side)
   - Save favorite tutors
   - Tutor recommendations (AI-powered matching)
   - Tutor availability calendar (visual)
   - Tutor reviews display improvements
   - **Priority:** High
   - **Estimated Time:** 2-3 days

### ❌ **Not Started - Medium Priority**

5. ❌ **Payment System Enhancements**
   - Payment retry mechanism
   - Payment failure notifications
   - Wallet system (if needed)
   - Payment history improvements (filters, search)
   - Receipt generation (PDF)
   - Payment analytics (for tutors)
   - **Priority:** Medium
   - **Estimated Time:** 2-3 days

6. ❌ **Analytics & Insights**
   - User analytics (session completion, engagement)
   - Tutor analytics (earnings, student retention)
   - Learning progress tracking (for students)
   - Performance dashboards
   - Usage statistics
   - Revenue analytics (for admin)
   - **Priority:** Medium
   - **Estimated Time:** 3-5 days
   - **Database:** Need analytics tables/views

---

## 🎨 **UI/UX Polish**

### ❌ **Not Started**

1. ❌ **Design System Consistency**
   - Standardize button styles
   - Standardize card designs
   - Standardize spacing/padding
   - Standardize typography hierarchy
   - Standardize color usage
   - Create component library
   - Dark mode support (optional)
   - **Priority:** Medium
   - **Estimated Time:** 1 week

2. ❌ **Onboarding Improvements**
   - Interactive tutorial (first-time user guide)
   - Skip option for returning users
   - Progress indicators (show steps completed)
   - Better error handling in surveys
   - Auto-save improvements (show save status)
   - Survey validation improvements
   - **Priority:** Medium
   - **Estimated Time:** 2-3 days

---

## 🔒 **Security & Performance**

### ❌ **Not Started**

1. ❌ **Security Enhancements**
   - Input validation (prevent SQL injection, XSS)
   - Rate limiting (prevent abuse)
   - File upload validation (file type, size) - *Partially done*
   - Session timeout
   - Two-factor authentication (optional)
   - Privacy settings (control data sharing)
   - **Priority:** High
   - **Estimated Time:** 2-3 days

2. ❌ **Performance Optimization**
   - Image lazy loading
   - Code splitting
   - Database query optimization
   - API response caching
   - Reduce app bundle size
   - Optimize animations (60fps)
   - Memory leak fixes
   - **Priority:** High
   - **Estimated Time:** 1 week

---

## 📚 **Documentation & Maintenance**

### ❌ **Not Started**

1. ❌ **Documentation**
   - API documentation
   - Code comments (complex logic)
   - User guides (how to use features)
   - Developer setup guide
   - Deployment guide
   - Troubleshooting guide
   - **Priority:** Medium
   - **Estimated Time:** 3-5 days

---

## 🧪 **Testing Checklist**

### ⚠️ **Critical Testing Tasks**

#### **Payment & Notifications Testing**
- [ ] **Trial Payment Flow**
  - [ ] Book trial session as student
  - [ ] Approve trial as tutor → Verify student gets "Pay Now" notification
  - [ ] Pay for trial → Verify payment success notification (student + tutor)
  - [ ] Verify Meet link generated (for online sessions)
  - [ ] Verify session appears in "Upcoming Sessions"
  - [ ] Verify session reminders scheduled (24h, 1h, 15min before)

- [ ] **Regular Session Payment Flow**
  - [ ] Create booking request as student
  - [ ] Approve booking as tutor → Verify payment request created
  - [ ] Pay for session → Verify tutor earnings added
  - [ ] Verify session status changes to "scheduled"

- [ ] **Notification Delivery**
  - [ ] Verify in-app notifications appear immediately
  - [ ] Verify push notifications received (requires FCM token)
  - [ ] Verify emails sent for critical notifications
  - [ ] Verify notification preferences respected

#### **Core Feature Testing**
- [ ] **Notification Role Filtering** ⏳ **PRIORITY 1**
  - [ ] Login as student account
  - [ ] Open notification list screen
  - [ ] Verify "Complete Your Profile to Get Verified" notification is NOT visible
  - [ ] Verify no tutor-specific notifications appear
  - [ ] Check unread notification count (should exclude tutor notifications)
  - [ ] Login as tutor account
  - [ ] Verify tutor notifications ARE visible
  - [ ] Test real-time stream: Create a tutor notification, verify it filters correctly for students

- [ ] **Deep Linking**
  - [ ] Tap notifications and verify navigation works
  - [ ] Test booking detail navigation
  - [ ] Test trial session navigation
  - [ ] Test feedback screen navigation

- [ ] **Tutor Dashboard**
  - [ ] Verify approved badge shows
  - [ ] Verify rejection reason displays

- [ ] **Web Uploads**
  - [ ] Verify fix works in fresh browser session
  - [ ] Test file uploads
  - [ ] Test image uploads

- [ ] **Specialization Tabs**
  - [ ] Hot reload and verify UI
  - [ ] Test tab switching

- [ ] **Session Management**
  - [ ] Test session start/end flow (manual testing needed)
  - [ ] Test feedback submission (manual testing needed)
  - [ ] Test attendance tracking (manual testing needed)

- [ ] **Game Generation**
  - [ ] Test text input game generation
  - [ ] Test document upload game generation
  - [ ] Test image upload game generation
  - [ ] Verify error messages are user-friendly
  - [ ] Test API fallback (localhost → production)

---

## 🚀 **Recommended Development Order**

### **Week 1: Critical Testing & Bug Fixes**
1. Complete all critical testing tasks
2. Fix any bugs discovered during testing
3. Improve error messages and user feedback
4. Verify all payment flows work end-to-end

### **Week 2: High Priority Features**
1. Complete session management improvements
2. Implement tutor discovery enhancements
3. Add user experience improvements (loading states, empty states)
4. Performance optimization

### **Week 3: Medium Priority Features**
1. Complete social features (achievements, daily challenges)
2. Add game generation improvements
3. Implement notification enhancements
4. Security enhancements

### **Week 4: Polish & Documentation**
1. Design system consistency
2. Onboarding improvements
3. Documentation
4. Final testing and bug fixes

---

## 📝 **Notes for Team**

### **Known Issues**
1. **Image Upload:** API expects `fileUrl` parameter, not `imageUrl` - Fixed by sending `imageUrl` as `fileUrl`
2. **Error Messages:** Some error messages still show raw exceptions - Partially fixed, needs more work
3. **Push Notifications:** Requires Firebase service account key in production environment
4. **Payment Refunds:** Waiting for Fapshi API to support refunds
5. **Tutor Payouts:** Waiting for Fapshi disbursement API

### **Dependencies**
- **External APIs:**
  - Fapshi (payment processing, refunds, disbursements)
  - Firebase (push notifications)
  - Resend (email notifications)
  - OpenRouter (AI game generation)
  - Supabase (database, storage, auth)

### **Environment Setup**
- See `docs/START_HERE_NOW.md` for quick setup
- See `docs/IMPLEMENTATION_PLAN.md` for detailed plan
- See `docs/NEXT_BIG_TODOS.md` for feature priorities

---

## 🔄 **How to Update This Document**

1. When starting a task, mark it as "🔄 In Progress"
2. When completing a task, mark it as "✅ Completed"
3. When a task needs refinement, mark it as "⚠️ Needs Improvement" and add notes
4. Add your name/initials when working on a task
5. Update the "Last Updated" date at the top
6. Add notes in the "Notes for Team" section for blockers or important info

---

**Last Updated:** January 2025  
**Maintained By:** Development Team  
**Next Review:** Weekly

