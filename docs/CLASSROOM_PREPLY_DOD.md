# Classroom / Preply-parity — Definition of Done

**Product parity & UX roadmap** (Preply references, responsive strategy, P0/P1 gaps): see [`PREPLY_PARITY_AND_UX_ROADMAP.md`](PREPLY_PARITY_AND_UX_ROADMAP.md).  
**Help Center distilled → core backlog + responsive matrix:** [`PREPLY_CLASSROOM_CORE_FEATURES_SPEC.md`](PREPLY_CLASSROOM_CORE_FEATURES_SPEC.md).

This document ties **features** to **automated checks** and **manual evidence** so releases stay accountable. Automated guards live under `test/features/sessions/*dod*test.dart`.

## Automated verification (CI)

Run locally:

```bash
cd prepskul_app
flutter test test/features/sessions/classroom_workspace_dod_test.dart \
  test/features/sessions/preply_classroom_dod_test.dart \
  test/features/sessions/phase_c_dod_validation_test.dart \
  test/features/sessions/rollout_flags_guard_test.dart \
  test/features/sessions/workspace_sync_state_test.dart \
  test/features/sessions/classroom_workspace_indexed_stack_test.dart \
  test/features/sessions/session_mode_statistics_service_test.dart
```

| Milestone | What is guarded | Primary tests |
|-----------|-----------------|----------------|
| Dual-pane shell + workspace | IndexedStack, dual-pane width, realtime flag | `phase_c_dod_validation_test`, `rollout_flags_guard_test`, `classroom_workspace_dod_test` |
| Realtime workspace bridge | Channel name, broadcast, tutor auth, `subscribe()` | `classroom_workspace_dod_test` |
| Whiteboard + reducer | `SCROLL_TO`, `STROKE_PATH`, `reduceWorkspace` | `workspace_sync_state_test` |
| PDF/notes scroll sync | Tutor `ScrollToPacket`, learner `_followRemoteScroll` | `preply_classroom_dod_test`, `classroom_workspace_indexed_stack_test` |
| Prejoin readiness | Checklist + `DeviceReadinessService` | `preply_classroom_dod_test` |
| Talk-time QoE | `talk_time_summary` + statistics service | `preply_classroom_dod_test`, `session_mode_statistics_service_test` |
| Audio-only fallback (Meet-style) | Camera never reaches capturing/encoding → one-time SnackBar; QoE `audio_only_fallback_*` | Code: `enableClassroomAudioOnlyFallback`, `localCameraPublishingSignalStream` |
| Tutoring audio profile | `CLASSROOM_AUDIO_PROFILE_MODE`, `_applyTutoringAudioProfile`, `audio_profile_selected` | `preply_classroom_dod_test` |
| Recovery / failover UX | Banner, heartbeat peer beats, QoE event names | `preply_classroom_dod_test` |
| Chat → vocabulary | `addWordToVocabularyDeck` wiring | `preply_classroom_dod_test`, `chat_service_test` |

## Manual evidence (must attach for release sign-off)

These require a running app, two devices or browsers, and optionally Supabase dashboard access. Capture **screenshots** and **redacted logs** (session id only).

| ID | Scenario | Evidence to capture |
|----|-----------|---------------------|
| `qoe-web-02-two-party-proof` | Web Chrome, two parties | Connect time, first remote frame, mic/camera toggles stable; console excerpt without secrets |
| `feedback-01-live-submit-proof` | Post-session feedback | Successful submit UI + network 200 (or Supabase row) for `session_feedback` path used in prod |
| `credits-01-live-parity-proof` | Student My Sessions vs Credits | Same points for paid upcoming sessions × rule (e.g. ×10); both screens in one capture |
| `chat-01-live-message-proof` | Message Tutor entry points | Trial / individual / recurring each opens correct thread (deep link or conversation id in debug overlay) |
| `home-01-alltime-progress-metrics` | Student home | All-time counters match API; toggle airplane mode shows cache fallback once (if applicable) |
| `meet-12-parity-qa-matrix` | Meet comparison | Short matrix: jitter handling, reconnect, 6-up gallery, screen-share stage — screenshot each |

**QoE database checks (optional but strong):** query `session_qoe_events` for correlation id patterns `audio_profile_selected`, `talk_time_summary`, `classroom_recovery_mode_*` during a supervised call.

## Configuration reference

| Env / flag | Purpose |
|------------|---------|
| `CLASSROOM_WORKSPACE_REALTIME_ENABLED` | Workspace Realtime sync |
| `CLASSROOM_QOE_TELEMETRY_ENABLED` | Inserts into `session_qoe_events` |
| `CLASSROOM_DUAL_STREAM_ENABLED` | Dual-stream policy |
| `CLASSROOM_AUDIO_PROFILE_MODE` | `speech` \| `balanced` \| `music` \| `ab` |
| `CLASSROOM_BACKUP_CALL_URL` | Optional Meet/Zoom link for recovery banner “Backup” |
| `CLASSROOM_AUDIO_ONLY_FALLBACK_ENABLED` | If local camera never reaches Agora capturing/encoding within ~18s after join, offer one-time “Audio only” (default on) |

## Teaching-platform roadmap (architecture priority)

**Priority:** State-sync workspace (PDF / whiteboard over Realtime + local render) **before** relying on pixel-only screen share for teaching materials. Keep Agora screen share as **fallback** for apps that cannot be modeled as assets + vectors.

**Hybrid RTC fallback:** When Realtime or workspace is unhealthy, recovery banner + backup link + support path (already wired in session screen).

## Sign-off checklist (release owner)

- [ ] All **Automated verification** tests green on CI / local.
- [ ] Manual rows above filled with dated evidence folder or ticket links.
- [ ] No open P0 bugs on session join/leave on Web + Android smoke paths.
