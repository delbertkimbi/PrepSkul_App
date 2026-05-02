# PrepSkul: Work Analysis and Feedback

**Date:** January 2026  
**Scope:** Flutter app (`prepskul_app`), Next.js web/API (`PrepSkul_Web`), recent changes, and remaining work.

---

## 1. What Has Been Done

### 1.1 Recent Work (This Session / Related)

| Area | What was done | Where |
|------|----------------|-------|
| **Payment flow UI** | Clear error vs success messaging; retry for failed/timeout; progress and “Cancel” during pending; one in-app reminder per day kept. | `trial_payment_screen.dart` |
| **Tutor onboarding reminders** | In-app + email + push via API; stage tracking (`missing_id`, `missing_video`, `missing_statement`); stage-specific email/push copy; daily cron for incomplete tutors (24h cooldown). | `notification_helper_service.dart`, `tutor_home_screen.dart`, `tutor_onboarding_choice_screen.dart`, `tutor_onboarding_progress_service.dart`, `PrepSkul_Web/app/api/notifications/send`, `PrepSkul_Web/app/api/cron/onboarding-reminders` |
| **Scheduled notifications cron** | Switched to Supabase **admin client** so external cron (e.g. cron-job.org) works without a session; batch size reduced to 50 for Vercel free tier. | `PrepSkul_Web/app/api/cron/process-scheduled-notifications/route.ts` |
| **Profile / discovery UI** | Profile settings cards reverted to white; tutor detail Message/Book Trial buttons explicit white background; onboarding background shapes structured via `_DecorativeShapeConfig`. | `profile_screen.dart`, `tutor_detail_screen.dart`, `simple_onboarding_screen.dart` |
| **Web tutor page** | Dart-style syntax fixed for Next.js; merge conflicts resolved; metadata and mobile deep-link preserved. | `PrepSkul_Web/app/tutor/[id]/page.tsx` |
| **Database / security** | RLS enabled for `profiles` and `payment_requests`; function `search_path` fixed. | Supabase migrations `044`, `045` |

### 1.2 Already in Place (Pre-existing)

- **Booking:** Students create requests; tutors approve/reject; recurring sessions created; trial booking and pricing.
- **Trial payments:** Fapshi integration, polling, webhook path, Meet link after payment.
- **Notifications:** In-app, email (Resend), push (Firebase) for booking/trial/profile/payment/session events; permission and quiet-hours checks; rate limiting on send API.
- **Tutor onboarding:** Progress table and service; skip/resume; completion checks; profile completion calculator and checklist (per TUTOR_PROFILE_COMPLETION_PLAN).
- **Session lifecycle:** Start/end services, status updates, attendance, Meet link generation (service layer).
- **Auth:** Role selection, tutor/student flows, OTP, email confirmation, navigation by onboarding state.
- **Discovery:** Find tutors, tutor detail, pricing from service, video URL handling (with fallback when ID extraction fails).
- **PrepSkul Web:** Notifications send API, cron for scheduled notifications and onboarding reminders, Supabase admin usage where needed.

---

## 2. What Is Left

### 2.1 Critical for Launch (from CURRENT_CAPABILITIES)

| Gap | Description | Notes |
|-----|-------------|--------|
| **Payment request on approval** | When tutor approves a **regular** (non-trial) booking, create payment request and drive student to pay. | Trial payment path exists; regular booking payment flow is the missing piece. |
| **Session start/end UI** | Services exist; UI to start/end session (e.g. from session detail) not fully wired. | `CURRENT_CAPABILITIES`: “UI buttons for start/end (service exists, UI needs integration)”. |
| **Feedback collection** | `session_feedback` table and service exist; end-to-end feedback UI and 24h reminder flow. | Phase 3.1 in docs; some feedback screens already present. |
| **Earnings → active** | Payment confirmation (e.g. webhook) and quality-assurance window so pending earnings move to active. | Depends on payment request creation and webhook/QA logic. |
| **Quality assurance** | Issue detection, fines/refunds, auto-move pending → active after 24–48h. | Phase 3.2; refund/fine TODOs in `session_lifecycle_service.dart`, `quality_assurance_service.dart`. |

### 2.2 Important but Not Blocking

- **Refund/disbursement:** TODOs for “Process refund via Fapshi” and “Implement Fapshi disbursement” in lifecycle and payout services.
- **Parent/learner selection:** “UI for parents to select which child they’re booking for” (trial_session_service).
- **Cancel/approve API:** Request detail and tutor request detail screens have “Call API to cancel/approve” TODOs; verify if backend exists and wire them.
- **Google Maps:** Embedded map widget still placeholder until API key; TODOs in code.
- **Agora token refresh:** TODO for token refresh in `agora_service.dart`.
- **Gender/match:** Tutor matching has “Add gender field” / “Implement when gender field available” TODOs.
- **Skulmate:** DiagramLabelGameScreen fallback, friend request decline/options TODOs.

### 2.3 UI/UX (from INTUITIVE_UI_PLAN)

- Student/Tutor home: hero, quick actions, progress rings, recommended tutors, earnings card, today’s schedule, etc. (many checkboxes still unchecked).
- Design system: 8px grid, reusable components, loading/empty/error states.
- Optional packages: staggered animations, shimmer, responsive framework, etc.

### 2.4 Database / Backend

- **session_feedback:** Referenced in code; ensure migration exists and is applied so “table does not exist” warnings go away.
- **trial_session_pricing.discount_percent:** Warning in logs; add column or stop reading it.
- **Video URL:** Tutor detail warns when YouTube ID can’t be extracted (e.g. non-standard URL); consider normalizing or guiding input.

---

## 3. What Could Be Improved

### 3.1 Reliability and Operations

- **Cron visibility:** Add a simple health or “last run” endpoint for cron-job.org (e.g. `/api/cron/process-scheduled-notifications` returns 200 with `{ lastRun, processed }` or similar) so failures are easier to see.
- **Notification API failures:** App already logs “Notification API call failed / Session reminder scheduling failed” when Web API is unreachable; consider retry or queue for critical reminders so they’re not lost.
- **Vercel free tier:** Process-scheduled-notifications and onboarding-reminders both do work in a single request; if volume grows, consider smaller batches or splitting runs to avoid timeouts.

### 3.2 Code Quality and Consistency

- **TODOs:** ~25+ TODOs in `lib` (import paths, “Call API”, refunds, Maps, Agora, matching). Prioritize: fix import paths and wire real cancel/approve APIs; then refunds/disbursement; then Maps/Agora/skulmate.
- **Import paths:** Several “TODO: Fix import path” in discovery/dashboard/booking; align with actual package structure to avoid future breakage.
- **Duplication:** Some notification copy is built in both Flutter and Next.js (e.g. onboarding stage messages); consider a single source (e.g. API returns title/body from stage) to keep copy in sync.

### 3.3 UX and Product

- **Payment:** Timeout and failure flows are clearer; optional next step: after N failed polls, suggest “Pay later” or “Contact support” so users aren’t stuck.
- **Onboarding reminders:** Stage-specific emails are in place; optional: track “last_reminder_stage” to avoid repeating the same stage email too often.
- **Reviews:** Logs mention “session_feedback table does not exist yet”; once migration is applied, ensure review counts and display on tutor profile/detail are correct.

### 3.4 Documentation and Planning

- **CURRENT_CAPABILITIES.md:** Update to reflect trial payment UI improvements, onboarding reminders (email/push + cron), and process-scheduled-notifications fix.
- **INTUITIVE_UI_PLAN.md:** Good backlog; mark items that are already done (e.g. profile white cards, tutor detail buttons, onboarding shapes) so progress is visible.
- **Single “what’s left” doc:** Consider one short doc (or section in this file) that lists only: “Must have for launch”, “Should have next”, “Tech debt / TODOs”, with file references.

---

## 4. Summary Table

| Category | Done | Left | Improve |
|----------|------|------|---------|
| **Payments** | Trial pay flow + UI (errors, retry, cancel); Fapshi sandbox/live | Regular payment request on approval; refund/disbursement TODOs | Clear “pay later”/support path after repeated failure |
| **Notifications** | In-app, email, push; onboarding reminders + stage + cron; scheduled cron fixed (admin client) | — | Retry/queue when API fails; optional cron health endpoint |
| **Tutor onboarding** | Progress, skip/resume, reminders (in-app + email + push), stage-specific copy, daily cron | — | Optional last_stage tracking to reduce repeat emails |
| **Booking / sessions** | Request flow; trial booking; start/end services | Start/end UI wiring; feedback end-to-end; payment request on approval | Wire cancel/approve to real APIs where TODOs exist |
| **Earnings / QA** | Pending balance, structure for QA | Payment confirmation path; QA rules; auto active after 24–48h | Implement refund/disbursement TODOs when Fapshi supports |
| **UI/UX** | Profile white cards; tutor detail buttons; onboarding shapes; payment pending/error states | INTUITIVE_UI_PLAN checklist; design system consistency | Fix import paths; reuse components; document done vs pending |
| **Infra / DB** | RLS and search_path fixes; admin client for crons | session_feedback migration; discount_percent or drop | Apply migrations; reduce 500s from missing tables/columns |

**Overall:** Core booking and trial payments are in place; notifications and tutor onboarding reminders are implemented and wired. The largest remaining gaps for launch are: **regular payment request on approval**, **session start/end UI**, and **feedback + earnings/QA path**. Addressing TODOs (imports, cancel/approve APIs, refunds) and keeping CURRENT_CAPABILITIES and INTUITIVE_UI_PLAN up to date will make the next steps clear for the team.
