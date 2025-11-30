# Migration Status Report

## ✅ Required Migrations (In Order)

### Core Migrations (002-031)
These should be run in numerical order:
- 002_booking_system.sql
- 003_booking_system.sql
- 004_tutor_requests.sql
- 005_fix_parent_profiles.sql
- 006_complete_parent_profiles_setup.sql
- 007_complete_learner_profiles_setup.sql
- 008_booking_requests_table.sql (use this one, ignore duplicates)
- 009_add_tutor_onboarding_columns.sql (use this one, ignore duplicates)
- 010_add_location_description_to_recurring_sessions.sql (use this one, ignore duplicates)
- 011-021: Continue in order
- **022_normal_sessions_tables.sql** ⚠️ **CRITICAL - Creates session_feedback table**
- 023_consolidate_redundant_fields.sql
- 024_payment_requests_table.sql (use this one, ignore add_hybrid_location_support)
- 025_fix_learner_profiles_learning_styles.sql (use this one, ignore add_tutor_response)
- 026_pricing_controls.sql (use this one, ignore add_tutor_response)
- 027-029: Continue in order
- 031_update_trial_sessions_policies.sql

### New Feature Migrations (Run After 031)
- **023_session_location_tracking.sql** (should be renamed to 030)
- **024_add_hybrid_location_support.sql** (should be renamed to 033)
- **032_add_tutor_response_to_reviews.sql** ✅ **USE THIS ONE** (requires 022)

### Date-Based Migration
- 20240101000000_create_individual_sessions.sql (may be duplicate of 002, check before running)

## ⚠️ Duplicate Migrations (DO NOT RUN)

### Migration 008 Duplicates:
- ❌ 008_ensure_tutor_profiles_complete.sql
- ❌ 008_ensure_tutor_profiles_complete_FIXED.sql

### Migration 009 Duplicates:
- ❌ 009_notifications_table.sql

### Migration 010 Duplicates:
- ❌ 010_add_rating_pricing_admin.sql

### Migration 024 Duplicates:
- ❌ 024_add_hybrid_location_support.sql (conflicts with 024_payment_requests_table.sql)

### Migration 025 Duplicates:
- ❌ 025_add_tutor_response_to_reviews.sql (use 032 instead)

### Migration 026 Duplicates:
- ❌ 026_add_tutor_response_to_reviews.sql (use 032 instead)

## 📋 SQL Files Outside Migrations Folder

The `All mds/` folder contains:
- Development/testing scripts
- One-off fixes
- **NOT part of migration sequence**
- Can be run manually if needed, but not required for migrations

## ✅ Migration Execution Order

1. Run migrations 002-031 in order
2. **Run migration 022** (creates session_feedback table)
3. Run migration 023_session_location_tracking.sql (rename to 030 first)
4. Run migration 024_add_hybrid_location_support.sql (rename to 033 first)
5. **Run migration 032** (adds tutor_response - requires 022)

## 🔧 Recommended Actions

1. **Rename conflicting migrations:**
   - `023_session_location_tracking.sql` → `030_session_location_tracking.sql`
   - `024_add_hybrid_location_support.sql` → `033_add_hybrid_location_support.sql`

2. **Delete duplicate migrations:**
   - Remove old tutor_response migrations (025, 026 versions)
   - Remove duplicate 008, 009, 010 files

3. **Verify before running:**
   - Check if `20240101000000_create_individual_sessions.sql` duplicates 002
   - Ensure migration 022 has been run before 032
