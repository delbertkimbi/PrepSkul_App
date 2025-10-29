# 🧪 Admin Dashboard Testing Guide

## How to Test Without Real Users

You have two options:

### Option 1: Quick Test with SQL (Recommended)

1. **Run the test data script**
   - Open Supabase Dashboard → SQL Editor
   - Open `/All mds/ADMIN_TEST_DATA.sql`
   - Copy all content
   - Paste and click **RUN**
   - Wait for "Success" message

2. **What you'll get:**
   - ✅ 25 test users (tutors, learners, parents)
   - ✅ 2 pending tutor applications
   - ✅ 1 active session (happening now)
   - ✅ 1 upcoming session today
   - ✅ 1 completed session with payment
   - ✅ Random activity data for peak hours chart

3. **Refresh your admin dashboard**
   - Go to: http://localhost:3000/admin
   - You should now see:
     - Total Users: ~25
     - Active Users: 3-5 online now
     - Pending Tutors: 2
     - Total Revenue: 50,000 XAF
     - Active Sessions: 1

### Option 2: Manual Testing via Supabase UI

1. **Add users manually**
   - Go to Supabase → Authentication → Users
   - Click "Add User" (email auth)
   - Create test users with different types

2. **Update profiles**
   - Go to Table Editor → profiles
   - Set `user_type` to 'tutor', 'learner', or 'parent'
   - Set `last_seen` to NOW() for "online" users

3. **Create tutor profiles**
   - Go to Table Editor → tutor_profiles
   - Add new rows with `status = 'pending'`

## What Each Page Should Show

### Main Dashboard (`/admin`)

After adding test data:

```
Total Users: 25
├─ Tutors: ~8
├─ Learners: ~12
└─ Parents: ~5

Active Users: 3-5 online now
└─ 15-20 active today

Pending Tutors: 2
└─ Review applications →

Total Revenue: 50,000 XAF
└─ This month: 50,000 XAF

Active Sessions: 1
└─ 1 scheduled today
```

### Active Users Page (`/admin/users/active`)

```
Online Now: 3-5 users
Active Today: 15-20 users
Active This Week: ~25 users
In Sessions: 2 users (1 tutor + 1 learner)

By User Type:
├─ Tutors Online: 2
├─ Learners Online: 2
└─ Parents Online: 1

Peak Activity: Shows hourly chart
Currently Online: List of 3-5 users
```

### Pending Tutors Page (`/admin/tutors/pending`)

```
2 Pending Applications

1. John Kamga
   - Mathematics, Physics
   - Douala, Akwa
   - 5 years experience
   - Applied 2 days ago
   [Approve] [Reject] [View Details]

2. Marie Ngono
   - English, French
   - Yaounde, Bastos
   - 3 years experience
   - Applied 1 day ago
   [Approve] [Reject] [View Details]
```

### Sessions Page (`/admin/sessions`)

```
All Sessions (3)

1. Mathematics - Algebra basics
   Tutor: John Kamga
   Learner: Paul Etundi
   Status: 🟢 In Progress
   Time: [Started 30 min ago]

2. English - Essay writing
   Tutor: Marie Ngono
   Learner: Sarah Mballa
   Status: ⏰ Upcoming
   Time: [In 2 hours]

3. Physics - Newton laws
   Tutor: John Kamga
   Learner: Paul Etundi
   Status: ✅ Completed
   Time: [2 days ago]
```

### Active Sessions Page (`/admin/sessions/active`)

```
Active Now (1)

Mathematics - Algebra basics
Tutor: John Kamga → Learner: Paul Etundi
Started: 30 minutes ago
Ends in: 30 minutes
Progress: [████████░░] 50%

Upcoming Today (1)

English - Essay writing
Tutor: Marie Ngono → Learner: Sarah Mballa
Starts in: 2 hours
Duration: 1 hour
```

### Revenue Page (`/admin/revenue`)

```
Total Revenue: 50,000 XAF
This Month: 50,000 XAF
Pending Revenue: 0 XAF

Top Earning Tutors:
1. John Kamga - 50,000 XAF

Recent Transactions:
1. 50,000 XAF - MTN Mobile Money
   Physics lesson - Completed
   2 days ago
```

## Testing Checklist

Use this to verify everything works:

### ✅ Database Setup
- [ ] Run `ADD_ACTIVE_USER_TRACKING.sql`
- [ ] Run `ADMIN_TEST_DATA.sql`
- [ ] Verify test data with verification queries

### ✅ Dashboard Page
- [ ] Total Users shows ~25
- [ ] Active Users shows 3-5 online
- [ ] Pending Tutors shows 2
- [ ] Revenue shows 50,000 XAF
- [ ] All cards display correctly
- [ ] No loading errors

### ✅ Active Users Page
- [ ] Summary stats load
- [ ] User type breakdown shows
- [ ] Peak activity chart displays
- [ ] Online users list shows 3-5 people
- [ ] Time ago updates correctly

### ✅ Pending Tutors Page
- [ ] Shows 2 pending tutors
- [ ] Profile cards display correctly
- [ ] Approve/Reject buttons present
- [ ] View Details link works

### ✅ Tutor Detail Page
- [ ] Click "View Details" on a tutor
- [ ] Full profile information shows
- [ ] Contact buttons work (Call, Email, WhatsApp)
- [ ] Admin notes field exists
- [ ] Approve/Reject workflow works

### ✅ Sessions Page
- [ ] Shows 3 sessions
- [ ] Status colors correct (green, yellow, blue)
- [ ] Tutor and learner names display
- [ ] Filters work (if implemented)

### ✅ Active Sessions Page
- [ ] Shows 1 active session
- [ ] Progress bar displays
- [ ] Time calculations correct
- [ ] Shows 1 upcoming session
- [ ] Countdown timer works

### ✅ Revenue Page
- [ ] Total revenue: 50,000 XAF
- [ ] Monthly revenue: 50,000 XAF
- [ ] Top tutors list shows
- [ ] Recent transactions show

### ✅ Navigation
- [ ] All nav links work
- [ ] Active tab highlighting works
- [ ] Logout button present
- [ ] Navigation persists across pages

## Troubleshooting

### No data showing?
```sql
-- Check if test data exists
SELECT COUNT(*) FROM profiles;
SELECT COUNT(*) FROM tutor_profiles WHERE status = 'pending';
SELECT COUNT(*) FROM lessons;
SELECT COUNT(*) FROM payments;
```

If all return 0, run `ADMIN_TEST_DATA.sql` again.

### "Column last_seen does not exist"?
Run `ADD_ACTIVE_USER_TRACKING.sql` first.

### Still showing 0 users online?
```sql
-- Manually update last_seen for some users
UPDATE profiles
SET last_seen = NOW()
WHERE id IN (
  SELECT id FROM profiles LIMIT 5
);
```

### Error: "now.getTime is not a function"?
This should be fixed now. Refresh the page.

### Want to reset test data?
```sql
-- WARNING: This deletes ALL data!
DELETE FROM payments;
DELETE FROM lessons;
DELETE FROM tutor_profiles;
DELETE FROM profiles WHERE email LIKE '%@test.com';
DELETE FROM auth.users WHERE email LIKE '%@test.com';
```

Then run `ADMIN_TEST_DATA.sql` again.

## Quick Test Commands

Run these in Supabase SQL Editor for instant results:

```sql
-- Add 5 online users right now
UPDATE profiles
SET last_seen = NOW()
WHERE id IN (SELECT id FROM profiles ORDER BY RANDOM() LIMIT 5);

-- Create a pending tutor
INSERT INTO tutor_profiles (id, user_id, status, created_at)
SELECT gen_random_uuid(), id, 'pending', NOW()
FROM profiles WHERE user_type = 'tutor' LIMIT 1
ON CONFLICT DO NOTHING;

-- Create an active session
INSERT INTO lessons (id, tutor_id, learner_id, subject, start_time, end_time, status)
SELECT 
  gen_random_uuid(),
  (SELECT id FROM profiles WHERE user_type = 'tutor' LIMIT 1),
  (SELECT id FROM profiles WHERE user_type = 'learner' LIMIT 1),
  'Test Subject',
  NOW() - INTERVAL '30 minutes',
  NOW() + INTERVAL '30 minutes',
  'scheduled'
ON CONFLICT DO NOTHING;
```

## Next Steps

Once you've tested all features:

1. ✅ Verify active user tracking works
2. ✅ Test tutor approval workflow
3. ✅ Check sessions monitoring
4. ✅ Verify revenue tracking
5. 🚀 Ready to move to **Ticket #4: Tutor Discovery**!

---

**Need more test data?** Just run the test data script again. It uses `ON CONFLICT` so it won't duplicate users.

**Ready for production?** Delete test users with the reset command above, then start building Tutor Discovery! 🎉

