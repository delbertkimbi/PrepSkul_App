# Pre-Implementation Checklist - Phase 1.2

## ✅ Email Account Setup

**PrepSkul Virtual Assistant Email:**
- ✅ Using: `[REDACTED - Use your VA email]` (temporary, can change later)
- ⚠️ **Consideration:** This is your personal Fathom account email
- 📝 **Future:** Can migrate to `prepskul-va@prepskul.com` later if needed

**Action Required:**
- [ ] Ensure `[REDACTED - Use your VA email]` has Google Calendar access
- [ ] Verify email can receive calendar invites
- [ ] Test calendar access from this account

---

## ✅ Fathom Account Setup

**Current Status:**
- ✅ Fathom account created with `[REDACTED - Use your VA email]`
- ✅ App "PrepSkul VA" created
- ✅ OAuth credentials obtained (dev & prod)
- ✅ Redirect URLs configured
- ✅ App signed up for marketplace

**Action Required:**
- [ ] Connect `[REDACTED - Use your VA email]` to Fathom account
- [ ] Authorize Fathom to access Google Calendar for this email
- [ ] Test Fathom can see calendar events
- [ ] Generate API key (if using API key method instead of OAuth)

**How to Connect:**
1. Log into Fathom dashboard
2. Go to Settings → Integrations
3. Connect Google Calendar
4. Authorize with `[REDACTED - Use your VA email]` account
5. Verify Fathom can access calendar

---

## ✅ Google Calendar API Setup

**Required:**
- [ ] Google Cloud Project created
- [ ] Google Calendar API enabled
- [ ] OAuth 2.0 credentials created
- [ ] Service account OR OAuth client configured
- [ ] Credentials stored in environment variables

**Action Required:**
- [ ] Verify Google Cloud Project exists
- [ ] Enable Google Calendar API
- [ ] Create OAuth 2.0 credentials (for server-side calendar creation)
- [ ] Store credentials securely (environment variables)

**Credentials Needed:**
```
GOOGLE_CALENDAR_CLIENT_ID=your_client_id
GOOGLE_CALENDAR_CLIENT_SECRET=your_client_secret
GOOGLE_CALENDAR_SERVICE_ACCOUNT_EMAIL=your_service_account_email (if using service account)
GOOGLE_CALENDAR_PRIVATE_KEY=your_private_key (if using service account)
```

---

## ✅ Fapshi Payment Setup

**Current Status:**
- ✅ Fapshi account activated
- ✅ API credentials obtained (dev & prod)
- ✅ Test credentials available

**Action Required:**
- [ ] Verify Fapshi direct-pay is activated (contact support if needed)
- [ ] Test payment flow in sandbox
- [ ] Store credentials in environment variables
- [ ] Decide: Sandbox only or ready for live?

**Credentials Needed:**
```
FAPSHI_ENVIRONMENT=sandbox  # or 'live'
FAPSHI_COLLECTION_API_USER_LIVE=your-fapshi-collection-api-user-here
FAPSHI_COLLECTION_API_KEY_LIVE=your-fapshi-collection-api-key-here
FAPSHI_SANDBOX_API_USER=your-fapshi-sandbox-api-user-here
FAPSHI_SANDBOX_API_KEY=your-fapshi-sandbox-api-key-here
```

---

## ✅ Database Migrations

**Required Migrations:**
- [ ] `012_add_meet_calendar_fields.sql` - Meet links and calendar fields
- [ ] `013_add_fathom_session_tables.sql` - Transcripts and summaries
- [ ] `014_add_assignments_table.sql` - Assignments from action items
- [ ] `015_add_admin_flags_table.sql` - Admin flags

**Action Required:**
- [ ] Review all migration files
- [ ] Apply migrations to database
- [ ] Verify tables created correctly
- [ ] Test RLS policies

---

## ✅ Environment Variables

**Required Variables:**
```env
# Fapshi
FAPSHI_ENVIRONMENT=sandbox
FAPSHI_COLLECTION_API_USER_LIVE=...
FAPSHI_COLLECTION_API_KEY_LIVE=...
FAPSHI_SANDBOX_API_USER=...
FAPSHI_SANDBOX_API_KEY=...

# Google Calendar
GOOGLE_CALENDAR_CLIENT_ID=...
GOOGLE_CALENDAR_CLIENT_SECRET=...
GOOGLE_CALENDAR_SERVICE_ACCOUNT_EMAIL=...
GOOGLE_CALENDAR_PRIVATE_KEY=...

# Fathom OAuth
FATHOM_CLIENT_ID_DEV=your-fathom-dev-client-id-here
FATHOM_CLIENT_SECRET_DEV=your-fathom-dev-client-secret-here
FATHOM_WEBHOOK_SECRET_DEV=your-fathom-dev-webhook-secret-here
FATHOM_CLIENT_ID_PROD=your-fathom-prod-client-id-here
FATHOM_CLIENT_SECRET_PROD=your-fathom-prod-client-secret-here
FATHOM_WEBHOOK_SECRET_PROD=your-fathom-prod-webhook-secret-here

# PrepSkul Virtual Assistant
PREPSKUL_VA_EMAIL=[REDACTED - Use your VA email]
PREPSKUL_VA_NAME=PrepSkul Virtual Assistant
PREPSKUL_VA_DISPLAY_NAME=PrepSkul VA
FATHOM_ACCOUNT_EMAIL=[REDACTED - Use your VA email]

# Admin
ADMIN_EMAIL=admin@prepskul.com

# Redirect URLs
FATHOM_REDIRECT_URI_DEV=https://app.prepskul.com/auth/fathom/callback
FATHOM_REDIRECT_URI_PROD=https://app.prepskul.com/auth/fathom/callback
```

**Action Required:**
- [ ] Add all variables to Flutter app `.env` file
- [ ] Add all variables to Next.js `.env.local` file
- [ ] Add all variables to Vercel environment variables
- [ ] Verify no secrets committed to Git

---

## ⚠️ Important Considerations

### 1. Concurrent Meetings Limitation
- **Issue:** Fathom can only join ONE meeting at a time
- **Impact:** If multiple sessions overlap, only one will be recorded
- **Solution:** Implement smart scheduling to minimize overlaps
- **Action:** Add conflict detection when creating sessions

### 2. App Verification Status
- **Current:** UNVERIFIED
- **Impact:** Users see warning when authorizing
- **Solution:** Request verification after launch with real users
- **Action:** Complete app details, launch, then request verification

### 3. Email Account Migration
- **Current:** Using `[REDACTED - Use your VA email]`
- **Future:** Can migrate to `prepskul-va@prepskul.com`
- **Consideration:** Migration requires:
  - Creating new email account
  - Re-authorizing Fathom with new email
  - Updating all calendar events
  - Testing thoroughly

### 4. Rate Limiting
- **Fathom:** 60 API calls per minute
- **Impact:** May hit limits with many concurrent sessions
- **Solution:** Use webhooks, implement queuing
- **Action:** Monitor API usage, implement rate limit handling

### 5. Mobile OAuth
- **Issue:** Fathom doesn't accept custom URL schemes
- **Solution:** Use HTTPS web app URLs
- **Action:** Ensure mobile apps redirect to web app for OAuth

---

## 🚀 Implementation Order

### Week 1: Foundation
1. ✅ Setup environment variables
2. ✅ Apply database migrations
3. ✅ Create Fapshi payment service
4. ✅ Test payment flow

### Week 2: Calendar & Meet
1. ✅ Setup Google Calendar API
2. ✅ Create calendar service
3. ✅ Implement Meet link generation
4. ✅ Test calendar event creation

### Week 3: Fathom Integration
1. ✅ Connect Fathom to `[REDACTED - Use your VA email]`
2. ✅ Authorize Google Calendar access
3. ✅ Create Fathom service
4. ✅ Implement webhook handler
5. ✅ Test Fathom auto-join

### Week 4: Processing & Distribution
1. ✅ Implement summary distribution
2. ✅ Create assignment system
3. ✅ Add admin flag detection
4. ✅ Test complete flow

### Week 5: Polish & Testing
1. ✅ Error handling
2. ✅ Edge cases
3. ✅ End-to-end testing
4. ✅ Documentation

---

## ✅ Ready to Start?

**Before Starting Implementation:**

1. **Google Calendar API:**
   - [ ] Do you have Google Cloud Project?
   - [ ] Is Calendar API enabled?
   - [ ] Do you have OAuth credentials?

2. **Fathom Connection:**
   - [ ] Can you connect `[REDACTED - Use your VA email]` to Fathom?
   - [ ] Can you authorize Google Calendar access?
   - [ ] Can Fathom see calendar events?

3. **Fapshi:**
   - [ ] Is direct-pay activated?
   - [ ] Ready to test in sandbox?

4. **Database:**
   - [ ] Can you apply migrations?
   - [ ] Do you have database access?

**If all checked, you're ready to start! 🚀**

---

**Last Updated:** January 2025  
**Status:** Pre-Implementation Checklist






