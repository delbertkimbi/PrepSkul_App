# GC-205 Prejoin Diagnostics Report (2026-04-27)

Task: Add explicit token prejoin diagnostics with structured failure reasons.

## Implemented diagnostics

### 1) API now returns structured error payloads for token failures

Updated:

- `PrepSkul_Web/app/api/agora/token/route.ts`

Added structured fields on error responses:

- `error` (human-readable message)
- `code` (stable machine-readable code)
- `reason` (category)
- `hint` (action guidance)
- `retryable` (bool)

Example codes introduced:

- `TOKEN_AUTH_HEADER_MISSING`
- `TOKEN_AUTH_INVALID_OR_NETWORK`
- `TOKEN_SESSION_ID_MISSING`
- `TOKEN_SESSION_ACCESS_DENIED`
- `TOKEN_ROLE_RESOLUTION_FAILED`
- `TOKEN_GENERATION_FAILED`

### 2) App token service now parses structured diagnostics

Updated:

- `prepskul_app/lib/features/sessions/services/agora_token_service.dart`

Enhancements:

- Parses backend error fields (`code`, `reason`, `hint`, `retryable`).
- Logs structured diagnostics for observability.
- Builds user-facing messages that preserve server guidance and error code context.

### 3) Test hardening for deterministic checks

Updated:

- `PrepSkul_Web/__tests__/group-classes/cors-hardening.test.ts`
  - Added assertions for structured diagnostic fields in token route.
- `prepskul_app/test/features/sessions/agora_token_service_test.dart`
  - Removed network-coupled assertion (`returnsNormally` on live call).
  - Relaxed auth error expectation to include deterministic connection/auth messages.

## Verification evidence

### Backend

Command:

- `npm test -- __tests__/group-classes/cors-hardening.test.ts __tests__/agora/session-service-authz.test.ts __tests__/group-classes/group-class-token-parity.test.ts`

Result:

- **3/3 suites passed**
- **12/12 tests passed**

### App

Command:

- `flutter test test/features/sessions/agora_cors_handling_test.dart test/features/sessions/agora_token_service_test.dart`

Result:

- **All tests passed**

### Lint

- No linter errors in updated files.

## Outcome

- Prejoin/token failures now emit machine-readable diagnostics suitable for:
  - UI messaging
  - telemetry categorization
  - faster QA triage
- Ready to execute `gc-206` reliability pass (paid/unpaid 3/3 evidence).
