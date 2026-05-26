# Session Screen Share QA Matrix

## Scope
- Verify screen-share behavior across web, Android, and iOS.
- Validate tutor and learner perspectives.
- Confirm recovery banner behavior during expected and broken states.
- Confirm workspace and in-call UI does not hide the active shared stream.

## Environment
- Build: latest `main` branch.
- Accounts: 1 tutor, 1 learner.
- Browsers: Chrome (desktop), Safari (iOS).
- Devices: Android phone/tablet, iPhone/iPad.

## Core Matrix
- [ ] Web Chrome tutor shares tab/window; learner sees shared stream in primary stage.
- [ ] Web Chrome tutor stops share from app button; learner returns to tutor camera.
- [ ] Web Chrome tutor stops share from browser chip/button; learner returns to tutor camera.
- [ ] Android tutor starts display capture; learner sees shared stream (not camera placeholder).
- [ ] Android tutor stops display capture; learner returns to camera state correctly.
- [ ] iOS Safari screen-share action shows unsupported guidance (no broken state).
- [ ] Learner cannot start share unless rollout flag explicitly enables learner sharing.

## Role Coverage
- [ ] Tutor sees local share controls active while `publishScreenTrack` is active.
- [ ] Learner sees remote share even if remote camera is muted/off.
- [ ] Tutor sees correct companion lane behavior (no tiny circular share preview).
- [ ] Both roles maintain audio and chat while share is active.

## Workspace + Share Interaction
- [ ] With teaching lane open and active share, video remains dominant on narrow layouts.
- [ ] Workspace panel does not replace active shared stream with empty placeholder.
- [ ] Materials empty/deferred states appear only in workspace panel, not over shared video.
- [ ] Page controls appear only when workspace is on Materials (`pdfDocument`).
- [ ] No workspace rail overlays render on top of active screen-share stage.

## Recovery Banner Rules
- [ ] No recovery banner when remote camera is off but remote screen share is decoding.
- [ ] Recovery banner can appear for real degradation (reconnect/freezes).
- [ ] Banner clears automatically on recovery.
- [ ] Banner actions open backup link/support entry points.
- [ ] Repeated failed recovery attempts do not spam banner/log every interval.

## Network / Resilience
- [ ] Toggle network off/on during active share on tutor; learner recovers back to share.
- [ ] Toggle network off/on during active share on learner; learner returns to share after reconnect.
- [ ] QoE event write failures (offline) do not block UI or recovery flows.
- [ ] Camera state updates still propagate when Agora data stream is unavailable.

## Regression Checks
- [ ] In-call messages panel keeps video visible on wide web layouts.
- [ ] Gallery/side-by-side transitions do not break local or remote video surfaces.
- [ ] No persistent black/pink tiles after rapid start/stop share cycles (5x).
- [ ] Screen share owner handoff preserves correct active stream.

## Baseline (2026-05-16) — reported regressions before fix batch

| Issue | Status | Notes |
|-------|--------|-------|
| Tutor desktop full-width cards | Still broken | Home/Requests/Sessions single column on wide Chrome |

## Post-fix code status (2026-05-16) — manual Chrome verify still required

| Issue | Code status | Manual verify |
|-------|-------------|---------------|
| Tutor desktop Z layout (all tabs) | Implemented (`TutorZRow`, `TutorZCardGrid`, home/requests/sessions/profile) | [ ] Chrome ≥1200px all four tabs |
| Teaching tools visible (1:1) | Shell on except gallery; spotlight on join; lane opens on tool tap | [ ] Tutor+learner: Board shows panel |
| Web screen share black stage | Camera setup guarded; default companion layout; screen source preserved | [ ] Sharer + viewer see content + faces |
| Participant left UI | `Learner left` banner; `_buildPeerLeftMainState`; strip "Left" | [ ] Learner leaves mid-call + during share |
| Prior routing/recovery/QoE work | Unchanged | [ ] Matrix rows 37–48 |

## Execution Log Template
- Date:
- Build/commit:
- Devices:
- Browser:
- Scenario:
- Expected:
- Actual:
- Result: PASS/FAIL
- Notes/screenshots:
