# P2 Security & Privacy Audit Status

Last updated: 2026-04-10

## Scope

- SkulMate client logging + API interaction
- SkulMate generation backend route logging behavior
- Data persistence sensitivity around uploaded source metadata

## Completed Fixes

- **Client request log redaction (DONE)**
  - File URLs with signed tokens are now sanitized before logging in
    `prepskul_app/lib/features/skulmate/services/skulmate_service.dart`.

- **Backend URL log sanitization (DONE)**
  - Download URL logs now strip query strings (token-safe) in
    `PrepSkul_Web/app/api/skulmate/generate/route.ts`.

- **Debug sink safety (DONE earlier)**
  - Debug ingest calls are env-gated; no hardcoded localhost sink in production path.

- **Push token logging (DONE 2026-04-10)**
  - FCM registration tokens are no longer logged in full; only token length is logged (`prepskul_app/lib/core/services/push_notification_service.dart`).

- **Phone OTP debug (verified)**
  - `verifyPhoneOTP` logs only code and phone **lengths**, not the OTP or full number (`prepskul_app/lib/core/services/supabase_service.dart`).

## Remaining Audit Checks (Pending)

- Verify no other logs emit signed URLs or bearer tokens.
- Review retention policy for `source_text_snapshot` data.
- Confirm production env variable access is restricted to least privilege.
- Validate RLS and service-role write paths for SkulMate tables.

## Recommended Next Security Tasks

1. Add centralized log sanitizer utility for URL/token-bearing fields.
2. Add a lint/check script for accidental token logging patterns.
3. Define purge/retention window for text snapshots.
4. Perform a final secret exposure scan before release build cut.

## Code review notes (2026-04-10)

- **SkulMate generate (client):** `LogService.debug` uses `_sanitizedRequestLog` so signed `fileUrl` query tokens are not logged (`prepskul_app/lib/features/skulmate/services/skulmate_service.dart`). The HTTP `Authorization` header is not logged.
- **Error paths:** Failed responses may log truncated bodies; avoid echoing full user document text in API error payloads.
- **Regression guard:** Run `flutter test test/features/skulmate/models/game_model_test.dart` in CI for SkulMate drag/drop playability and JSON alias coverage.

- **RLS (repo inventory):** SkulMate tables define policies in migrations — e.g. `skulmate_games` / `skulmate_game_data` in `prepskul_app/supabase/migrations/030_skulmate_games.sql`, usage events in `072_skulmate_usage_events.sql`, pricing in `074_skulmate_pricing.sql`, social tables in `034_add_social_features.sql`. **Prod check:** confirm these migrations are applied and policies match dashboard (no `service_role` bypass surprises for anon).

