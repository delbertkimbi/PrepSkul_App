# Trial vs Recurring Booking - Multi-Learner Support

## Current Implementation Status

### ✅ Trial Sessions (COMPLETE)
- **ONE trial session** regardless of how many children selected
- **Same price** - trial fee doesn't change based on learner count
- Parent selects learners for **informational purposes only**
- Stores learner names in `learner_labels` JSONB array (migration 052)
- Students (non-parents) are **NOT affected** - they see normal 3-step flow

### ⚠️ Normal/Recurring Bookings (NOT YET IMPLEMENTED)
- Currently: **One booking request = one learner** (the requester)
- Multi-learner support for recurring bookings is **not yet implemented**
- Infrastructure exists (`parent_learners` table) but not wired to recurring booking flow
- When implemented: Will use `multi_learner_discount_rules` (migration 051) for discounts

## Student (Non-Parent) Flow - VERIFIED UNCHANGED

### Trial Booking
- Students see **3 steps**: Subject → Date/Time → Goals
- No "Who is this for?" step (only shows for `user_type == 'parent'`)
- Creates single trial with `learner_id = student's ID`
- No `learner_labels` or `learner_label` fields set

### Recurring Booking
- Students use `book_tutor_flow_screen.dart` (unchanged)
- Creates `booking_request` with `student_id = student's ID`
- No multi-learner selection (not applicable for students)

## Parent Flow - Current State

### Trial Booking
- Parents see **4 steps**: Who is this for? → Subject → Date/Time → Goals
- Can select one or multiple children from "My children"
- Creates **ONE trial** with:
  - `learner_id = parent's ID` (parent attends)
  - `learner_labels = ["Emma", "James"]` if multiple selected
  - `learner_label = "Emma"` if single selected
- **Same price** regardless of selection

### Recurring Booking
- Parents use `book_tutor_flow_screen.dart` (same as students currently)
- Creates `booking_request` with `student_id = parent's ID`
- **TODO**: Add "Who is this for?" step and multi-learner support for recurring bookings
- **TODO**: Apply `multi_learner_discount_rules` when multiple children selected

## Verification Checklist

- [x] Students don't see "Who is this for?" step
- [x] Students get normal 3-step trial flow
- [x] Students' recurring bookings unchanged
- [x] Parent trial booking creates ONE trial (not multiple)
- [x] Parent trial booking uses same price regardless of learners
- [ ] Parent recurring booking multi-learner support (future work)
- [ ] Multi-learner discounts for recurring bookings (future work)
