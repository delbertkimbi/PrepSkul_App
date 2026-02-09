# Sessions & Requests – UI and Functionality Fixes

Audit of **sessions** and **requests** sections for **students**, **parents**, and **tutors**. Items below are concrete fixes to apply.

---

## 1. Student / Parent Home (Student Home Screen)

**File:** `lib/features/dashboard/screens/student_home_screen.dart`

### Functionality
- **Stats always show 0:** "Active Tutors" and "Sessions" are hardcoded to `'0'`. They should load real counts (e.g. from booking/session services) and update when the user has tutors or sessions.
- **No Upcoming Sessions / Pending Requests on Home:** Docs mention "Upcoming Sessions" and "Pending Requests" sections with "See all" to the Requests tab. The current home only has Quick Actions (My Sessions, Payment History). Consider adding:
  - A short "Upcoming Sessions" list (e.g. next 2–3) with "See all" → `/my-sessions` or Requests tab.
  - A short "Pending Requests" list with "See all" → Requests tab (index 2).

### UI
- **Quick Actions subtitles not localized:** "View upcoming and completed sessions" and "View and manage your payments" are hardcoded; move to `AppLocalizations` if you support multiple languages.
- **Parent-only "Learning Progress" is hardcoded:** Title and dialog text ("Coming Soon!", etc.) are in English only; add localization keys if needed.

---

## 2. Student / Parent – My Requests Screen

**File:** `lib/features/booking/screens/my_requests_screen.dart`

### Functionality (critical)
- **Parent sent to wrong nav after actions:** Several places use **`/student-nav`** when navigating back to main app. Parents use **`/parent-nav`**. So after:
  - "Pay now" success → navigate to Requests tab
  - Post-trial / booking success → navigate to Sessions tab
  - "View Session" (or similar) → navigate to My Sessions
  - "Fix missing recurring session" success → navigate to Requests tab  
  the code should use **current user type**: if parent → `'/parent-nav'`, if student → `'/student-nav'` (same pattern as in `MySessionsScreen` around line 2325).

**Places to fix (all currently use `/student-nav`):**
- ~1451: After pay success → `pushNamedAndRemoveUntil(..., '/student-nav', ...)`  
- ~2227: After another success flow → same  
- ~3599: Route predicate `route.settings.name == '/student-nav'` → also allow `'/parent-nav'`  
- ~3944: After "fix missing recurring session" → `pushNamedAndRemoveUntil(..., '/student-nav', ...)`

Use `_getUserType()` (or equivalent) and choose `/parent-nav` or `/student-nav` accordingly.

### UI
- **FAB label:** "Request Another Tutor" is hardcoded; consider localization.
- **Tab content:** Ensure empty states and error messages are consistent and, if applicable, localized.

---

## 3. Student / Parent – My Sessions Screen

**File:** `lib/features/booking/screens/my_sessions_screen.dart`

### Functionality
- **Parent vs student nav:** One place (~2325–2329) already uses `userType == 'parent' ? '/parent-nav' : '/student-nav'`. Ensure **every** navigation back to main shell (after "View session", back from detail, etc.) uses the same logic so parents never land on student shell.
- **TODOs:** Imports for `session_transcript_service` and `session_summary_screen` are commented with "Fix import path"; fix or remove if those features are used.

### UI
- No major structural issues found; keep empty states and loading states consistent with the rest of the app.

---

## 4. Tutor – Requests Screen

**File:** `lib/features/tutor/screens/tutor_requests_screen.dart`

### Functionality
- **Error handling:** On load failure, SnackBar shows raw error: `'Failed to load requests: $e'`. Use a user-friendly message (e.g. "Unable to load requests. Please try again.") and log `e` separately.
- **Approval/Rejection:** Loading and success/error feedback are present; ensure any other actions (e.g. opening detail) also handle errors and offline sensibly.

### UI
- **App bar title hardcoded:** `title: Text('Requests')` should use localization, e.g. `t.navRequests` (or a dedicated "Tutor Requests" key if different from nav label).
- **Filter chips:** Labels are built from counts; ensure "All", "Pending", "Approved", "Rejected" are localized if you support multiple languages.
- **Empty state:** `EmptyStateWidget.noRequests()` is used; confirm copy and icon match tutor context ("No booking requests" vs "No requests").

---

## 5. Tutor – Sessions Screen

**File:** `lib/features/tutor/screens/tutor_sessions_screen.dart`

### Functionality
- **Large file (~3500+ lines):** Consider splitting into smaller widgets (e.g. session card, filter bar, list) or a separate "sessions list" widget for readability and reuse.
- **Error handling:** Ensure load errors and action errors (e.g. start session, reschedule) show user-friendly messages and not raw exceptions.
- **Offline:** If tutors can open this screen offline, ensure cached data or a clear "You're offline" state is shown where appropriate.

### UI
- **Titles and labels:** Check that "Upcoming", "Past", "All", and any other filter or section labels are localized.
- **Empty states:** Verify copy fits tutor context ("No upcoming sessions" / "No past sessions").
- **Consistency:** Match styling (cards, chips, spacing) with Tutor Requests and Student/Parent sessions for a consistent experience.

---

## 6. Cross-cutting

### Localization
- Use `AppLocalizations.of(context)!` (or your current approach) for all user-facing strings in:
  - Student Home (stats labels, quick action titles/subtitles, Learning Progress).
  - Tutor Requests (title, filter labels, errors).
  - Tutor Sessions (filter labels, empty states, buttons).
  - My Requests (FAB, any hardcoded empty/error text).

### Parent vs student
- **Single source of truth for "am I parent?":** Both My Requests and My Sessions need the same notion (e.g. profile `user_type` or a shared getter). My Requests already has `_getUserType()` / `_cachedUserType`; use it for all nav decisions so parents always get `/parent-nav` and students `/student-nav`.

### Navigation summary
| User   | Main shell route   | After "View Session" / "Pay" / success |
|--------|--------------------|----------------------------------------|
| Student| `/student-nav`     | `/student-nav` with appropriate tab    |
| Parent | `/parent-nav`      | `/parent-nav` with appropriate tab     |

---

## 7. Suggested priority

1. **High:** Parent nav fix in My Requests (use `/parent-nav` when user is parent).
2. **High:** Student Home stats – replace hardcoded `'0'` with real Active Tutors and Sessions counts.
3. **Medium:** Tutor Requests – localize title and improve error message.
4. **Medium:** Student Home – add Upcoming Sessions / Pending Requests sections (or document as future work).
5. **Low:** Localize remaining hardcoded strings; refactor Tutor Sessions into smaller widgets.

---

*Generated from codebase audit of sessions and requests flows for students, parents, and tutors.*
