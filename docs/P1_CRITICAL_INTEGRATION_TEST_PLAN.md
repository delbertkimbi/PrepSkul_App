# P1 Critical Integration Test Plan (SkulMate)

Owner: __________  
Date: __________  
Build: __________

## Goal

Validate the release-critical user journey:

`login -> upload -> generate -> play -> results -> library`

## Required Scenarios

1. **Auth entry**
   - login with email/password
   - login with Google
   - recover from session-expired state

2. **Upload source variants**
   - document upload
   - image upload
   - manual text input

3. **Generation outcomes**
   - successful generation
   - timeout/network failure returns user-friendly error
   - 402/limit returns billing-friendly error

4. **Playable game route**
   - generated game opens expected screen
   - drag-drop content is accepted as playable when valid payload exists

5. **Results + return**
   - results screen renders score/progress
   - navigate back to library/dashboard without crash

6. **Library upload history**
   - upload tab shows recent 3 items by default
   - `See more uploads` expands list
   - open source text does not show blank/black page

## Automation Strategy

- **Model / contract tests (no device):** `test/features/skulmate/models/game_model_test.dart` covers `GameModel.isPlayable` for `drag_drop`, including shared `gameData.dropZones` and JSON aliases (`draggables`, `zones`).
- Keep a dedicated integration test entrypoint:
  - `test/integration/skulmate_critical_flow_integration_test.dart`
- Use controlled mocks for:
  - auth state
  - generation API responses (success + failure shapes)
  - storage upload responses
- Stabilize deterministic waits around async transitions before enabling test.

## Exit Criteria

- [ ] Model/contract: `flutter test test/features/skulmate/models/game_model_test.dart` passes (drag/drop playability + JSON aliases).
- [ ] All six scenario groups pass on CI
- [ ] No unhandled exceptions during flow
- [ ] Failure states have actionable UI copy

