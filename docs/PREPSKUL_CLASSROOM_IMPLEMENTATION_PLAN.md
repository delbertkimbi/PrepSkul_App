# PrepSkul Classroom Implementation Plan

Owner: Engineering  
Contributors: Product, Design, QA, Data  
Status: Draft v1  
Scope: Flutter app + Agora RTC + Supabase + Next.js APIs

## Goal

Upgrade live sessions from a 1:1 MVP call flow into a production-grade classroom experience that remains stable under weak and fluctuating network conditions.

## Current Baseline

- Join flow works.
- Camera and microphone preview works.
- Live audio/video connection works.
- Basic screenshare exists.
- Existing session UI logic still heavily assumes one remote participant.
- Existing event handlers can trigger fast UI changes under unstable network.

## Design Principles

- Audio-first reliability over video sharpness.
- Domain-controlled UI projection (no direct raw RTC callback to UI transitions).
- Multi-participant first-class model.
- Tutor-first classroom ergonomics.
- Degradation should feel intentional, not broken.

## Target Architecture

### 1) RTC Adapter Layer

Create `RtcEngineAdapter` to isolate Agora SDK details:

- Join/leave/publish/subscribe.
- Encoder and dual-stream configuration.
- Expose normalized `RtcEvent` stream.
- Zero direct UI logic.

### 2) Orchestration Layer

Create `ClassroomOrchestrator`:

- Consumes `RtcEvent`.
- Runs state machine + policy engine.
- Emits stable `ClassroomState`.
- Applies debounce and hysteresis before UI-impacting state transitions.

### 3) Participant Registry

Replace single remote UID mindset with:

- `Map<int, ParticipantState> participants`
- Roles: tutor, learner, observer.
- Media state per participant: audio/video/speaking/screenshare/network.

### 4) Quality Policy Engine

Introduce `QualityController`:

- Aggregates packet loss, RTT, freeze events, bitrate trends.
- Tiers: `good`, `constrained`, `poor`.
- Controls stream profile, local encoder settings, and remote stream type selection.

### 5) UI Projection Layer

UI widgets consume a derived `ClassroomViewState`:

- Main stage tile, grid tiles, banners, overlays.
- No direct mutation from Agora callbacks.

## Session State Machine

`idle -> prejoin_check -> joining -> connected -> degraded -> reconnecting -> resumed -> ending -> ended | failed`

Rules:

- Do not instantly remove participant tile on transient disconnect.
- Keep frozen/placeholder tile with reconnect overlay for grace window.
- Escalate messaging over time (silent retry, reconnecting banner, stronger warning).

## Data and API Requirements

### Database

Use `session_participants` as classroom membership extension:

- Support tutor + multiple learners + optional observer roles.
- Keep legacy `individual_sessions` and `trial_sessions` compatibility.

### Token Authorization

Agora token API must allow if user is:

- legacy participant (`tutor_id`, `learner_id`, `parent_id`) OR
- member of `session_participants`.

## Implementation Phases

## Phase 1: Stabilize Core (1-3 days)

- Add orchestrator and session state machine.
- Route RTC callbacks through orchestrator.
- Add explicit UI states: joining, connected, degraded, reconnecting, resumed, ended.
- Introduce participant map in memory while preserving existing screens.

Deliverable:

- No abrupt UI collapse on transient network drops.

## Phase 2: Classroom Media Control (1 week)

- Enable dual-stream mode.
- Add stream selection policy:
  - Tutor/active speaker high stream.
  - Non-focused participants low stream.
- Add quality tiering with hysteresis windows.

Deliverable:

- Lower stutter and improved continuity with 3-6 participants.

## Phase 3: UX and Tooling (1 week)

- Reconnection overlay flow.
- Degraded network banners with calm wording.
- Screen share ownership and pinned stage behavior.
- Session telemetry events to Supabase (`session_qoe_events`).

Deliverable:

- Predictable classroom UX and measurable QoE data.

## Phase 4: Classroom Productization (later)

- Hand raise, chat moderation, tutor control strip.
- Whiteboard/annotation workflows.
- Attendance and engagement analytics.

## Engineering Tasks

### Flutter

- Add `lib/features/sessions/domain/` for state machine/reducers.
- Add `lib/features/sessions/rtc/` for adapter.
- Refactor `agora_video_session_screen.dart` to consume view state.

### Next.js

- Ensure token route and role resolution support `session_participants`.
- Add structured response fields for client-side policy decisions if needed.

### Supabase

- Apply `076_classroom_session_participants.sql`.
- Add QoE events table migration.

## QA Plan

- Test matrix:
  - 1:1 baseline parity.
  - 1 tutor + 2 learners.
  - 1 tutor + 4 learners.
  - forced network degradation and recovery.
- Validate no tile flicker under packet loss spikes.
- Validate reconnect grace behavior and state transitions.

## Risks and Mitigations

- Risk: Regression to existing 1:1 flow.
  - Mitigation: Keep compatibility mode path and dedicated smoke suite.
- Risk: Overreactive quality switching.
  - Mitigation: Hysteresis + min dwell duration for each tier.
- Risk: UI complexity growth.
  - Mitigation: Strict separation of domain state and presentation state.

## Success Metrics

- Reduced video freeze frequency per session.
- Reduced reconnect-related call drops.
- Improved session completion rate.
- Fewer support tickets tagged as video instability.

