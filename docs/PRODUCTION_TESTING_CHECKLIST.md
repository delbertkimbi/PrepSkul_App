# Production Testing Checklist - PrepSkul

**Date:** January 2025  
**Purpose:** Comprehensive end-to-end testing checklist for production readiness

---

## Critical User Flows Testing

### 1. Authentication & Onboarding

#### Student Flow
- [ ] **Signup**
  - [ ] Phone number signup works
  - [ ] OTP verification works
  - [ ] Email signup works (if enabled)
  - [ ] Password reset flow works
  - [ ] Error handling for invalid credentials

- [ ] **Student Survey**
  - [ ] All survey steps complete without errors
  - [ ] University courses text input works
  - [ ] Budget step appears at end (before Review)
  - [ ] Review page shows card-based layout
  - [ ] Survey submission succeeds
  - [ ] Navigation to student dashboard works

#### Parent Flow
- [ ] **Signup & Survey**
  - [ ] Parent signup works
  - [ ] Multi-child support works
  - [ ] Survey completion works
  - [ ] Navigation to parent dashboard works

#### Tutor Flow
- [ ] **Signup & Onboarding**
  - [ ] Tutor signup works
  - [ ] All onboarding steps complete
  - [ ] Document uploads work (web + mobile)
  - [ ] Specialization tabs work correctly
  - [ ] Profile completion tracking works
  - [ ] Navigation to tutor dashboard works

---

### 2. Tutor Discovery & Booking

#### Discovery
- [ ] **Find Tutors Screen**
  - [ ] Tutor list loads correctly
  - [ ] Search functionality works
  - [ ] All filters work (subject, price, rating, verification)
  - [ ] Filter combinations work correctly
  - [ ] Empty state shows when no results
  - [ ] WhatsApp request button works

- [ ] **Tutor Detail Screen**
  - [ ] Tutor profile loads correctly
  - [ ] YouTube video player works
  - [ ] Play button visible and clickable
  - [ ] Video plays in-app (not browser)
  - [ ] All tutor information displays correctly
  - [ ] "Book Trial Lesson" button works

#### Booking Flow
- [ ] **Trial Session Booking**
  - [ ] Booking screen opens correctly
  - [ ] Duration selector works (25min, 50min)
  - [ ] Calendar displays correctly
  - [ ] Date selection works
  - [ ] Time slots display correctly
  - [ ] Time slot selection works
  - [ ] Price calculation is correct
  - [ ] "Request Session" button works
  - [ ] Booking request created in database
  - [ ] Success notification appears

- [ ] **Regular Session Booking**
  - [ ] Booking wizard (5 steps) works
  - [ ] Location selector works (Online/Onsite)
  - [ ] Address auto-fetch works for Onsite
  - [ ] Date/time selection works
  - [ ] Subject selection works
  - [ ] Price calculation is correct
  - [ ] Booking request created
  - [ ] Tutor receives notification

---

### 3. Payment System

#### Trial Session Payment
- [ ] **Payment Flow**
  - [ ] Student books trial session
  - [ ] Tutor approves trial
  - [ ] Student receives "Pay Now" notification
  - [ ] Payment screen opens
  - [ ] Fapshi payment initiation works
  - [ ] Payment status polling works
  - [ ] Payment success notification (student + tutor)
  - [ ] Meet link generated (for online sessions)
  - [ ] Session appears in "Upcoming Sessions"

#### Regular Session Payment
- [ ] **Payment Request Flow**
  - [ ] Student creates booking request
  - [ ] Tutor approves booking
  - [ ] Payment request created
  - [ ] Student receives payment notification
  - [ ] Payment processing works
  - [ ] Tutor earnings calculated (85% of fee)
  - [ ] Earnings moved to pending balance
  - [ ] Session status updates to "scheduled"

#### Payment Webhooks
- [ ] **Webhook Handling**
  - [ ] Trial session payment webhook works
  - [ ] Payment request webhook works
  - [ ] Regular session payment webhook works
  - [ ] Payment status updates correctly
  - [ ] Error handling for failed payments

---

### 4. Session Management

#### Session Lifecycle
- [ ] **Session Flow**
  - [ ] Session appears in "Upcoming Sessions"
  - [ ] Session reminders scheduled (24h, 1h, 15min)
  - [ ] Reminder notifications delivered
  - [ ] "Join Session" button works (for online)
  - [ ] Agora video session works
  - [ ] Session can be started
  - [ ] Session can be ended
  - [ ] Session status updates correctly

#### Session Feedback
- [ ] **Feedback System**
  - [ ] Feedback screen accessible after session
  - [ ] Rating submission works (1-5 stars)
  - [ ] Review text submission works
  - [ ] Feedback saved to database
  - [ ] Tutor receives notification on new review
  - [ ] Rating calculation works (after 3+ reviews)
  - [ ] Rating displays on tutor profile
  - [ ] Feedback reminder delivered (24h after session)

---

### 5. Notifications

#### Notification System
- [ ] **Role Filtering** ⚠️ **CRITICAL**
  - [ ] Students don't see tutor notifications
  - [ ] Tutors don't see student notifications
  - [ ] Parents see appropriate notifications
  - [ ] Unread count excludes filtered notifications
  - [ ] Real-time stream filters correctly

- [ ] **Notification Delivery**
  - [ ] In-app notifications appear immediately
  - [ ] Push notifications received (when configured)
  - [ ] Email notifications sent for critical events
  - [ ] Notification preferences respected

- [ ] **Deep Linking**
  - [ ] Notification tap navigates to correct screen
  - [ ] Booking detail navigation works
  - [ ] Trial session detail navigation works
  - [ ] Profile navigation works
  - [ ] Parameters passed correctly

#### Notification Types
- [ ] Booking request notifications
- [ ] Payment notifications
- [ ] Session reminder notifications
- [ ] Tutor approval notifications
- [ ] Feedback reminder notifications

---

### 6. Tutor Features

#### Tutor Dashboard
- [ ] **Home Screen**
  - [ ] Profile completion status displays
  - [ ] Approval status displays correctly
  - [ ] Wallet balances display (active + pending)
  - [ ] Quick stats display
  - [ ] Action cards work (My Requests, My Sessions, Payment History)

- [ ] **Earnings & Payouts**
  - [ ] Earnings screen loads
  - [ ] Earnings history displays
  - [ ] Payout request form works
  - [ ] Payout validation works (minimum 5,000 XAF)
  - [ ] Payout history displays
  - [ ] Wallet balance updates correctly

#### Request Management
- [ ] **Booking Requests**
  - [ ] Requests list loads
  - [ ] Request details display
  - [ ] Approve button works
  - [ ] Reject button works (with reason)
  - [ ] Student receives notification on approval/rejection

---

### 7. Admin Dashboard

#### Admin Features
- [ ] **Login**
  - [ ] Admin login works
  - [ ] Password visibility toggle works
  - [ ] Error handling for invalid credentials

- [ ] **Dashboard**
  - [ ] Metrics display correctly
  - [ ] Real-time data updates
  - [ ] All navigation links work

- [ ] **Tutor Management**
  - [ ] Pending tutors list loads
  - [ ] Tutor details display
  - [ ] Approve button works
  - [ ] Reject button works (with reason required)
  - [ ] Admin notes save correctly
  - [ ] Tutor receives notification on status change

---

### 8. Offline Mode

#### Offline Functionality
- [ ] **Offline Detection**
  - [ ] App detects offline status
  - [ ] Offline indicator displays
  - [ ] Cached data loads correctly

- [ ] **Cached Data**
  - [ ] User info loads from cache
  - [ ] Tutor profile loads from cache
  - [ ] Previous data displays correctly

- [ ] **Offline Actions**
  - [ ] Offline dialog shows for internet-required actions
  - [ ] "View Earnings" shows offline dialog
  - [ ] Profile completion shows offline dialog
  - [ ] Navigation works offline (to cached screens)

- [ ] **Reconnection**
  - [ ] Data refreshes when connection restored
  - [ ] Cache updates with fresh data

---

### 9. Video Sessions (Agora)

#### Video Session Flow
- [ ] **Session Join**
  - [ ] Token generation works
  - [ ] Agora SDK loads correctly
  - [ ] Video/audio permissions requested
  - [ ] Session joins successfully
  - [ ] Video/audio streams work

- [ ] **Session Controls**
  - [ ] Mute/unmute works
  - [ ] Camera on/off works
  - [ ] End call button works
  - [ ] Session status updates on end

---

### 10. File Uploads

#### Upload Functionality
- [ ] **Web Uploads**
  - [ ] Image uploads work
  - [ ] Document uploads work
  - [ ] Video uploads work (if applicable)
  - [ ] Upload progress displays
  - [ ] Error handling works

- [ ] **Mobile Uploads**
  - [ ] Image picker works
  - [ ] Document picker works
  - [ ] Camera capture works
  - [ ] Upload succeeds

---

## Performance Testing

### Load Testing
- [ ] App loads quickly (< 3 seconds)
- [ ] Images load efficiently
- [ ] Lists scroll smoothly
- [ ] No memory leaks
- [ ] Battery usage acceptable

### Network Testing
- [ ] Works on slow connections
- [ ] Handles network errors gracefully
- [ ] Retry logic works
- [ ] Timeout handling works

---

## Security Testing

### Authentication
- [ ] Session tokens expire correctly
- [ ] Unauthorized access blocked
- [ ] Password requirements enforced
- [ ] OTP verification required

### Data Security
- [ ] RLS policies work correctly
- [ ] User data isolated correctly
- [ ] Payment data secured
- [ ] No sensitive data in logs

---

## Cross-Platform Testing

### Web (app.prepskul.com)
- [ ] All features work on web
- [ ] Responsive design works
- [ ] Browser compatibility (Chrome, Firefox, Safari)
- [ ] File uploads work

### Android
- [ ] App builds successfully
- [ ] All features work
- [ ] Push notifications work
- [ ] Permissions requested correctly

### iOS
- [ ] App builds successfully
- [ ] All features work
- [ ] Push notifications work (requires real device)
- [ ] Permissions requested correctly

---

## Bug Reporting Template

When reporting bugs, include:
1. **Steps to Reproduce**
2. **Expected Behavior**
3. **Actual Behavior**
4. **Screenshots/Logs**
5. **Device/Platform**
6. **App Version**

---

## Testing Priority

### P0 (Critical - Block Launch)
- Authentication flows
- Payment flows
- Session booking
- Notification role filtering

### P1 (High - Should Fix)
- Session feedback
- Tutor payouts
- Deep linking
- Offline mode

### P2 (Medium - Nice to Have)
- Performance optimization
- UI polish
- Error messages

---

**Status:** Ready for Testing  
**Last Updated:** January 2025




**Date:** January 2025  
**Purpose:** Comprehensive end-to-end testing checklist for production readiness

---

## Critical User Flows Testing

### 1. Authentication & Onboarding

#### Student Flow
- [ ] **Signup**
  - [ ] Phone number signup works
  - [ ] OTP verification works
  - [ ] Email signup works (if enabled)
  - [ ] Password reset flow works
  - [ ] Error handling for invalid credentials

- [ ] **Student Survey**
  - [ ] All survey steps complete without errors
  - [ ] University courses text input works
  - [ ] Budget step appears at end (before Review)
  - [ ] Review page shows card-based layout
  - [ ] Survey submission succeeds
  - [ ] Navigation to student dashboard works

#### Parent Flow
- [ ] **Signup & Survey**
  - [ ] Parent signup works
  - [ ] Multi-child support works
  - [ ] Survey completion works
  - [ ] Navigation to parent dashboard works

#### Tutor Flow
- [ ] **Signup & Onboarding**
  - [ ] Tutor signup works
  - [ ] All onboarding steps complete
  - [ ] Document uploads work (web + mobile)
  - [ ] Specialization tabs work correctly
  - [ ] Profile completion tracking works
  - [ ] Navigation to tutor dashboard works

---

### 2. Tutor Discovery & Booking

#### Discovery
- [ ] **Find Tutors Screen**
  - [ ] Tutor list loads correctly
  - [ ] Search functionality works
  - [ ] All filters work (subject, price, rating, verification)
  - [ ] Filter combinations work correctly
  - [ ] Empty state shows when no results
  - [ ] WhatsApp request button works

- [ ] **Tutor Detail Screen**
  - [ ] Tutor profile loads correctly
  - [ ] YouTube video player works
  - [ ] Play button visible and clickable
  - [ ] Video plays in-app (not browser)
  - [ ] All tutor information displays correctly
  - [ ] "Book Trial Lesson" button works

#### Booking Flow
- [ ] **Trial Session Booking**
  - [ ] Booking screen opens correctly
  - [ ] Duration selector works (25min, 50min)
  - [ ] Calendar displays correctly
  - [ ] Date selection works
  - [ ] Time slots display correctly
  - [ ] Time slot selection works
  - [ ] Price calculation is correct
  - [ ] "Request Session" button works
  - [ ] Booking request created in database
  - [ ] Success notification appears

- [ ] **Regular Session Booking**
  - [ ] Booking wizard (5 steps) works
  - [ ] Location selector works (Online/Onsite)
  - [ ] Address auto-fetch works for Onsite
  - [ ] Date/time selection works
  - [ ] Subject selection works
  - [ ] Price calculation is correct
  - [ ] Booking request created
  - [ ] Tutor receives notification

---

### 3. Payment System

#### Trial Session Payment
- [ ] **Payment Flow**
  - [ ] Student books trial session
  - [ ] Tutor approves trial
  - [ ] Student receives "Pay Now" notification
  - [ ] Payment screen opens
  - [ ] Fapshi payment initiation works
  - [ ] Payment status polling works
  - [ ] Payment success notification (student + tutor)
  - [ ] Meet link generated (for online sessions)
  - [ ] Session appears in "Upcoming Sessions"

#### Regular Session Payment
- [ ] **Payment Request Flow**
  - [ ] Student creates booking request
  - [ ] Tutor approves booking
  - [ ] Payment request created
  - [ ] Student receives payment notification
  - [ ] Payment processing works
  - [ ] Tutor earnings calculated (85% of fee)
  - [ ] Earnings moved to pending balance
  - [ ] Session status updates to "scheduled"

#### Payment Webhooks
- [ ] **Webhook Handling**
  - [ ] Trial session payment webhook works
  - [ ] Payment request webhook works
  - [ ] Regular session payment webhook works
  - [ ] Payment status updates correctly
  - [ ] Error handling for failed payments

---

### 4. Session Management

#### Session Lifecycle
- [ ] **Session Flow**
  - [ ] Session appears in "Upcoming Sessions"
  - [ ] Session reminders scheduled (24h, 1h, 15min)
  - [ ] Reminder notifications delivered
  - [ ] "Join Session" button works (for online)
  - [ ] Agora video session works
  - [ ] Session can be started
  - [ ] Session can be ended
  - [ ] Session status updates correctly

#### Session Feedback
- [ ] **Feedback System**
  - [ ] Feedback screen accessible after session
  - [ ] Rating submission works (1-5 stars)
  - [ ] Review text submission works
  - [ ] Feedback saved to database
  - [ ] Tutor receives notification on new review
  - [ ] Rating calculation works (after 3+ reviews)
  - [ ] Rating displays on tutor profile
  - [ ] Feedback reminder delivered (24h after session)

---

### 5. Notifications

#### Notification System
- [ ] **Role Filtering** ⚠️ **CRITICAL**
  - [ ] Students don't see tutor notifications
  - [ ] Tutors don't see student notifications
  - [ ] Parents see appropriate notifications
  - [ ] Unread count excludes filtered notifications
  - [ ] Real-time stream filters correctly

- [ ] **Notification Delivery**
  - [ ] In-app notifications appear immediately
  - [ ] Push notifications received (when configured)
  - [ ] Email notifications sent for critical events
  - [ ] Notification preferences respected

- [ ] **Deep Linking**
  - [ ] Notification tap navigates to correct screen
  - [ ] Booking detail navigation works
  - [ ] Trial session detail navigation works
  - [ ] Profile navigation works
  - [ ] Parameters passed correctly

#### Notification Types
- [ ] Booking request notifications
- [ ] Payment notifications
- [ ] Session reminder notifications
- [ ] Tutor approval notifications
- [ ] Feedback reminder notifications

---

### 6. Tutor Features

#### Tutor Dashboard
- [ ] **Home Screen**
  - [ ] Profile completion status displays
  - [ ] Approval status displays correctly
  - [ ] Wallet balances display (active + pending)
  - [ ] Quick stats display
  - [ ] Action cards work (My Requests, My Sessions, Payment History)

- [ ] **Earnings & Payouts**
  - [ ] Earnings screen loads
  - [ ] Earnings history displays
  - [ ] Payout request form works
  - [ ] Payout validation works (minimum 5,000 XAF)
  - [ ] Payout history displays
  - [ ] Wallet balance updates correctly

#### Request Management
- [ ] **Booking Requests**
  - [ ] Requests list loads
  - [ ] Request details display
  - [ ] Approve button works
  - [ ] Reject button works (with reason)
  - [ ] Student receives notification on approval/rejection

---

### 7. Admin Dashboard

#### Admin Features
- [ ] **Login**
  - [ ] Admin login works
  - [ ] Password visibility toggle works
  - [ ] Error handling for invalid credentials

- [ ] **Dashboard**
  - [ ] Metrics display correctly
  - [ ] Real-time data updates
  - [ ] All navigation links work

- [ ] **Tutor Management**
  - [ ] Pending tutors list loads
  - [ ] Tutor details display
  - [ ] Approve button works
  - [ ] Reject button works (with reason required)
  - [ ] Admin notes save correctly
  - [ ] Tutor receives notification on status change

---

### 8. Offline Mode

#### Offline Functionality
- [ ] **Offline Detection**
  - [ ] App detects offline status
  - [ ] Offline indicator displays
  - [ ] Cached data loads correctly

- [ ] **Cached Data**
  - [ ] User info loads from cache
  - [ ] Tutor profile loads from cache
  - [ ] Previous data displays correctly

- [ ] **Offline Actions**
  - [ ] Offline dialog shows for internet-required actions
  - [ ] "View Earnings" shows offline dialog
  - [ ] Profile completion shows offline dialog
  - [ ] Navigation works offline (to cached screens)

- [ ] **Reconnection**
  - [ ] Data refreshes when connection restored
  - [ ] Cache updates with fresh data

---

### 9. Video Sessions (Agora)

#### Video Session Flow
- [ ] **Session Join**
  - [ ] Token generation works
  - [ ] Agora SDK loads correctly
  - [ ] Video/audio permissions requested
  - [ ] Session joins successfully
  - [ ] Video/audio streams work

- [ ] **Session Controls**
  - [ ] Mute/unmute works
  - [ ] Camera on/off works
  - [ ] End call button works
  - [ ] Session status updates on end

---

### 10. File Uploads

#### Upload Functionality
- [ ] **Web Uploads**
  - [ ] Image uploads work
  - [ ] Document uploads work
  - [ ] Video uploads work (if applicable)
  - [ ] Upload progress displays
  - [ ] Error handling works

- [ ] **Mobile Uploads**
  - [ ] Image picker works
  - [ ] Document picker works
  - [ ] Camera capture works
  - [ ] Upload succeeds

---

## Performance Testing

### Load Testing
- [ ] App loads quickly (< 3 seconds)
- [ ] Images load efficiently
- [ ] Lists scroll smoothly
- [ ] No memory leaks
- [ ] Battery usage acceptable

### Network Testing
- [ ] Works on slow connections
- [ ] Handles network errors gracefully
- [ ] Retry logic works
- [ ] Timeout handling works

---

## Security Testing

### Authentication
- [ ] Session tokens expire correctly
- [ ] Unauthorized access blocked
- [ ] Password requirements enforced
- [ ] OTP verification required

### Data Security
- [ ] RLS policies work correctly
- [ ] User data isolated correctly
- [ ] Payment data secured
- [ ] No sensitive data in logs

---

## Cross-Platform Testing

### Web (app.prepskul.com)
- [ ] All features work on web
- [ ] Responsive design works
- [ ] Browser compatibility (Chrome, Firefox, Safari)
- [ ] File uploads work

### Android
- [ ] App builds successfully
- [ ] All features work
- [ ] Push notifications work
- [ ] Permissions requested correctly

### iOS
- [ ] App builds successfully
- [ ] All features work
- [ ] Push notifications work (requires real device)
- [ ] Permissions requested correctly

---

## Bug Reporting Template

When reporting bugs, include:
1. **Steps to Reproduce**
2. **Expected Behavior**
3. **Actual Behavior**
4. **Screenshots/Logs**
5. **Device/Platform**
6. **App Version**

---

## Testing Priority

### P0 (Critical - Block Launch)
- Authentication flows
- Payment flows
- Session booking
- Notification role filtering

### P1 (High - Should Fix)
- Session feedback
- Tutor payouts
- Deep linking
- Offline mode

### P2 (Medium - Nice to Have)
- Performance optimization
- UI polish
- Error messages

---

**Status:** Ready for Testing  
**Last Updated:** January 2025


