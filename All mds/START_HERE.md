# 🚀 START HERE - Admin Dashboard Setup

## ✅ Step 1: Next.js Server (DONE)
Your Next.js dev server is now running at:
- **http://localhost:3000/admin**

The `now.getTime` error is fixed! ✅

---

## 📋 Step 2: Add Test Data to Supabase (2 minutes)

### Open Supabase Dashboard
1. Go to: https://supabase.com/dashboard
2. Select your PrepSkul project
3. Click "SQL Editor" in the left sidebar

### Run Script 1: Enable Active User Tracking
1. **Copy ALL content from:**
   ```
   /Users/user/Desktop/PrepSkul/prepskul_app/All mds/ADD_ACTIVE_USER_TRACKING.sql
   ```
2. **Paste into SQL Editor**
3. **Click "RUN" button** (bottom right)
4. ✅ You should see: **"Success. No rows returned"**

### Run Script 2: Add Test Data
1. **Copy ALL content from:**
   ```
   /Users/user/Desktop/PrepSkul/prepskul_app/All mds/ADMIN_TEST_DATA.sql
   ```
2. **Paste into SQL Editor**
3. **Click "RUN" button**
4. ✅ You should see: **"Success. No rows returned"**

---

## 🎯 Step 3: View Your Dashboard

1. **Go to:** http://localhost:3000/admin
2. **Login with your admin credentials** (the one you set up earlier)
3. **You should now see:**

```
Dashboard
├─ Total Users: 25
│  └─ 8 tutors • 12 learners • 5 parents
├─ Active Users: 4 online now
│  └─ 18 active today
├─ Pending Tutors: 2
│  └─ Review applications →
└─ Total Revenue: 50,000 XAF
   └─ This month: 50,000 XAF
```

---

## 🧪 Step 4: Test All Features

Click around and test these pages:

### ✅ Dashboard (`/admin`)
- See all metrics populated
- Click "View details" on Active Users
- Click "Review applications" on Pending Tutors

### ✅ Active Users (`/admin/users/active`)
- See 4 users online now
- View user type breakdown (2 tutors, 2 learners, 1 parent)
- Check the hourly activity chart
- See the live user list

### ✅ Pending Tutors (`/admin/tutors/pending`)
- See 2 pending applications:
  - John Kamga (Mathematics, Physics)
  - Marie Ngono (English, French)
- Click "View Details" on any tutor
- Try the Approve/Reject buttons

### ✅ Tutor Detail Page (`/admin/tutors/{id}`)
- View full tutor profile
- See all qualification details
- Test contact buttons (Call, Email, WhatsApp)
- Add admin notes
- Use the Approve/Reject workflow

### ✅ Sessions (`/admin/sessions`)
- See 3 sessions:
  - 1 in progress (Mathematics)
  - 1 upcoming (English)
  - 1 completed (Physics)

### ✅ Active Sessions (`/admin/sessions/active`)
- See the live session with progress bar
- View upcoming session with countdown
- Check time calculations

### ✅ Revenue (`/admin/revenue`)
- Total Revenue: 50,000 XAF
- Monthly Revenue: 50,000 XAF
- Top Tutors: John Kamga
- Recent Transactions: 1 payment

---

## 🎉 Everything Working?

If you see all the data above, **congratulations!** 🎊

Your admin dashboard is fully functional with:
- ✅ Active user tracking
- ✅ Tutor review workflow
- ✅ Session monitoring
- ✅ Revenue analytics
- ✅ Real-time metrics

---

## 🧹 Want to Reset Test Data?

Run this in Supabase SQL Editor:

```sql
-- Delete all test data
DELETE FROM payments;
DELETE FROM lessons;
DELETE FROM tutor_profiles;
DELETE FROM profiles WHERE email LIKE '%@test.com';
DELETE FROM auth.users WHERE email LIKE '%@test.com';
```

Then run `ADMIN_TEST_DATA.sql` again for fresh data!

---

## 🚀 Next: Tutor Discovery (Ticket #4)

Once you've tested everything, we'll build:

### Tutor Discovery Feature for Students
- Browse available tutors
- Filter by subject, location, availability
- View tutor profiles
- Book sessions
- Beautiful, intuitive UI

**Ready to start Tutor Discovery?** Just say the word! 🎯

---

## 📚 All Documentation

- **`START_HERE.md`** - This file (quick start)
- **`QUICK_TESTING_STEPS.md`** - 3-step testing guide
- **`ADMIN_TESTING_GUIDE.md`** - Complete testing checklist
- **`TESTING_SIMPLE_GUIDE.md`** - Sample data explanation
- **`BEFORE_AFTER_TEST_DATA.md`** - Visual comparison
- **`ACTIVE_USER_TRACKING_COMPLETE.md`** - Full feature docs
- **`ADD_ACTIVE_USER_TRACKING.sql`** - SQL to enable tracking
- **`ADMIN_TEST_DATA.sql`** - SQL to add test data

---

## ⚡ Quick Troubleshooting

### Admin dashboard shows all 0s?
→ Run the SQL scripts in Supabase

### "Column last_seen does not exist"?
→ Run `ADD_ACTIVE_USER_TRACKING.sql` first

### Can't login to admin?
→ Check your admin user in Supabase → Table Editor → profiles
→ Make sure `is_admin = TRUE` for your user

### Page not loading?
→ Check terminal for Next.js errors
→ Try refreshing the page
→ Clear browser cache/cookies

---

**Total setup time: ~2 minutes**  
**You're almost there!** 🚀

