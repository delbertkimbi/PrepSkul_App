# Migration Execution Order Guide

## ⚠️ IMPORTANT: Migration Order Matters

Migrations must be run in the correct order because some migrations depend on tables created by earlier migrations.

## 📋 Required Migration Order

### Step 1: Run Migration 022 FIRST ⚠️
**File**: `supabase/migrations/022_normal_sessions_tables.sql`

**What it creates**:
- ✅ `session_payments` table
- ✅ `session_feedback` table (REQUIRED for migration 032)
- ✅ `session_attendance` table
- ✅ `tutor_earnings` table
- ✅ All indexes and RLS policies

**Status**: ❌ **NOT RUN YET** (this is why migration 032 is failing)

### Step 2: Run Migration 032 (After 022)
**File**: `supabase/migrations/032_add_tutor_response_to_reviews.sql`

**What it does**:
- ✅ Adds `tutor_response` column to `session_feedback`
- ✅ Adds `tutor_response_submitted_at` column
- ✅ Creates index for performance

**Dependency**: Requires `session_feedback` table from migration 022

**Status**: ✅ **UPDATED** - Now safely checks if table exists first

### Step 3: Run Other Migrations (Optional)
- Migration 023: Location tracking (if needed)
- Migration 024: Hybrid support (if needed)

## 🚀 How to Run Migrations

### Option 1: Supabase Dashboard
1. Go to Supabase Dashboard → SQL Editor
2. **Run migration 022 first**:
   - Copy contents of `022_normal_sessions_tables.sql`
   - Paste and execute
   - Verify no errors
3. **Then run migration 032**:
   - Copy contents of `032_add_tutor_response_to_reviews.sql`
   - Paste and execute
   - Should complete successfully now

### Option 2: Supabase CLI
```bash
# Run migrations in order
supabase migration up 022
supabase migration up 032
```

## ✅ Verification

After running migrations, verify with:

```sql
-- Check if session_feedback table exists
SELECT table_name 
FROM information_schema.tables 
WHERE table_name = 'session_feedback';

-- Check if tutor_response column exists
SELECT column_name 
FROM information_schema.columns 
WHERE table_name = 'session_feedback' 
AND column_name = 'tutor_response';
```

## 🔧 What Was Fixed

Migration 032 has been updated to:
- ✅ Check if `session_feedback` table exists before modifying it
- ✅ Show helpful message if table doesn't exist
- ✅ Skip gracefully if dependencies aren't met
- ✅ Complete successfully if table exists

## 📝 Current Status

- ❌ Migration 022: **NOT RUN** (needs to be executed first)
- ✅ Migration 032: **READY** (will work after 022 is run)

## 🎯 Next Steps

1. **Run migration 022** in Supabase SQL Editor
2. **Verify** it completed successfully
3. **Run migration 032** (will now work correctly)
4. **Verify** tutor_response columns were added
