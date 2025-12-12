# 🔧 Trial Session Booking - Troubleshooting Guide

## 🚨 **Issue: "Unable to send your trial request"**

### **Root Causes:**

#### **1. Migration Not Applied** ❌
The `trial_sessions` table is defined in `002_booking_system.sql`, but you may have only applied `003_booking_system.sql`.

**Solution**: Apply the missing migration.

#### **2. Foreign Key Reference Issue** ⚠️
```sql
tutor_id UUID NOT NULL REFERENCES auth.users(id)
```
The table references `auth.users(id)`, but we're passing `tutor['user_id']` or `tutor['id']` which might be from the `profiles` table instead.

#### **3. Data Format Issues** ⚠️
- `scheduled_time TIME NOT NULL` expects PostgreSQL TIME format
- `scheduled_date DATE NOT NULL` expects PostgreSQL DATE format

---

## ✅ **Quick Fix Steps:**

### **Step 1: Check if trial_sessions table exists**
Run in Supabase SQL Editor:
```sql
SELECT EXISTS (
  SELECT FROM information_schema.tables 
  WHERE table_schema = 'public' 
  AND table_name = 'trial_sessions'
);
```

If it returns `false`, you need to apply the migration.

### **Step 2: Apply Missing Migration**
If the table doesn't exist, run this in Supabase SQL Editor:
```sql
-- Copy the entire content from:
-- supabase/migrations/002_booking_system.sql
-- Starting from line 225 (CREATE TABLE IF NOT EXISTS trial_sessions)
-- Until the end of the trial_sessions section
```

### **Step 3: Fix Foreign Key References**
The issue is likely that `tutor_id` references `auth.users(id)` but should reference `profiles(id)`.

**Option A: Fix the migration** (Recommended)
```sql
-- Drop and recreate the table with correct references
DROP TABLE IF EXISTS trial_sessions CASCADE;

CREATE TABLE IF NOT EXISTS trial_sessions (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  tutor_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  learner_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  parent_id UUID REFERENCES public.profiles(id) ON DELETE SET NULL,
  requester_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  
  -- Session Details
  subject TEXT NOT NULL,
  scheduled_date DATE NOT NULL,
  scheduled_time TIME NOT NULL,
  duration_minutes INT NOT NULL CHECK (duration_minutes IN (30, 60)),
  location TEXT NOT NULL CHECK (location IN ('online', 'onsite')),
  
  -- Trial Details
  trial_goal TEXT,
  learner_challenges TEXT,
  learner_level TEXT,
  
  -- Status
  status TEXT DEFAULT 'pending' CHECK (status IN ('pending', 'approved', 'rejected', 'scheduled', 'completed', 'cancelled', 'no_show')),
  tutor_response_notes TEXT,
  rejection_reason TEXT,
  
  -- Payment
  trial_fee DECIMAL(10,2) NOT NULL CHECK (trial_fee >= 0),
  payment_status TEXT DEFAULT 'unpaid' CHECK (payment_status IN ('unpaid', 'paid', 'refunded')),
  payment_id UUID,
  
  -- Outcome
  converted_to_recurring BOOLEAN DEFAULT FALSE,
  recurring_session_id UUID,
  
  -- Timestamps
  created_at TIMESTAMPTZ DEFAULT NOW(),
  responded_at TIMESTAMPTZ,
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Add indexes
CREATE INDEX idx_trial_sessions_tutor_id ON trial_sessions(tutor_id);
CREATE INDEX idx_trial_sessions_learner_id ON trial_sessions(learner_id);
CREATE INDEX idx_trial_sessions_status ON trial_sessions(status);
CREATE INDEX idx_trial_sessions_scheduled_date ON trial_sessions(scheduled_date DESC);

-- Enable RLS
ALTER TABLE trial_sessions ENABLE ROW LEVEL SECURITY;

-- RLS Policies
CREATE POLICY "Users can view their own trial sessions"
  ON trial_sessions FOR SELECT
  USING (auth.uid() = requester_id OR auth.uid() = tutor_id);

CREATE POLICY "Users can create their own trial requests"
  ON trial_sessions FOR INSERT
  WITH CHECK (auth.uid() = requester_id);

CREATE POLICY "Tutors can respond to trial requests"
  ON trial_sessions FOR UPDATE
  USING (auth.uid() = tutor_id AND status = 'pending');

CREATE POLICY "Students can cancel their trial requests"
  ON trial_sessions FOR UPDATE
  USING (auth.uid() = requester_id AND status = 'pending')
  WITH CHECK (status = 'cancelled');
```

---

## 🔍 **Debugging Steps:**

### **1. Check the actual error**
Modify the code to log the actual error:

```dart
} catch (e) {
  print('TRIAL BOOKING ERROR: $e'); // ADD THIS
  throw Exception('Failed to create trial request: $e');
}
```

### **2. Check if user is authenticated**
```dart
final userId = _supabase.auth.currentUser?.id;
print('User ID: $userId'); // ADD THIS
if (userId == null) throw Exception('User not authenticated');
```

### **3. Check the tutor ID being passed**
In `book_trial_session_screen.dart`:
```dart
await TrialSessionService.createTrialRequest(
  tutorId: widget.tutor['user_id'] ?? widget.tutor['id'],
  // ADD THIS LOG:
  // print('Tutor ID: ${widget.tutor['user_id'] ?? widget.tutor['id']}');
  ...
);
```

---

## 🎯 **Most Likely Issue:**

The `trial_sessions` table probably **doesn't exist** in your database because:
1. You only applied `003_booking_system.sql`
2. The `trial_sessions` table is in `002_booking_system.sql`
3. Supabase doesn't have this table, so the insert fails

**Solution**: Apply the SQL above to create the table with correct references.

---

## 📝 **After Applying Fix:**

1. ✅ Run the SQL to create `trial_sessions` table
2. ✅ Verify table exists: `SELECT * FROM trial_sessions;`
3. ✅ Test trial booking again
4. ✅ Check for any error logs
5. ✅ Confirm request appears in database

---

## 🚀 **Quick Test:**

After applying the fix, try booking again. If it still fails:
1. Check browser console / Flutter logs for exact error
2. Check Supabase logs (Dashboard → Logs)
3. Verify RLS policies allow inserts
4. Check if all required fields are being sent

---

**Most Common Issue**: Table doesn't exist. Apply the SQL above! 🎯

