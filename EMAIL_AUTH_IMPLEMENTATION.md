# Email Authentication Implementation

## Overview
Email authentication has been added as an alternative to phone OTP authentication. This allows users to sign up and log in using email/password, which is essential for development and testing before phone OTP credits are purchased.

## Changes Made

### 1. Auth Method Selection Screen
- **File**: `lib/features/auth/screens/auth_method_selection_screen.dart`
- **Purpose**: After onboarding, users choose between email or phone authentication
- **Flow**: 
  - Splash → Onboarding → **Auth Method Selection** → Email/Phone Signup → Survey → Dashboard

### 2. Email Signup Screen
- **File**: `lib/features/auth/screens/email_signup_screen.dart`
- **Features**:
  - Name, email, password fields
  - Password confirmation with show/hide toggle
  - Role selection (Student/Parent/Tutor)
  - Email validation
  - Password strength (minimum 6 characters)

### 3. Email Login Screen
- **File**: `lib/features/auth/screens/email_login_screen.dart`
- **Features**:
  - Email and password fields
  - Password show/hide toggle
  - "Forgot Password" link (placeholder for now)
  - Switch to phone login option

### 4. Tutor Onboarding Updates
- **File**: `lib/features/tutor/screens/tutor_onboarding_screen.dart`
- **Changes**:
  - Dynamically shows **phone** field if user chose email auth
  - Dynamically shows **email** field if user chose phone auth
  - Saves appropriate contact info to profiles table

### 5. Survey Repository Updates
- **File**: `lib/core/services/survey_repository.dart`
- **Changes**:
  - `saveTutorSurvey` now accepts `contactInfo` (email or phone)
  - Automatically detects if contact info is email or phone
  - Updates `profiles.email` or `profiles.phone_number` accordingly

### 6. Navigation Updates
- **File**: `lib/main.dart`
- **Changes**:
  - Added routes: `/auth-method-selection`, `/email-signup`, `/email-login`
  - Updated splash screen to navigate to auth method selection
  - Updated onboarding completion to navigate to auth method selection

## User Flow

### New User Flow (Email Auth)
1. Splash Screen
2. Onboarding Slides
3. **Auth Method Selection** → Choose "Sign up with email"
4. Email Signup → Enter name, email, password, select role
5. Profile Setup/Survey → Complete onboarding
6. Dashboard

### New User Flow (Phone Auth)
1. Splash Screen
2. Onboarding Slides
3. **Auth Method Selection** → Choose "Sign up with phone"
4. Phone Signup → Enter name, phone, select role
5. OTP Verification → Enter code
6. Profile Setup/Survey → Complete onboarding
7. Dashboard

### Returning User Flow
- Users who chose email auth → Email Login Screen
- Users who chose phone auth → Phone Login Screen
- Both options available on auth method selection screen

## Supabase Configuration

### Email Auth Setup
Email authentication in Supabase is enabled by default. Ensure the following in Supabase Dashboard:

1. **Authentication → Providers → Email**
   - ✅ Email provider should be enabled
   - ✅ "Confirm email" can be disabled for development (enabled by default)
   - ✅ Password reset enabled

2. **Authentication → Email Templates**
   - Customize welcome emails, password reset, etc. (optional)

3. **Database → profiles table**
   - `email` column exists and can be nullable
   - `phone_number` column exists and can be nullable
   - Both are stored separately based on auth method

### Testing Locally
1. Email auth works immediately in development
2. No API keys or credits required
3. Users are created in `auth.users` table
4. Profiles are created in `profiles` table

### Production Considerations
- Email confirmations can be enabled for production
- Password reset emails require SMTP configuration in Supabase
- Consider enabling email verification for production users

## Database Schema

The `profiles` table supports both:
- `email` - Used when user chooses phone auth (email collected in tutor onboarding)
- `phone_number` - Used when user chooses email auth (phone collected in tutor onboarding)

Both fields are nullable and populated based on the user's auth method choice.

## Notes

1. **Auth Method Preference**: Stored in `SharedPreferences` as `auth_method` ('email' or 'phone')
2. **Tutor Onboarding**: Automatically swaps contact field based on auth method
3. **Profile Updates**: Both email and phone can coexist in profiles table
4. **Session Management**: Works with existing `AuthService` - phone field is empty string for email auth users

## Next Steps

- [ ] Implement "Forgot Password" flow for email users
- [ ] Add email verification (optional, for production)
- [ ] Configure SMTP for password reset emails in Supabase
- [ ] Test end-to-end flow for both auth methods
- [ ] Test tutor onboarding with both auth methods

