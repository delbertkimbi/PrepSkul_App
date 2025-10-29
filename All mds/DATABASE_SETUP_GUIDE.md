# 🗄️ PrepSkul Database Setup Guide

## Quick Setup (3 SQL Files)

### Step 1: Create Tables (Run Once)
📁 **File:** `CREATE_ALL_TABLES.sql`

**What it does:**
- ✅ Creates all database tables
- ✅ Sets up Fapshi payment integration support
- ✅ Adds indexes for performance
- ✅ Enables Row Level Security

**Run this in Supabase SQL Editor** (one time only)

---

### Step 2: Add Demo Data (For Testing)
📁 **File:** `ADD_DEMO_DATA.sql`

**What it does:**
- ✅ Creates 5 test users
- ✅ Creates 2 pending tutors (for admin review)
- ✅ Creates sample lessons and payments
- ✅ Adds Fapshi payment examples

**Test login credentials:**
- Email: `tutor1@test.com`
- Password: `password123`

---

### Step 3: Delete Demo Data (When Going Live)
📁 **File:** `DELETE_DEMO_DATA.sql`

**What it does:**
- ✅ Removes all test data
- ✅ Keeps all real users
- ✅ Production-ready database

**Run this before launching to production**

---

## Tables Created

### 📚 Core Tables
1. **lessons** - Tutoring sessions
2. **bookings** - Lesson requests from students

### 💰 Payment Tables (Fapshi Ready)
3. **payments** - All payment transactions
   - Supports: MTN Mobile Money, Orange Money, Express Union
   - Tracks: `fapshi_transaction_id`, `fapshi_payment_link`
4. **payment_webhooks** - Fapshi callback handling

### 📅 Scheduling
5. **tutor_availability** - Tutor schedules

### ⭐ Reviews
6. **reviews** - Student feedback for tutors

---

## Fapshi Integration Fields

According to [Fapshi's API documentation](https://docs.fapshi.com/en/api-reference/getting-started), the `payments` table includes:

- `fapshi_transaction_id` - Unique transaction reference from Fapshi
- `fapshi_payment_link` - Generated checkout link
- `fapshi_status` - Raw status from Fapshi API
- `fapshi_response` - Full JSON response for debugging
- `payment_method` - MTN, Orange Money, etc.

---

## Testing the Admin Dashboard

1. **Run SQL in this order:**
   ```
   1. CREATE_ALL_TABLES.sql
   2. ADD_DEMO_DATA.sql
   ```

2. **Create admin user** (in Supabase SQL Editor):
   ```sql
   -- Update your real user to be admin
   UPDATE public.profiles 
   SET is_admin = true 
   WHERE email = 'your-email@example.com';
   ```

3. **Login to admin:**
   - Go to: http://localhost:3001/admin
   - Use your email and password

4. **You'll see:**
   - ✅ 5 total users
   - ✅ 2 pending tutors
   - ✅ 1 active session
   - ✅ 50,000 XAF revenue

---

## Going Live Checklist

- [ ] Run `CREATE_ALL_TABLES.sql`
- [ ] Run `ADD_DEMO_DATA.sql` (for testing)
- [ ] Test all features
- [ ] Set up your admin account
- [ ] **Run `DELETE_DEMO_DATA.sql`** ⚠️
- [ ] Set up Fapshi API credentials
- [ ] Deploy to production

---

## Need Help?

- **Fapshi Docs:** https://docs.fapshi.com/en/api-reference/getting-started
- **Supabase Docs:** https://supabase.com/docs

---

**Ready to go!** 🚀

