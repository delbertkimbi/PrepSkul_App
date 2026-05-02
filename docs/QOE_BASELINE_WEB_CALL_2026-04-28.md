# Web Call QoE Baseline (2026-04-28)

## Reproduction context
- Command: `flutter run -d chrome`
- Session observed: web learner/tutor call join with remote participant present
- Evidence source: terminal stream and current UI screenshots

## Baseline findings
1. Repeated Flutter web assertion spam while call is active:
   - `Assertion failed: org-dartlang-sdk://lib/_engine/engine/window.dart:99:12`
   - Appears continuously in terminal output during active connected state.

2. Unsupported SDK API calls are repeatedly retried on web:
   - `RtcEngine_setRemoteVideoStreamType... not supported in this platform!`
   - Followed by repeated warnings:
     - `[NET] Failed to set HIGH stream for uid=...: AgoraRtcException(-4, null)`
   - Indicates stream-priority logic keeps issuing unsupported calls.

3. User-visible web QoE symptoms:
   - Delayed remote video appearance vs Android.
   - Camera state appears to oscillate (camera on/off style flicker).
   - UI status can feel noisy rather than calm/Meet-like during transitions.

4. High log noise from unrelated session/points polling while in call:
   - Repetitive `DB payment_status` and `Mapped trial ... paymentStatus=...` output.
   - Makes diagnosis harder and can mask call QoE signals.

## Immediate hardening targets
- Add capability gating + one-way disable for unsupported stream-type APIs on web.
- Prevent repeated calls to remote stream type setters once unsupported is detected.
- Reduce volatile remote mute/ready transitions to avoid visual flicker on web.
- Keep connecting/leaving UX calm and deterministic with stable state transitions.
