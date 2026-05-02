# PrepSkul Classroom Execution Backlog

Owner: Engineering  
Status: Ready for execution  
Scope: Flutter + Agora + Supabase + Next.js  
Reference docs: `PREPSKUL_CLASSROOM_IMPLEMENTATION_PLAN.md`, `PREPSKUL_CLASSROOM_SRS.md`

---

## Epic 1: Classroom Session Architecture Stabilization

### Story 1.1: Introduce RTC Adapter Boundary

**Goal:** Isolate Agora SDK operations from UI and business logic.

**Subtasks**
- Create `lib/features/sessions/rtc/agora_adapter.dart`.
- Move join/leave/publish/subscribe operations from screen/service into adapter.
- Normalize Agora callbacks into typed domain events (`RtcEvent` union/classes).
- Add adapter unit tests for event emission and error propagation.

**Definition of Done**
- No UI widget directly calls Agora engine methods.
- All media operations pass through adapter.
- Existing 1:1 flow still works with adapter in place.

### Story 1.2: Add Classroom Orchestrator

**Goal:** Centralize state transitions for session lifecycle.

**Subtasks**
- Create `lib/features/sessions/domain/classroom_orchestrator.dart`.
- Implement state machine: `idle -> prejoin_check -> joining -> connected -> degraded -> reconnecting -> resumed -> ending -> ended|failed`.
- Add event reducer to transform `RtcEvent` into `ClassroomState`.
- Add tests for all lifecycle transitions.

**Definition of Done**
- Session status no longer derived ad hoc in UI.
- All status transitions are deterministic and test-covered.

### Story 1.3: Participant Registry (multi-user source of truth)

**Goal:** Replace single remote UID model with participant map.

**Subtasks**
- Add `ParticipantState` model and `Map<int, ParticipantState>`.
- Refactor join/leave/video/audio/speaking updates to target participant entries.
- Keep compatibility path for 1:1 layout while map-based model is adopted.
- Add tests for participant add/update/remove with grace windows.

**Definition of Done**
- No critical flow depends on a single `_remoteUID`.
- Multi-participant state can be represented without UI collapse.

---

## Epic 2: Network Resilience and Adaptive Media Quality

### Story 2.1: Quality Policy Engine

**Goal:** Introduce policy-driven quality adaptation with hysteresis.

**Subtasks**
- Create `lib/features/sessions/domain/quality_controller.dart`.
- Define quality tiers: `good`, `constrained`, `poor`.
- Implement hysteresis windows and minimum dwell time per tier.
- Feed controller with network metrics (loss/RTT/bitrate/freeze signals).

**Definition of Done**
- Quality transitions do not oscillate rapidly under noisy conditions.
- Tier changes are observable via logs and telemetry.

### Story 2.2: Dual Stream + Spotlight Switching

**Goal:** Improve classroom continuity by stream prioritization.

**Subtasks**
- Enable dual-stream mode in adapter.
- Configure encoder profiles by quality tier.
- Implement stream type switching policy:
  - tutor/spotlight/high-priority -> high stream
  - background participants -> low stream
- Add integration checks for 3+ participants.

**Definition of Done**
- High/low stream switching is policy-driven and stable.
- CPU/bandwidth load reduced for multi-participant sessions.

### Story 2.3: Reconnection Grace Policy

**Goal:** Preserve UX continuity during temporary disconnects.

**Subtasks**
- Add reconnect grace timer per participant.
- Keep tile with reconnecting overlay before removal timeout.
- Escalate UI messaging by elapsed reconnect duration.
- Add test scenarios for transient vs definitive leave.

**Definition of Done**
- Temporary disconnect no longer causes immediate tile disappearance.
- Rejoin within grace window restores participant seamlessly.

---

## Epic 3: Classroom UX and Teaching Experience

### Story 3.1: Stable Session State UX

**Goal:** Make network/session conditions understandable and calm.

**Subtasks**
- Add UI states for joining, degraded, reconnecting, resumed, ended.
- Add top banner/chip with concise state copy.
- Add minimum display durations to prevent flicker.
- Validate dark/light status bar contrast on key classroom screens.

**Definition of Done**
- Users can always tell what state the classroom is in.
- No visual thrashing during short network events.

### Story 3.2: Classroom Layout System

**Goal:** Support tutor-first stage + participant grid.

**Subtasks**
- Build layout manager (spotlight + grid + screenshare stage).
- Add spotlight pin logic and active-speaker fallback.
- Keep local preview/pip stable during layout changes.
- Add responsive behavior for smaller devices.

**Definition of Done**
- Layout remains stable when participants join/leave.
- Tutor and content remain prioritized.

### Story 3.3: Screenshare Reliability Upgrade

**Goal:** Make screenshare predictable in classroom conditions.

**Subtasks**
- Enforce share owner state in orchestrator.
- Add share start/stop transitions with explicit UI cues.
- Add fallback behavior when share stream degrades.
- Add QA flows for handoff and interrupted share.

**Definition of Done**
- Screenshare state is consistent across participants.
- No orphaned share UI after interruption.

---

## Epic 4: Data, Authorization, and APIs

### Story 4.1: Participant Authorization Completion

**Goal:** Make classroom membership first-class in APIs.

**Subtasks**
- Ensure migration `076_classroom_session_participants.sql` is applied in all environments.
- Verify token endpoint accepts legacy participants and `session_participants` members.
- Add server-side role mapping for classroom roles.
- Add API tests for authorization matrix.

**Definition of Done**
- Valid classroom members can join successfully.
- Unauthorized users are blocked with clear errors.

### Story 4.2: Enrollment Pipeline

**Goal:** Ensure multi-learner bookings create classroom membership rows.

**Subtasks**
- Define enrollment insertion path (booking flow or service function).
- Insert learner participants by user id, not only learner labels.
- Add idempotency guard for duplicate inserts.
- Add admin/backfill script for existing eligible sessions.

**Definition of Done**
- Multi-learner bookings map to actual joinable classroom participants.
- No manual participant insertion is required for normal flow.

---

## Epic 5: QoE Observability and Operational Readiness

### Story 5.1: Session QoE Telemetry

**Goal:** Capture diagnostics needed for production tuning.

**Subtasks**
- Add migration for `session_qoe_events` table.
- Emit events from orchestrator:
  - quality tier changes
  - reconnect attempts/outcomes
  - stream switch actions
  - freeze/decode interruptions
- Add correlation ids per live session.

**Definition of Done**
- Every live session yields traceable QoE event timeline.
- Data is queryable for incident analysis.

### Story 5.2: QA Reliability Suite

**Goal:** Create repeatable pass/fail quality gates.

**Subtasks**
- Build classroom smoke checklist (1:1, 1:3, 1:5 scenarios).
- Add scripted network degradation tests (loss, latency, jitter spikes).
- Define release gate thresholds (max reconnect failures, freeze rate).
- Publish triage workflow for regressions.

**Definition of Done**
- Release candidates must pass classroom reliability gate before shipping.

---

## Cross-Cutting Engineering Tasks

- Add feature flags:
  - `classroom_orchestrator_enabled`
  - `classroom_dual_stream_enabled`
  - `classroom_qoe_telemetry_enabled`
- Preserve fallback path to current 1:1 behavior until full rollout confidence.
- Add migration and rollback notes to release checklist.

---

## Suggested Sprint Breakdown

### Sprint 1 (Stabilization)
- Epic 1 stories 1.1, 1.2, 1.3
- Epic 3 story 3.1

### Sprint 2 (Adaptive Quality + UX)
- Epic 2 stories 2.1, 2.2, 2.3
- Epic 3 story 3.2

### Sprint 3 (Data + Ops Readiness)
- Epic 3 story 3.3
- Epic 4 stories 4.1, 4.2
- Epic 5 stories 5.1, 5.2

---

## Dependencies and Blockers

- iOS simulator runtime availability (local dev environment).
- Supabase migration rollout order and environment parity.
- QA access to controlled network throttling tools.

---

## Delivery Checkpoint Criteria

- Checkpoint A: Session state machine live behind feature flag.
- Checkpoint B: Dual-stream + quality policy validated with 3+ participants.
- Checkpoint C: Authorization + enrollment pipeline complete.
- Checkpoint D: QoE telemetry and release reliability gate active.

