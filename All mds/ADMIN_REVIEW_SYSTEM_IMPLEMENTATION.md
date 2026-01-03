# Admin Review System for Pending Tutor Updates

## Overview
This document outlines the implementation of the admin review system for pending tutor profile updates. When an approved tutor edits their profile, changes are stored in `pending_changes` (JSONB) and NOT applied to the profile until admin approval.

## Database Changes

### SQL Script Required
Run `CREATE_PENDING_CHANGES_SYSTEM.sql` to add:
- `pending_changes` JSONB column to `tutor_profiles` table
- Index for faster queries

## How It Works

### 1. When Tutor Saves Changes
- For approved tutors: Changes are stored in `pending_changes` JSONB column
- Current profile fields remain unchanged
- `has_pending_update` is set to `TRUE`
- Notification is sent to tutor
- Tutor is redirected to dashboard

### 2. Admin Dashboard
- Shows tutors with `has_pending_update = TRUE` in pending section
- Displays "Pending Update" badge
- Admin can click "View Details" to see changes

### 3. Admin Review Screen (TO BE IMPLEMENTED)
- Shows current values vs pending changes
- Allows approve/reject individual fields or all
- On approval: Apply changes from `pending_changes` to profile fields
- Clear `pending_changes` and set `has_pending_update = FALSE`

## Implementation Status

### ✅ Completed (Flutter App)
1. Save logic stores changes in `pending_changes` for approved tutors
2. Pending update alert removed from tutor dashboard
3. Notification sent to tutor when changes are saved
4. Automatic redirect to dashboard after save
5. Duplicate "Student" session bug fixed

### ⏳ Pending (Web Admin Dashboard)
1. Create detail screen showing pending changes
2. Display before/after comparison
3. Implement approve/reject functionality
4. Apply approved changes to profile

## Next Steps for Web Implementation

### 1. Create Pending Changes Detail Page
**File:** `/app/admin/tutors/[id]/pending-update/page.tsx`

**Features:**
- Fetch tutor profile with `pending_changes`
- Display current values vs pending values side-by-side
- Show field names in human-readable format
- Highlight changed fields

### 2. Approve/Reject API Route
**File:** `/app/api/admin/tutors/[id]/pending-update/approve/route.ts`

**Logic:**
```typescript
// 1. Get pending_changes from tutor_profiles
// 2. Apply approved changes to profile fields
// 3. Clear pending_changes
// 4. Set has_pending_update = FALSE
// 5. Send notification to tutor
```

### 3. Reject API Route
**File:** `/app/api/admin/tutors/[id]/pending-update/reject/route.ts`

**Logic:**
```typescript
// 1. Clear pending_changes
// 2. Set has_pending_update = FALSE
// 3. Optionally set status to 'needs_improvement'
// 4. Send notification to tutor with rejection reason
```

## Example pending_changes Structure

```json
{
  "highest_education_level": "PhD",
  "bio": "Updated bio text with more details",
  "availability_schedule": {
    "Monday": ["09:00", "10:00", "14:00"],
    "Wednesday": ["09:00", "14:00"]
  },
  "subjects": ["Mathematics", "Physics", "Chemistry"]
}
```

## Field Mapping (Human-Readable Names)

- `highest_education_level` → "Highest Education Level"
- `bio` → "Bio"
- `availability_schedule` → "Availability Schedule"
- `subjects` → "Subjects"
- `years_of_experience` → "Years of Experience"
- `tutoring_availability` → "Tutoring Availability"
- `test_session_availability` → "Test Session Availability"
- `hourly_rate` → "Hourly Rate"
- `certificates_urls` → "Certificates"
- `social_media_links` → "Social Media Links"
- `video_link` → "Video Link"
- `languages` → "Languages"
- `specializations` → "Specializations"
- `education_background` → "Education Background"
- `professional_experience` → "Professional Experience"
- `teaching_approach` → "Teaching Approach"

## Testing Checklist

- [ ] Tutor edits profile → changes stored in `pending_changes`
- [ ] Current profile fields remain unchanged
- [ ] Admin sees "Pending Update" badge
- [ ] Admin can view pending changes detail screen
- [ ] Admin can approve all changes
- [ ] Admin can approve individual changes
- [ ] Admin can reject changes
- [ ] Approved changes are applied to profile
- [ ] Tutor receives notification when approved/rejected
- [ ] `has_pending_update` is cleared after approval/rejection

