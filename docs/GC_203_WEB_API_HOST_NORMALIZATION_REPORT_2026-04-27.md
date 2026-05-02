# GC-203 Web API Host Normalization Report (2026-04-27)

Task: Normalize web API host resolution across environments.

## Changes made

- Updated `SkulMateService` base URL source to use normalized SkulMate HTTP base:
  - `lib/features/skulmate/services/skulmate_service.dart`
  - Changed `_apiBaseUrl` from `AppConfig.effectiveApiBaseUrl` to `AppConfig.skulMateHttpApiBase`.
  - This ensures web host normalization (`app.prepskul.com` -> `www.prepskul.com`) is consistently applied for SkulMate HTTP routes.

- Updated CORS/config tests to assert normalized effective API base usage:
  - `test/features/sessions/agora_cors_handling_test.dart`
  - Switched URL assertions from `AppConfig.apiBaseUrl` to `AppConfig.effectiveApiBaseUrl`.
  - Expanded error-message matcher to accept current normalized network-safe messages.

## Verification evidence

Command:

- `flutter test test/features/group_classes/web_api_normalization_and_qa_switch_test.dart test/features/sessions/agora_cors_handling_test.dart`

Result:

- **All tests passed**

Lint check:

- **No linter errors** in edited files.

## Outcome

- Web/API host normalization is now consistently consumed on SkulMate HTTP path and validated in targeted tests.
- Ready to proceed to `gc-204` (CORS policy hardening on group-class/token endpoints).
