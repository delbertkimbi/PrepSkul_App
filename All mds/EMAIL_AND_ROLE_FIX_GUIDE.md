# Email and Role Fix Guide

## Problem Summary

1. **Email Auto-Assignment Bug**: `brianleke9@gmail.com` is being automatically assigned to new students
2. **Role Confusion**: Confusion between `learner_id`, `requester_id`, and `parent_id` in trial sessions
3. **Display Issues**: Tutors see generic "Student" with "S" placeholder instead of actual names and profile images

## Solution Steps

### Step 1: Run Diagnostic Script

Run `DIAGNOSE_EMAIL_AND_ROLE_ISSUES.sql` in Supabase SQL Editor to identify:
- Duplicate emails
- Users with `brianleke9@gmail.com`
- Missing emails
- Incorrect role assignments
- Missing avatar URLs

### Step 2: Run Fix Script

Run `FIX_EMAIL_AND_ROLE_ISSUES.sql` in Supabase SQL Editor to:
- Fix duplicate emails (keep oldest, update others with correct email from `auth.users`)
- Fix `brianleke9@gmail.com` assignments
- Sync NULL/empty emails from `auth.users`
- Fix incorrect `user_type` (parents marked as learners)
- Ensure data integrity

### Step 3: Code Fixes Applied

#### 1. `tutor_sessions_screen.dart`
- **Fixed**: Now fetches **requester** profile (who made the booking) instead of just learner
- **Priority**: Requester → Learner (fallback)
- **Display**: Shows actual requester name and avatar, not generic "Student"

#### 2. `tutor_request_detail_screen.dart`
- **Already Fixed**: Displays requester name and avatar correctly
- **Shows**: Parent name if parent booked, Student name if student booked
- **Avatar**: Uses `CachedNetworkImage` to load profile images

#### 3. `booking_service.dart`
- **Already Fixed**: Prioritizes requester profile for display
- **Logic**: Requester → Learner → Parent (fallback chain)

## Understanding the Data Model

### Trial Sessions Fields:
- `requester_id`: **Who made the booking** (parent or student) - **This is what tutors should see**
- `learner_id`: **Who will attend the session** (the actual student)
- `parent_id`: **Parent associated with the session** (if parent booked)

### Display Logic:
- **Tutor Request Detail Screen**: Show `requester_id` profile (who made the booking)
- **Tutor Sessions Screen**: Show `requester_id` profile (who made the booking)
- **Student/Parent View**: Show `learner_id` profile (who will attend)

## Verification

After running the SQL scripts, verify:

```sql
-- Check for remaining brianleke9@gmail.com
SELECT COUNT(*) FROM profiles WHERE email = 'brianleke9@gmail.com';
-- Should be 0 or 1 (only if that's the actual user's email)

-- Check for duplicate emails
SELECT email, COUNT(*) FROM profiles 
WHERE email IS NOT NULL AND email != ''
GROUP BY email HAVING COUNT(*) > 1;
-- Should return no rows

-- Check for incorrect roles
SELECT p.id, p.email, p.user_type, p.full_name
FROM profiles p
WHERE p.user_type = 'learner'
  AND EXISTS (SELECT 1 FROM trial_sessions WHERE parent_id = p.id);
-- Should return no rows (parents should have user_type = 'parent')
```

## Expected Behavior After Fix

1. ✅ New students get their own email (not `brianleke9@gmail.com`)
2. ✅ Tutors see actual requester names (parent name if parent booked, student name if student booked)
3. ✅ Tutors see actual profile images (not just "S" or "P" initials)
4. ✅ Role badges show correctly ("Parent" or "Student" based on `user_type`)
5. ✅ No more duplicate emails in the database

## If Issues Persist

1. Check `auth.users` table - ensure emails are correct there
2. Check for database triggers that might auto-assign emails
3. Check for default values in `profiles.email` column
4. Review signup flow in `lib/features/auth/screens/email_signup_screen.dart`

