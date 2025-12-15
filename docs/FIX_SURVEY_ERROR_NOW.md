# Fix Survey Error - Quick Guide

## The Error
```
PostgrestException: column learner_profiles.user_id does not exist
```

## The Problem
The `learner_profiles` and `parent_profiles` tables don't exist in your Supabase database yet.

## The Solution (2 minutes)

### Step 1: Open Supabase
1. Go to https://supabase.com/dashboard
2. Select your PrepSkul project
3. Click "SQL Editor" in the left sidebar

### Step 2: Run the SQL
1. Click "New Query"
2. Copy ALL the content from `FIX_SURVEY_TABLES.sql`
3. Paste it in the SQL editor
4. Click "Run" (or press Cmd/Ctrl + Enter)

### Step 3: Verify Success
You should see:
```
✅ Survey tables created successfully!
```

### Step 4: Test the App
1. Hot reload your Flutter app (press `r` in terminal)
2. Complete a student or parent survey
3. Error should be gone! 🎉

## What This Creates

### Tables Created:
1. **`learner_profiles`** - Stores student survey data
2. **`parent_profiles`** - Stores parent survey data

### Features Added:
- ✅ Proper user_id column
- ✅ All survey fields (subjects, location, preferences, etc.)
- ✅ Row Level Security (users can only see their own data)
- ✅ Admin access (admins can see all profiles)
- ✅ Auto-update timestamps
- ✅ One profile per user (UNIQUE constraint)

## File Location
📄 `/Users/user/Desktop/PrepSkul/prepskul_app/All mds/FIX_SURVEY_TABLES.sql`

## Quick Copy-Paste
Just open `FIX_SURVEY_TABLES.sql` and copy everything → paste in Supabase SQL Editor → Run!

