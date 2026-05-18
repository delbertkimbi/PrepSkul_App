# PrepSkul Launch Scope (v1)

**Document type:** Launch charter + Phase 0 audit baseline  
**Created:** 2026-05-16  
**Audience:** Lean team, Cursor implementation phases  
**Status:** Phase 0 complete (read-only audit). Implementation phases follow `LAUNCH_IMPLEMENTATION_PLAN` (separate prompts).

---

## 1. Executive intent

Ship a **stable 1:1 tutoring marketplace** in Cameroon: book → pay (Fapshi) → join session (online Agora or onsite) → tutor earnings → withdrawal. **Group classes** remain in codebase but **off at launch** (online-only when enabled later). Do **not** refactor `agora_video_session_screen.dart` until post-launch stability.

---

## 2. In scope / out of scope

### In scope (v1 launch)

| Area | Scope |
|------|--------|nb v
| **Sessions** | 1:1 only — **online** (in-app Agora classroom) and **onsite** (address, tutor start/end, optional family feedback) |
| **Booking** | Request → tutor approve → payment request → pay → recurring + individual sessions |
| **Trials** | Trial book/approve/pay/join (online trials may still get Meet link via webhook) |
| **Payments** | Fapshi collection (MTN/Orange), webhook status sync, payment_request + trial + per-session pay |
| **Tutor money** | 15% platform fee on session fee only; 85% tutor; transport 100% tutor; pending → active (QA cron) → payout request → Fapshi disburse (admin) |
| **Platforms** | Sign-off: **Web Chrome** (tutor + learner) + **one Android** build per role |
| **Auth** | Email + Google + phone login (OTP verification flag off) |

### Out of scope (explicit deferrals)

| Area | Notes |
|------|--------|
| **Group classes** | Online-only when shipped; `GROUP_CLASSES_ENABLED=false` at launch |
| **SkulMate** | Optional UAT; recommend **off** at launch unless dedicated QA |
| **Preply parity / desktop Z-layout polish** | UX only; not launch blockers |
| **Riverpod / session screen split** | Post-launch maintainability |
| **Advanced onsite anti-cheat / continuous GPS** | See `ONSITE_SESSION_TRACKING_IMPROVEMENTS_PLAN.md` — minimal tutor-centric flow for v1 |
| **iOS Safari screen-share perfection** | Best-effort; Chrome-first |
| **Fathom webhook / VA** | Exists; not on critical path unless product insists |

---

## 3. P0 flows (must pass before RC)

### P0-A — Recurring booking money path

1. Student submits booking request (online or onsite).  
2. Tutor approves → `PaymentRequestService.createPaymentRequestOnApproval` (`booking_service.dart`).  
3. `recurring_sessions` row created on approval (individual sessions **after first pay**).  
4. Student pays via `booking_payment_screen` → `externalId: payment_request_{id}`.  
5. Fapshi webhook (Next.js) marks `payment_requests.status = paid`.  
6. **Session unlock:** client `FapshiWebhookService.handleWebhook` (poll/complete) generates/links recurring + `individual_sessions`.  
7. Student/tutor see sessions; **online** → Join opens Agora when paid + in window.

### P0-B — Trial path

1. Trial created → pay with `externalId: trial_{trialSessionId}` (trial payment screens / services).  
2. Webhook → `trial_sessions.payment_status = paid`, optional Meet link for `location === 'online'`.  
3. Join trial per `trial_session_service` paid + time rules.

### P0-C — Per-session pay (recurring plan)

1. Session completes → `SessionPaymentService.createSessionPayment` / lifecycle earnings.  
2. Pay with `externalId: session_{individualSessionId}`.  
3. Webhook → `session_payments.payment_status = paid`; tutor_earnings stay **pending** until QA cron.

### P0-D — Tutor wallet

1. Earnings **pending** after session payment confirmed.  
2. `PrepSkul_Web/app/api/cron/process-pending-earnings` → **active** after 24h QA window (no serious flags).  
3. Tutor `TutorPayoutService.requestPayout` (min 5,000 XAF) → admin `POST /api/payouts/process` → Fapshi disburse `externalId: payout_{payoutRequestId}`.

### P0-E — Online classroom (1:1)

Manual sign-off: `docs/session_screenshare_qa_matrix.md` (2-user Chrome): teaching tools, screen share, peer-left UI.

### P0-F — Onsite (1:1 minimal)

Tutor start/end, address visible, completion does not require student check-in; earnings path same as online session fee + transport rules.

---

## 4. Feature flags — v1 launch (Phase 1 implemented)

| Flag / config | Code default (Phase 1) | Enable for post-launch / UAT | Notes |
|---------------|------------------------|------------------------------|-------|
| `AppConfig.isProduction` | `false` (sandbox) | `true` for production RC | Fapshi live vs sandbox |
| `AppConfig.enableGroupClasses` | **`false`** (`GROUP_CLASSES_ENABLED` unset) | Set `GROUP_CLASSES_ENABLED=true` in Flutter `.env` / `window.env` and Vercel | Flutter + `PrepSkul_Web/lib/services/group-classes/feature-flag.ts` |
| `AppConfig.enableSkulMate` | **`true`** (code const) | Set const to `false` if SkulMate out of launch UAT | **In scope for v1** unless team flips const; not env-gated |
| SkulMate (launch doc) | In: optional UAT | Out: set `enableSkulMate = false` | Reduces QA surface if turned off |
| `AppConfig.enablePhoneOtpVerification` | `false` | Keep `false` until OTP ready | |
| `AppConfig.enableGoogleSignIn` | `true` | `true` | |
| `AppConfig.enablePhoneSignIn` | `true` | `true` | |
| `AppConfig.enablePrepSkulVA` | env default `true` | `true` or env `false` | Non-blocking |
| `AppConfig.enableSessionCameraPublishing` | `true` | `true` | |
| `AppConfig.enableLearnerScreenShare` | `true` | `true` (or tutor-only if product changes) | |
| Fapshi collection keys | `fapshiApiUser` / `fapshiApiKey` | Set per env in `.env` / Vercel | Prod: `FAPSHI_COLLECTION_API_*_LIVE` |
| Fapshi disburse keys | `fapshiDisburseApiUser` / `fapshiDisburseApiKey` | Required for payouts | Prod: `FAPSHI_DISBURSE_API_*_LIVE` |

---

## 5. Fapshi webhook — verified behavior

**File (verified exists):** `PrepSkul_Web/app/api/webhooks/fapshi/route.ts`  
**Documented URL:** `https://www.prepskul.com/api/webhooks/fapshi`  
**Also exists:** `PrepSkul_Web/app/api/webhooks/fathom/route.ts` (not launch-critical)

### externalId routing (must match Flutter `FapshiService.initiateDirectPayment`)

| Prefix | Example | Handler | DB impact (SUCCESS) |
|--------|---------|---------|---------------------|
| `trial_` | `trial_{uuid}` | `handleTrialSessionPayment` | `trial_sessions.payment_status = paid`, status `scheduled`, optional Meet link (online) |
| `payment_request_` | `payment_request_{uuid}` | `handlePaymentRequestPayment` | `payment_requests.status = paid`; idempotent if already paid |
| `session_` | `session_{individual_session_id}` | `handleSessionPayment` | `session_payments.payment_status = paid`; notifications; earnings remain pending for cron |
| *(fallback)* | unknown | `handleByTransactionId` | Lookup by `fapshi_trans_id` on trial_sessions, payment_requests, session_payments |

**Status normalization:** SUCCESSFUL/SUCCESS → SUCCESS; FAILED; EXPIRED; PENDING/CREATED/PROCESSING → PENDING.

**Idempotency (verified):** `payment_request_` skips duplicate SUCCESS if already `paid`; ignores FAILED if already `paid`.

### Flutter mirror (client-side, not HTTP receiver)

**File:** `prepskul_app/lib/features/payment/services/fapshi_webhook_service.dart`  
**Invoked from:** `booking_payment_screen._completePayment`, polling success paths — **same externalId patterns**.

**Critical difference (verified gap):**

| Step | Next.js webhook | Flutter `FapshiWebhookService` |
|------|-----------------|--------------------------------|
| Mark `payment_requests` paid | Yes | Yes |
| Generate `individual_sessions` after first booking pay | **No** | **Yes** (`generateIndividualSessions`, recurring link) |
| Group enrollment finalize | No | Yes (`GroupClassService.finalizeEnrollmentForPaymentRequest`) |

**Implication:** If the learner pays via USSD and **closes the app before** poll/`_completePayment`, DB may show `paid` (server webhook) but **sessions may be missing** until the app runs webhook logic again or a **server-side job** is added (Phase 2 launch fix).

**Stale doc warning:** `ARCHITECTURE_VS_IMPLEMENTATION_ANALYSIS.md` (Jan 2025) states Fapshi webhooks “DO NOT EXIST” — **incorrect as of 2026-05-16**. Update that doc in a later housekeeping pass.

---

## 6. Learner pay path — traced

```
Tutor approves
  → BookingService.approveBookingRequest (booking_service.dart ~771)
      → PaymentRequestService.createPaymentRequestOnApproval
      → RecurringSessionService.createRecurringSessionFromBooking (on approval; sessions after pay)
  → Student: request_detail / my_requests → Pay Now
  → booking_payment_screen
      → FapshiService.initiateDirectPayment(externalId: payment_request_{id})
      → PaymentConfirmationScreen poll → _completePayment
      → PaymentRequestService.updatePaymentRequestStatus('paid')
      → FapshiWebhookService.handleWebhook(SUCCESS, payment_request_{id})
          → generate individual_sessions, link recurring_session_id
  Parallel: Fapshi → POST /api/webhooks/fapshi → payment_requests paid (no session generation)
```

**Trial:** `BookingService.approveTrialRequest` + trial payment screens; `externalId: trial_{id}`.

**Join gating (representative):**

- `request_detail_screen.dart`: paid + approved + not expired → join/actions.  
- `my_sessions_screen.dart`: `isPaid` + approved + `canJoin` time/window.  
- Online → `AgoraVideoSessionScreen`; onsite → start/end flows in `tutor_sessions_screen.dart` (not Agora).

---

## 7. Tutor money path — traced

### Fee model (verified in code)

| Component | Rule | Source |
|-----------|------|--------|
| Session fee | `monthly_total / (frequency * 4)` | `session_payment_service.dart`, `session_lifecycle_service.dart` |
| Platform fee | **15%** of session fee only | Same |
| Tutor session share | **85%** of session fee | Same |
| Transportation | 100% to tutor; **no** platform fee on transport | Onsite `transportation_cost` |

### Lifecycle

```
Session completes
  → SessionPaymentService.createSessionPayment / session_lifecycle earnings insert
  → tutor_earnings.earnings_status = 'pending'
Learner pays session (if unpaid)
  → externalId session_{id} → webhook marks session_payments paid
Cron (24h QA)
  → PrepSkul_Web/app/api/cron/process-pending-earnings
  → pending → active (barring flags/complaints)
Tutor withdraws
  → TutorPayoutService.requestPayout (min 5,000 XAF, marks earnings paid_out)
  → Admin: POST /api/payouts/process → Fapshi disburse API
```

**Payout externalId:** `payout_{payoutRequestId}` (server only; not in Fapshi collection webhook router).

---

## 8. Gaps vs existing plans

### vs `PRE_LAUNCH_PRIORITY_PLAN.md` (Jan 2025)

| Plan item | Audit status |
|-----------|----------------|
| Payment request on approval | **Implemented** — `createPaymentRequestOnApproval` + `payment_request_amounts.dart`; see `docs/LAUNCH_PAYMENTS_E2E.md` |
| Fapshi webhook integration | **Partial** — Next.js route exists; **session generation after pay is client-side only** |
| Payment status UI | **Implemented** — multiple screens; accuracy pass still needed (Phase 5) |
| Session start/end, Meet generation | **Partial** — Agora for in-app online; Meet still used for some trials/webhook paths |
| Session payment + 85/15 split | **Implemented** |
| QA pending → active | **Implemented** — cron route exists; verify Vercel cron schedule in prod |
| Feedback / attendance / points | **Partial** — not all blocking if cron + tutor check-in sufficient for v1 |

### vs `PAYMENT_FLOW_IMPLEMENTATION_SUMMARY.md`

| Item | Audit status |
|------|----------------|
| Environment `isProduction` precedence | **Implemented** in `app_config.dart` |
| MTN/Orange UI / instructions | **Implemented** |
| RLS migration `038_user_credits_system.sql` | **Unverified** — checklist still `[ ]` in summary doc |
| Production verification checklist | **Not run** in this audit — manual required |
| Credits / SkulMate pay paths | Out of launch scope unless SkulMate on |

### New gaps (not in older docs)

1. **Dual webhook processors** — server marks paid; Flutter must run for `individual_sessions` after `payment_request_` pay.  
2. ~~**`GROUP_CLASSES_ENABLED` defaults true**~~ — **fixed Phase 1** (Flutter + Web default `false`).  
3. **`isProduction = false`** in repo — RC must flip + verify Vercel/Flutter env.  
4. **Manual classroom QA** — `session_screenshare_qa_matrix.md` checkboxes still open.  
5. **`ARCHITECTURE_VS_IMPLEMENTATION_ANALYSIS.md`** — webhook section outdated.  
6. **Payout flow** — tutor request may mark earnings `paid_out` before admin disburse succeeds — verify failure rollback (Phase 2e).  
7. **handleByTransactionId fallback** for `session_` passes `sessionPayment.id` not `session_id` — edge-case risk if fallback path used.

---

## 9. Verified vs assumed

| Item | Status |
|------|--------|
| `PrepSkul_Web/app/api/webhooks/fapshi/route.ts` exists | **Verified** (read 2026-05-16) |
| externalId patterns trial_ / payment_request_ / session_ | **Verified** (Flutter + Next.js align) |
| `payment_request_` idempotency on Next.js | **Verified** in source |
| Flutter initiates pay with correct externalIds | **Verified** `booking_payment_screen.dart`, `session_payment_service.dart` |
| 15% platform fee logic | **Verified** in session payment + lifecycle services |
| Payout API route | **Verified** `PrepSkul_Web/app/api/payouts/process/route.ts` |
| Pending earnings cron | **Verified** file exists; **Assumed** scheduled in Vercel |
| Fapshi dashboard webhook URL points to production | **Assumed** — must confirm manually |
| End-to-end sandbox pay → join → earn → withdraw | **Assumed** — requires Phase 2/6 runbook execution |
| `individual_sessions` created if app killed after USSD pay | **Assumed failure risk** — needs test |
| RLS / credits migration applied | **Assumed** — not checked against live DB |
| Agora classroom manual matrix | **Assumed** partial — code fixes landed; manual PASS not recorded |

---

## 10. Related documents

| Doc | Use |
|-----|-----|
| `session_screenshare_qa_matrix.md` | P0-E online classroom manual QA |
| `PRE_LAUNCH_PRIORITY_PLAN.md` | Historical priority (partially done) |
| `PAYMENT_FLOW_IMPLEMENTATION_SUMMARY.md` | UI/env payment notes |
| `WEBHOOK_AND_SESSION_ARCHITECTURE.md` | Webhook URL reference (verify against §5) |
| `ONSITE_SESSION_TRACKING_IMPROVEMENTS_PLAN.md` | Post-v1 onsite depth |
| `P2_RC_UAT_ROLLBACK_MONITORING.md` | RC/UAT after P0 green |
| `PREPSKUL_CLASSROOM_SRS.md` | Online classroom requirements |

---

## 11. Next implementation phases (Cursor)

| Phase | Focus | Prompt location |
|-------|--------|-----------------|
| 1 | Flag defaults (`GROUP_CLASSES_ENABLED=false`) | **Done** (Phase 1) |
| 2 | Payments E2E + server-side session generation after pay | Launch plan Phase 2 |
| 3 | Online 1:1 manual QA matrix | Launch plan Phase 3 |
| 4 | Onsite 1:1 minimal | Launch plan Phase 4 |
| 5 | Session/payment UI accuracy | Launch plan Phase 5 |
| 6 | `LAUNCH_E2E_RUNBOOK.md` | Launch plan Phase 6 |
| 7 | RC / UAT | Launch plan Phase 7 |

---

## 12. Phase 0 operational checklist (manual vs audit)

| # | Item | Status (2026-05-16) | Evidence / next step |
|---|------|---------------------|----------------------|
| 1 | Webhook URL in Fapshi dashboard matches deployed route | **Not confirmed** | Deployed route responds at **`https://www.prepskul.com/api/webhooks/fapshi`** (POST → `400` + `Missing required fields: transId, status, externalId`). **`https://app.prepskul.com/api/webhooks/fapshi` serves Flutter HTML — wrong host.** You must open Fapshi dashboard and confirm URL is `www`, not `app`. |
| 2 | Sandbox payment E2E + Vercel log `🔔 Fapshi webhook received` | **Not confirmed** | Requires real sandbox pay + Vercel project access. Code path exists; not executed in this audit. |
| 3 | Known failures from `session_screenshare_qa_matrix.md` | **Documented** | See §12.1 below. Manual PASS/FAIL not recorded (all matrix checkboxes still open). |

### 12.1 Known session QA failures / open items (from matrix)

**Pre-fix baseline (2026-05-16)**

| Issue | Notes |
|-------|--------|
| Tutor desktop full-width cards | Reported before Z-layout batch; code claims fixed — **manual verify open** |

**Post-fix — code landed, manual Chrome 2-user verify still required**

| Issue | Manual verify |
|-------|----------------|
| Tutor desktop Z layout (Home, Requests, Sessions, Profile ≥1200px) | [ ] |
| Teaching tools visible in 1:1 (Board panel) | [ ] |
| Web screen share (content + faces, not black stage) | [ ] |
| Participant left UI (`Learner left`, no waiting spinner) | [ ] |
| Recovery/QoE rows 37–48 | [ ] |

**Full matrix (rows 16–54)** — core screen share, workspace, recovery, network: **all unchecked**; treat as **not signed off** for launch until Phase 3 run.

**Phase 0 code audit:** complete. **Phase 0 ops sign-off:** items 1–2 pending you; item 3 documented only.

---

*Phase 0 audit complete. No product code changed in this phase.*
