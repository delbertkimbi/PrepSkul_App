# Video Feature Ground-Up Execution Plan (v2)

Owner: Engineering  
Contributors: Product, Design, QA, Data  
Status: Ready for execution  
Date: 2026-04-24

## 1) Objective

Deliver a production-grade PrepSkul classroom experience that is:
- stable on weak/fluctuating networks,
- simple and predictable for tutors and learners,
- observable with actionable QoE telemetry,
- released safely behind feature flags.

## 2) Source Documents Reviewed

- `PREPSKUL_CLASSROOM_IMPLEMENTATION_PLAN.md`
- `PREPSKUL_CLASSROOM_EXECUTION_BACKLOG.md`
- `PREPSKUL_CLASSROOM_SRS.md`
- `VIDEO_EXPERIENCE_ASSESSMENT.md`
- `AGORA_ERROR_LOGGING_IMPROVEMENTS.md`

## 3) Ground-Up Scope (What we build first)

This plan prioritizes reliability and clarity over feature breadth.

### In Scope (v2 rollout)
- Session lifecycle state machine and orchestrator
- Multi-participant participant registry
- Dual-stream + adaptive quality policy with hysteresis
- Reconnection grace behavior and calm state UI
- Token/session authorization parity (`session_participants` + legacy fields)
- Enrollment pipeline for classroom participants
- QoE telemetry pipeline + release reliability gate

### Out of Scope (later)
- Whiteboard, breakout rooms, live AI moderation
- Full chat system and captions
- Heavy visual effects that risk performance regression

## 4) Execution Sequence (No parallel confusion)

## Phase A: Architecture Foundation (Sprint 1, Week 1)

### A1. RTC adapter boundary
- Implement `RtcEngineAdapter` under `lib/features/sessions/rtc/`
- Route all join/leave/publish/subscribe and callback normalization through adapter
- Remove direct Agora SDK calls from UI widgets

### A2. Classroom orchestrator + state machine
- Implement `ClassroomOrchestrator` under `lib/features/sessions/domain/`
- Canonical states: `idle -> prejoin_check -> joining -> connected -> degraded -> reconnecting -> resumed -> ending -> ended|failed`
- Add deterministic reducer tests for transition coverage

### A3. Participant registry
- Replace single remote UID assumptions with `Map<int, ParticipantState>`
- Support per-participant audio/video/speaking/screenshare/network fields
- Keep 1:1 compatibility path while migrating rendering

Exit Criteria:
- No abrupt screen collapse on transient network drops
- No core flow depends on single remote UID

## Phase B: Network Resilience and Quality Policy (Sprint 1-2, Week 2)

### B1. Quality controller
- Implement quality tiers: `good`, `constrained`, `poor`
- Use packet loss, RTT, bitrate trends, freeze/decode signals
- Add hysteresis + minimum dwell time to prevent oscillation

### B2. Dual-stream and stream selection policy
- Enable dual stream for classroom sessions
- Keep tutor/spotlight in high stream, others low stream
- Validate stable switching for 3 to 6 participants

### B3. Reconnection grace policy
- Keep participant tile during grace window
- Add reconnect overlay and escalating messages by elapsed time
- Remove tile only after definitive timeout rules

Exit Criteria:
- Quality switching is stable and visible in logs
- Rejoin within grace window restores tile seamlessly

## Phase C: UX Stabilization (Sprint 2, Week 3)

### C1. Stable session state UX
- Standard banners/chips for joining, degraded, reconnecting, resumed
- Minimum display durations to avoid UI flicker
- Tutor-first stage + predictable participant grid behavior

### C2. Screenshare reliability
- Explicit share ownership in orchestrator
- Correct start/stop transitions and fallback behavior
- No orphaned share UI after interruptions

### C3. Brand and polish pass (quick wins)
- Bring PrepSkul brand tones to control/status affordances
- Smooth transitions without adding heavy animation cost
- Keep clarity and accessibility as priority

Exit Criteria:
- Users can always understand class/session state
- Visual behavior feels intentional under instability

## Phase D: Data, Authorization, and Observability (Sprint 3, Week 4)

### D1. Authorization parity
- Ensure token endpoint validates legacy and `session_participants` membership
- Add API tests for authorized/unauthorized matrix

### D2. Enrollment pipeline completion
- Ensure bookings create `session_participants` entries idempotently
- Add backfill path for existing sessions

### D3. QoE telemetry
- Add/verify `session_qoe_events` migration
- Emit events for tier changes, reconnect outcomes, stream switches, freezes
- Add correlation id per live session

Exit Criteria:
- Every session has traceable QoE event timeline
- Classroom join failures are diagnosable within minutes

## 5) Feature Flags and Safe Rollout

Required flags:
- `classroom_orchestrator_enabled`
- `classroom_dual_stream_enabled`
- `classroom_qoe_telemetry_enabled`

Rollout path:
1. Internal testing cohort
2. 10% of eligible sessions
3. 50% cohort after stability gate
4. 100% once reliability thresholds are met

## 6) Reliability Gate (Release must pass)

Mandatory test matrix:
- 1:1 parity baseline
- 1 tutor + 2 learners
- 1 tutor + 4 learners
- induced degradation: packet loss, latency spikes, jitter bursts

Release thresholds (initial):
- reconnect failure rate below agreed threshold
- freeze events per session trending down week over week
- no critical regression in session completion rate

## 7) Workstream Ownership

- Flutter client: adapter, orchestrator, participant model, view state projection
- Backend (Next.js): token auth checks, role mapping, diagnostics
- Supabase: participant schema parity, telemetry storage, migration integrity
- QA: reliability matrix, scripted degradation suite, release signoff

## 8) Immediate Next 5 Tasks

1. Create adapter and orchestrator scaffolding with tests  
2. Refactor `agora_video_session_screen.dart` to consume derived classroom view state  
3. Implement participant map and remove single-UID assumptions  
4. Add quality controller with hysteresis and dual-stream policy wiring  
5. Stand up QoE event capture and dashboard queries

## 9) Definition of Success

- No more user-visible "video confusion" during join/reconnect cycles
- Session UX remains calm and understandable under poor network
- Multi-participant classrooms are stable by design, not best effort
- Engineering and support can diagnose issues quickly from telemetry

## 10) Implementation Progress and Evidence

### Phase C Status
- C1 Complete: stable state UX with minimum display durations for transient and reconnect states.
- C2 Complete: screen-share owner state enforced to prevent orphaned share UI after interruptions.
- C3 Complete: restrained glass/soft visual polish applied to banner and controls with high-contrast overlays.
- C Test + DoD Complete: baseline checks for no-flicker guards, touch-target sizing, and semantics coverage added.

### Phase C Evidence (tests)
- `test/features/sessions/session_state_ux_stability_test.dart`
- `test/features/sessions/screenshare_owner_transition_test.dart`
- `test/features/sessions/phase_c_dod_validation_test.dart`

### Definition of Done (Phase C) checklist
- [x] UX consistency implementation is aligned for mobile and desktop layouts.
- [x] Anti-flicker protections are implemented and covered by tests.
- [x] Accessibility baseline applied: semantic button labels and touch-target size >= 56.
- [x] Visual polish is restrained and avoids heavy effects that risk runtime performance.

### Phase D Status (current)
- D1 Complete: token authorization parity validated for legacy participants and `session_participants` membership.
- D2 Complete: booking/session generation now writes idempotent `session_participants` rows and includes a legacy backfill migration.
- D3 Complete: QoE telemetry pipeline added with `session_qoe_events`, per-session correlation IDs, and key Agora event emissions.
- D Test + DoD Complete: auth matrix, enrollment integrity, and telemetry pipeline validations are passing in targeted automated checks.

### Phase D Evidence (D1 auth matrix)
- `PrepSkul_Web/__tests__/agora/session-service-authz.test.ts`
- Validates:
  - legacy tutor access on individual sessions,
  - access via `session_participants` when not in legacy tutor/learner/parent columns,
  - trial-session parity via `session_participants`,
  - role mapping of `parent_observer` to learner-class RTC role,
  - deny path for non-members.

### Phase D Evidence (D2 enrollment + backfill)
- `prepskul_app/lib/features/booking/services/trial_session_service.dart`
  - writes/upserts `session_participants` rows for trial sessions and trial-created individual sessions.
- `prepskul_app/lib/features/booking/services/recurring_session_service.dart`
  - upserts `session_participants` rows for generated individual sessions.
- `prepskul_app/supabase/migrations/077_backfill_session_participants.sql`
  - idempotent backfill path for existing `individual_sessions` and `trial_sessions`.
- `prepskul_app/test/features/booking/session_participants_enrollment_test.dart`
  - validation tests for enrollment upsert hooks and migration presence.

### Phase D Evidence (D3 QoE telemetry)
- `prepskul_app/supabase/migrations/078_session_qoe_events.sql`
  - creates `session_qoe_events` table, indexes, and RLS policies.
- `prepskul_app/lib/features/sessions/services/qoe_telemetry_service.dart`
  - correlation-id generation + event writer for QoE events.
- `prepskul_app/lib/features/sessions/services/agora_service.dart`
  - emits telemetry for:
    - quality tier changes,
    - reconnect attempts/success/failure/exhaustion,
    - remote stream type switches,
    - remote freeze start/end.
- `prepskul_app/test/features/sessions/qoe_telemetry_pipeline_test.dart`
  - validates D3 emission hooks and migration presence.

### Phase D Test + DoD evidence
- API auth matrix:
  - `PrepSkul_Web/__tests__/agora/session-service-authz.test.ts`
- Enrollment integrity:
  - `prepskul_app/test/features/booking/session_participants_enrollment_test.dart`
- Telemetry schema + emission validation:
  - `prepskul_app/test/features/sessions/qoe_telemetry_pipeline_test.dart`
- Diagnostics readiness:
  - migration/index/RLS coverage in `prepskul_app/supabase/migrations/078_session_qoe_events.sql`.

## 11) Release Gate and Rollout Control Evidence

- Reliability gate checklist added: `docs/CLASSROOM_RELEASE_RELIABILITY_GATE.md`
- Reliability gate execution/query artifacts added:
  - `docs/CLASSROOM_RELEASE_RELIABILITY_GATE.md`
  - `docs/CLASSROOM_QOE_QUERY_CHECKS.sql`
- Rollout flag controls are now wired in config:
  - `CLASSROOM_ORCHESTRATOR_ENABLED`
  - `CLASSROOM_DUAL_STREAM_ENABLED`
  - `CLASSROOM_QOE_TELEMETRY_ENABLED`
- Dual-stream execution is guarded by `CLASSROOM_DUAL_STREAM_ENABLED` in `agora_service`.
- Guard tests:
  - `test/features/sessions/rollout_flags_guard_test.dart`

## 12) Group Classes Extension Addendum

Status: In implementation; core platform flows are now delivered.

Delivered:
- DB foundation:
  - `supabase/migrations/079_group_class_listings_and_enrollments.sql`
  - `supabase/migrations/080_group_class_share_tokens.sql`
- Backend APIs and authz:
  - create/update/publish/list/enroll group classes
  - join-token validation endpoint (`/api/group-classes/join/[token]`)
- Payment lifecycle:
  - paid enrollment finalization with session linking and `session_participants` upsert
- App flows:
  - tutor listing create/publish UI
  - learner class discovery + reserve seat CTA
  - deep-link join handling for `/join/class/:token`
  - My Sessions visibility for paid participant-enrolled class sessions
- Observability:
  - structured lifecycle logs for create/publish/enroll/idempotency paths

Execution artifacts:
- DoD and release checklist:
  - `docs/GROUP_CLASSES_EXECUTION_DOD.md`
- Runtime DB checks:
  - `docs/GROUP_CLASSES_DB_RUNTIME_CHECKS.sql`

Pending human gate items:
- live UAT matrix execution + evidence capture
- staged rollout signoff + support readiness confirmation

