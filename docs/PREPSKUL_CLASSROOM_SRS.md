# PrepSkul Classroom SRS (v1)

Document Type: Software Requirements Specification  
Version: 1.0 (Draft)  
Date: 2026-04-19  
Product: PrepSkul Live Classroom

## 1. Introduction

## 1.1 Purpose

Define functional and non-functional requirements to evolve PrepSkul live sessions from 1:1 MVP behavior into a production-grade classroom system.

## 1.2 Scope

This SRS covers:

- Flutter client classroom behavior and UX.
- Agora real-time media configuration and adaptation.
- Supabase data access and participant authorization.
- Next.js token and session API behavior.

## 1.3 Definitions

- Classroom session: one tutor with one or more learners in one live room.
- QoE: Quality of Experience metrics captured during sessions.
- Degraded network: sustained poor network where quality adaptation is required.

## 2. Product Overview

- Existing system supports basic live session join and media publishing.
- Existing UX remains closer to raw call behavior than classroom workflow.
- New architecture must provide stable, controlled state transitions.

## 3. Functional Requirements

## 3.1 Session Access and Authorization

- FR-001: System shall authorize live join for legacy participants (`tutor_id`, `learner_id`, `parent_id`).
- FR-002: System shall authorize live join for members listed in `session_participants`.
- FR-003: System shall reject join requests from non-participants with explicit error feedback.

## 3.2 Session Lifecycle

- FR-004: System shall implement explicit lifecycle states:
  - joining, connected, degraded, reconnecting, resumed, ended, failed.
- FR-005: Client UI shall render state-appropriate overlays and banners.
- FR-006: System shall persist session end transitions even after network interruptions.

## 3.3 Participant Model

- FR-007: System shall support multiple remote participants in one room.
- FR-008: System shall maintain per-participant media state:
  - video enabled, audio enabled, speaking, screen sharing, connection status.
- FR-009: UI shall not depend on a single remote UID for classroom rendering.

## 3.4 Media and Adaptation

- FR-010: System shall enable dual-stream mode for classroom sessions.
- FR-011: System shall select high stream for tutor/spotlight participant and low stream for others.
- FR-012: System shall apply network quality tiering (`good`, `constrained`, `poor`).
- FR-013: System shall apply hysteresis to prevent frequent oscillation between tiers.
- FR-014: System shall prioritize audio continuity over video quality under degradation.

## 3.5 Reconnection Behavior

- FR-015: System shall not immediately remove participant tile on transient disconnect.
- FR-016: System shall show reconnecting state during grace window.
- FR-017: System shall remove participant only after timeout and confirmation rules.

## 3.6 Classroom UX

- FR-018: System shall support tutor-first stage layout with participant grid.
- FR-019: System shall support stable screen-sharing presentation with clear ownership.
- FR-020: System shall expose minimum classroom interaction affordances:
  - reactions, session state messaging, participant visibility.

## 3.7 Telemetry

- FR-021: System shall log QoE events per session:
  - reconnect attempts, tier transitions, freeze windows, stream switches.
- FR-022: System shall persist telemetry for operational analysis.

## 4. Non-Functional Requirements

## 4.1 Reliability

- NFR-001: Client shall recover from short network interruptions without full session reset where possible.
- NFR-002: UI shall remain visually stable during transient RTC events.

## 4.2 Performance

- NFR-003: Participant grid updates shall avoid full-screen rebuild on single participant change.
- NFR-004: Quality adaptation decisions shall not execute more frequently than policy cadence.

## 4.3 Usability

- NFR-005: Users shall always see clear session status feedback.
- NFR-006: Reconnect messaging shall escalate progressively, not abruptly.

## 4.4 Maintainability

- NFR-007: RTC SDK calls shall be isolated in adapter layer.
- NFR-008: UI widgets shall consume derived view state rather than raw RTC callbacks.

## 5. System Architecture Requirements

- AR-001: Introduce `RtcEngineAdapter` abstraction.
- AR-002: Introduce `ClassroomOrchestrator` domain layer.
- AR-003: Introduce `ParticipantState` registry map.
- AR-004: Introduce `QualityController` policy engine.
- AR-005: Introduce `ClassroomViewState` projection for presentation layer.

## 6. External Interface Requirements

## 6.1 API Interface

- API-001: Token endpoint shall return token, channel name, uid, role, expiry.
- API-002: Access validation shall include `session_participants` membership checks.

## 6.2 Data Interface

- DB-001: `session_participants` shall support participant roles and session linkage.
- DB-002: QoE table (new migration) shall store per-session quality events.

## 7. Acceptance Criteria

- AC-001: Classroom session with tutor + 3 learners joins successfully.
- AC-002: Under induced packet loss, system downgrades gracefully without abrupt UI collapse.
- AC-003: Temporary disconnect under grace threshold shows reconnecting state and recovers.
- AC-004: Spotlight participant retains high stream while non-spotlight participants use low stream.
- AC-005: QoE events are recorded and queryable after each session.

## 8. Out of Scope (v1)

- Advanced whiteboard collaboration.
- Breakout rooms.
- AI-generated live moderation.

## 9. Traceability Matrix (Initial)

- FR-010 to FR-014 -> Agora adapter + quality policy engine.
- FR-015 to FR-017 -> Orchestrator reconnect state machine.
- FR-021 to FR-022 -> QoE event pipeline and Supabase storage.
- AC-001 to AC-005 -> QA classroom reliability suite.

## 10. Rollout Notes

- Start with feature flag for classroom mode.
- Preserve 1:1 compatibility during migration.
- Enable classroom gradually by cohort and monitor QoE dashboards.

