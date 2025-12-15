# ✅ Database Migration Checklist - Feedback System

## Pre-Migration Checklist

- [ ] Backup your database
- [ ] Verify you have admin access to Supabase
- [ ] Check current database schema
- [ ] Ensure `individual_sessions` table exists
- [ ] Ensure `recurring_sessions` table exists

## Migration Execution Checklist

### Step 1: Run Migration 022
- [ ] Open Supabase Dashboard → SQL Editor
- [ ] Copy contents of `supabase/migrations/022_normal_sessions_tables.sql`
- [ ] Execute the migration
- [ ] Verify no errors occurred
- [ ] Check that `session_feedback` table was created
- [ ] Verify `session_payments` table was created
- [ ] Verify `session_attendance` table was created
- [ ] Verify `tutor_earnings` table was created

### Step 2: Run Migration 025
- [ ] Copy contents of `supabase/migrations/025_add_tutor_response_to_reviews.sql`
- [ ] Execute the migration
- [ ] Verify no errors occurred
- [ ] Check that `tutor_response` column was added
- [ ] Check that `tutor_response_submitted_at` column was added
- [ ] Verify index was created

### Step 3: Run Migration 023 (if not already done)
- [ ] Copy contents of `supabase/migrations/023_session_location_tracking.sql`
- [ ] Execute the migration
- [ ] Verify `session_location_tracking` table was created

### Step 4: Run Migration 024 (if not already done)
- [ ] Copy contents of `supabase/migrations/024_add_hybrid_location_support.sql`
- [ ] Execute the migration
- [ ] Verify location constraints were updated

## Post-Migration Verification

- [ ] Run verification script: `VERIFY_022_025_MIGRATIONS.sql`
- [ ] Check all tables exist
- [ ] Check all columns exist
- [ ] Check all indexes exist
- [ ] Check RLS policies are enabled
- [ ] Test creating a feedback record
- [ ] Test reading feedback records
- [ ] Test updating feedback records

## Testing Checklist

### Test Student Feedback
- [ ] Student can submit rating
- [ ] Student can submit review text
- [ ] Student can submit "what went well"
- [ ] Student can submit "what could improve"
- [ ] Student can mark "would recommend"
- [ ] Feedback appears in database

### Test Tutor Feedback
- [ ] Tutor can submit session notes
- [ ] Tutor can submit progress notes
- [ ] Tutor can submit homework assigned
- [ ] Tutor can submit next focus areas
- [ ] Tutor can rate student engagement
- [ ] Feedback appears in database

### Test Tutor Response
- [ ] Tutor can respond to student review
- [ ] Response is stored in `tutor_response` field
- [ ] Response timestamp is recorded
- [ ] Response appears on tutor profile
- [ ] Student receives notification

### Test Analytics
- [ ] Analytics service can fetch reviews
- [ ] Rating trends are calculated
- [ ] Common themes are extracted
- [ ] Sentiment analysis works
- [ ] Response rate is calculated

## Rollback Plan (if needed)

If migration fails:
1. Check error message
2. Review which step failed
3. Fix the issue in migration file
4. Re-run from the failed step
5. If critical failure, restore from backup

## Support

If you encounter issues:
1. Check Supabase logs
2. Review migration SQL for syntax errors
3. Verify table dependencies exist
4. Check RLS policies
5. Review foreign key constraints
