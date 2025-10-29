# Fix Sessions Error - Database Setup

## Error You're Seeing:
```
Error loading sessions: Could not find the table 'public.lessons' in the schema cache
```

## What's Wrong:
The `lessons` table hasn't been created in your Supabase database yet. The admin dashboard is trying to fetch session data, but the table doesn't exist.

---

## How to Fix (2 Minutes):

### Step 1: Open Supabase Dashboard
1. Go to https://supabase.com
2. Open your PrepSkul project
3. Click "SQL Editor" in the left sidebar

### Step 2: Run the SQL
1. Copy the SQL from `CREATE_LESSONS_TABLE.sql`
2. Paste it into the SQL Editor
3. Click "Run" button

The SQL will create:
- `lessons` table with all columns
- Row Level Security (RLS)
- Updated_at trigger

### Step 3: Refresh Admin Dashboard
1. Go back to `http://localhost:3000/admin/sessions`
2. Refresh the page
3. Error should be gone!

---

## What You'll See After Fix:

### If No Sessions Yet:
- "No sessions yet" message
- Stats showing 0 for everything
- This is normal - sessions will appear when tutors/students book lessons

### To Test With Sample Data:
Uncomment the last section of `CREATE_LESSONS_TABLE.sql` to insert a test session.

---

## Alternative: Full Schema Setup

If you haven't run your main schema yet, run the entire `supabase/schema.sql` file instead. This will create ALL tables at once:
- profiles
- learner_profiles
- tutor_profiles
- lessons
- payments
- feedback
- progress_reports
- notifications

---

## Quick Check:
After running the SQL, verify the table exists:
```sql
SELECT * FROM public.lessons LIMIT 1;
```

Should return empty result (no error).

---

## The `lessons` table tracks:
- Session ID
- Tutor & Learner IDs
- Subject & Description
- Start & End times
- Status (scheduled/completed/cancelled)
- Meeting link (Zoom, Google Meet, etc.)
- Created & Updated timestamps

Once this table exists, all session pages will work perfectly!

