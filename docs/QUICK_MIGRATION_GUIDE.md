# Quick Migration Execution Guide

## Current Status
❌ Migration 022 has NOT been run yet (session_feedback table doesn't exist)

## Required Migrations (In Order)

### Step 1: Run Migration 022
**File**: `supabase/migrations/022_normal_sessions_tables.sql`

**What it does**:
- Creates `session_payments` table
- Creates `session_feedback` table (base structure)
- Creates `session_attendance` table
- Creates `tutor_earnings` table
- Sets up indexes and RLS policies

**How to run**:
1. Open Supabase Dashboard → SQL Editor
2. Copy entire contents of `022_normal_sessions_tables.sql`
3. Paste and execute
4. Verify no errors

### Step 2: Run Migration 032
**File**: `supabase/migrations/032_add_tutor_response_to_reviews.sql`

**What it does**:
- Adds `tutor_response` column to `session_feedback`
- Adds `tutor_response_submitted_at` column
- Creates index for performance

**How to run**:
1. After migration 022 completes successfully
2. Copy entire contents of `032_add_tutor_response_to_reviews.sql`
3. Paste and execute
4. Verify no errors

### Step 3: Verify
Run the verification script again:
- `VERIFY_022_025_MIGRATIONS.sql` (now updated to handle missing tables)

## Important Notes

⚠️ **Migration 022 MUST be run first** - It creates the base table structure
⚠️ **Migration 032 requires 022** - It adds columns to the existing table
✅ **Both migrations are safe to run** - They use `IF NOT EXISTS` and `IF EXISTS` checks

## Troubleshooting

If you get errors:
1. Check that `individual_sessions` table exists (required dependency)
2. Check that `recurring_sessions` table exists (required dependency)
3. Verify you have admin permissions in Supabase
4. Check Supabase logs for detailed error messages
