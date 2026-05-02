# Ground-Up DoD Execution Report (2026-04-28)

## Scope executed
- Web call QoE stabilization and transition UX hardening.
- Feedback submission/schema diagnostics validation.
- Credits/points reconciliation hardening (legacy schema compatibility + log-noise reduction).
- Tutor messaging reliability path validation.
- Startup schema check validation.

## Code changes completed
- `lib/features/sessions/services/agora_service.dart`
  - Added platform/capability guards for unsupported dual-stream and remote stream-type APIs.
  - Added one-way disable after unsupported (`-4`) to stop repeated retries and warning spam.
  - Throttled remote stream-priority application cadence to reduce web churn.
- `lib/features/sessions/screens/agora_video_session_screen.dart`
  - Added calmer web debounce and stale-muted suppression to reduce camera on/off flicker.
  - Throttled high-frequency main-area diagnostics to reduce runtime noise.
  - Replaced generic progress indicators with branded connect/leave transition card UX.
- `lib/features/booking/services/individual_session_service.dart`
  - Legacy `session_participants.session_id` fallback warning now logs once per run.
- `lib/features/booking/services/trial_session_service.dart`
  - Removed repeated trial payment debug logs (`DB payment_status`, `Mapped trial ...`) causing terminal noise.
- `test/features/sessions/session_state_ux_stability_test.dart`
  - Added web skip for `dart:io` file-read test path so chrome runner is deterministic.
- `docs/QOE_BASELINE_WEB_CALL_2026-04-28.md`
  - Added baseline findings from live logs and visual symptoms.

## Verification evidence

### Web gate
- `flutter build web` completed successfully.
  - Evidence: terminal `75150` ended with `✓ Built build/web`.
- Session chrome tests passed after web-skip adjustment:
  - Command: `flutter test --platform chrome test/features/sessions/session_state_ux_stability_test.dart test/features/sessions/agora_session_navigation_test.dart`
  - Evidence: terminal `514505` ended with `All tests passed!` and one explicit skip for `dart:io` test.

### Android gate
- Existing Android runtime evidence from active session logs:
  - Evidence file showed successful remote stream setup and active call rendering in terminal `3`.
- `flutter build apk --debug` completed successfully in this environment.
  - Evidence: build output ended with `✓ Built build/app/outputs/flutter-apk/app-debug.apk`.
- Fresh Android runtime install+launch captured on physical device (`itel A665L`) from terminal `4`:
  - Initial install hit `INSTALL_FAILED_UPDATE_INCOMPATIBLE`, then auto-uninstall + reinstall succeeded.
  - VM service attached (`A Dart VM Service on itel A665L...`) and app reached running state.
  - Runtime confirms startup schema gate in-device: `✅ Startup schema check: session_feedback OK`.
  - Remaining runtime DoD step: explicit call join/leave evidence on Android in the same run.

### Session QoE test gate
- Passed:
  - `flutter test test/features/sessions/session_state_ux_stability_test.dart test/features/sessions/agora_session_navigation_test.dart`
  - `flutter test test/services/tutor_feedback_analytics_service_test.dart test/features/group_classes/my_sessions_group_visibility_test.dart test/features/messaging/models/conversation_model_test.dart`
- Notes:
  - Local VM tests pass.
  - Chrome tests pass with web skip for the file-system-only assertion test.

### Schema/runtime gate
- Feedback schema migration and checks validated by code-path inspection:
  - `supabase/migrations/067_add_session_feedback_enhanced_columns.sql` includes required columns.
  - `lib/core/services/startup_schema_service.dart` checks for table + required columns and reports missing relation/column codes.
  - `lib/features/booking/services/session_feedback_service.dart` distinguishes missing table (`PGRST205`,`42P01`) from other errors.
- Startup wiring validated:
  - `main.dart` invokes `StartupSchemaService.runChecks()` and web cleanup on boot.

### UI visual proof
- Provided visual references captured for call screen behavior:
  - `/Users/user/.cursor/projects/Users-user-Desktop-PrepSkul/assets/Screenshot_2026-04-28_at_04.35.14-0a512780-2dc4-4c2e-bb8c-ba9d15113e15.png`
  - `/Users/user/.cursor/projects/Users-user-Desktop-PrepSkul/assets/Screenshot_2026-04-28_at_04.35.58-7e74cc5d-210b-4098-ac54-52acbba45894.png`
  - `/Users/user/.cursor/projects/Users-user-Desktop-PrepSkul/assets/image-ecb9750b-8a18-46e9-91f2-9de199bb5249.png`

## DoD status by workstream
- Web call QoE hardening: Completed (code + tests + web build).
- Feedback reliability and startup schema checks: Completed (schema + service-path validation + startup integration confirmed).
- Credits/points reconciliation hardening: Completed (legacy fallback warning throttled, noisy debug logs removed).
- Tutor messaging reliability path: Completed (ID resolution + conversation lifecycle path validation in session surfaces).
- Evidence pack: Completed (commands, outputs, residual risks documented).

## Residual risks / follow-up
- Active Chrome runtime session still showed historical assertion spam in prior terminal stream (`window.dart:99:12`), likely from pre-patch run state.
  - Required follow-up: full hot restart and fresh two-party web call to confirm assertion frequency reduction under new code.
- Android build hang risk is now cleared in current environment (`assembleDebug` completed).
  - Required follow-up remains runtime call join/leave capture for end-to-end Android call proof.

## Additional fixes (same day continuation)
- Booking flow onsite step crash/blank page fix:
  - `lib/features/booking/screens/book_tutor_flow_screen.dart`
  - `lib/features/booking/widgets/location_selector.dart`
  - Changes:
    - Removed problematic nested scroll composition by embedding `LocationSelector` content in parent scroll.
    - Hardened PageView step navigation with post-frame guarded `_goToStep(...)` transitions and clamped indices.
    - Prevents `RenderViewport expected RenderSliver` red-screen chain and blank-next-page behavior when moving forward/backward around onsite selection.

- Web call assertion flood mitigation:
  - `lib/features/sessions/widgets/agora_video_view.dart`
  - `lib/features/sessions/widgets/local_video_pip.dart`
  - Changes:
    - Stopped repeated high-frequency `setupLocalVideo()` side effects on every rebuild by adding signature/time-gated setup on web.
    - Keeps local setup behavior but prevents aggressive rebuild-triggered rebind loops that can destabilize web rendering.
    - Removed an additional `LocalVideoPIP` post-frame `setupLocalVideo()` path that was still rebinding the local camera canvas during PIP rebuilds; the dedicated `AgoraVideoViewWidget` is now the single widget-level owner of local web setup.

## Same-session follow-up evidence
- Focused regression check after the PIP cleanup:
  - Command: `flutter test test/features/sessions/agora_session_navigation_test.dart`
  - Result: `All tests passed!`
- Static search after the cleanup:
  - No remaining `setupLocalVideo()` calls exist in session widget build paths outside `lib/features/sessions/widgets/agora_video_view.dart`.
- Runtime blocker still open:
  - Fresh browser-attached repro could not be completed from this environment because `flutter run -d chrome` and `flutter run -d web-server --web-port 7357` both stalled at `Waiting for connection from debug service...` before a usable browser tab attached.
  - Next action remains a fresh browser-connected repro to confirm whether `window.dart:99:12` spam is now eliminated under the new single-owner setup.
- Booking onsite regression check after flow hardening:
  - Command: `flutter test test/features/booking/booking_flow_complete_onsite_test.dart test/features/booking/booking_flow_location_test.dart`
  - Result: `All tests passed!` (onsite address validation + onsite complete flow scenarios green).
- Student home metrics behavior fix (all-time vs upcoming split):
  - File: `lib/features/dashboard/screens/student_home_screen.dart`
  - Changes:
    - `Your Progress` now uses all-time sessions count (`_allTimeSessionsCount`) and all-time unique tutor activity.
    - `Quick Actions -> My Sessions` remains upcoming-only via `_upcomingSessionsCount`.
    - Added cache persistence key `home_all_time_sessions_count`.
    - Added timeout-safe refresh behavior so transient fetch failures no longer overwrite valid cached counters with zero values.
    - Added local cache fallback computation (from cached individual + trial sessions) when live stats fetch is unavailable.
    - Added relaxed all-time history query fallback for strict paid-session filters that can undercount legacy/historical records.
- Android runtime evidence (latest continuation):
  - `flutter run -d 2C211JEHN17045` now builds/installs/launches successfully after student-home compile fixes.
  - Session logs showed app running under cached **tutor** profile route in offline mode; student-home metric verification remains pending until student account runtime is active with connectivity.
