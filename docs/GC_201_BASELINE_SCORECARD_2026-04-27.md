# GC-201 Baseline Scorecard (2026-04-27)

Scope: `sprint-1-web-join-stability` baseline for prejoin/token reliability, CORS/status-0 risk, and paid/unpaid authorization behavior.

## Executive status (traffic light)

- **Token authz parity (backend): GREEN**
- **Web/API normalization wiring: GREEN**
- **App-side token prejoin reliability test posture: RED**
- **Overall GC-201 readiness: AMBER** (known blockers isolated and actionable)

## Evidence collected

## 1) Backend authorization + token parity

Command:

- `npm test -- __tests__/group-classes/group-class-token-parity.test.ts __tests__/agora/session-service-authz.test.ts __tests__/group-classes/group-class-routes.test.ts`

Result:

- **3/3 suites passed**
- **13/13 tests passed**

What this proves:

- Session access control parity logic is working in backend tests.
- Unauthorized users are blocked in test scenarios.
- Route-level behavior for group classes is stable in test coverage.

## 2) App-side baseline tests (normalization + CORS + token service)

Command:

- `flutter test test/features/group_classes/web_api_normalization_and_qa_switch_test.dart test/features/sessions/agora_cors_handling_test.dart test/features/sessions/agora_token_service_test.dart`

Result:

- `web_api_normalization_and_qa_switch_test.dart`: **PASS**
- `agora_cors_handling_test.dart`: **FAIL** (CORS message expectation mismatch)
- `agora_token_service_test.dart`: **FAIL** (network-dependent expectations, auth expectation mismatch)

Observed failure signatures:

- Exception path resolves to generic connection failure:
  - `"Connection failed. Please check your internet and try again."`
- Some tests appear to expect a more explicit CORS/auth-specific message path.
- Token service tests appear to depend on live connectivity behavior rather than deterministic mocks in current environment.

## 3) CORS/status-0 risk posture (code scan)

Confirmed via codebase scan:

- Dedicated CORS handling logic exists for Agora token and web client flows.
- Web API host normalization comments and config are present in app config and group class API service.
- Multiple defensive handlers for status-0/CORS-like failures exist, but messaging expectations differ across tests.

## Decision and next actions

### Decision

- Mark GC-201 baseline as **completed with blockers captured**.
- Proceed to GC-202/203/204 with focus on deterministic token prejoin diagnostics and test reliability.

### Immediate follow-ups

1. Align expected vs actual error messaging for CORS and auth cases in app tests (`gc-205` dependency).
2. Remove live-network coupling from token service tests using controlled mocks.
3. Add explicit machine-readable error reason mapping (`network`, `cors`, `authz`, `enrollment`) for prejoin path.
4. Re-run the same baseline suite as post-fix comparison snapshot.

## Founder lens summary

- Core authorization logic is healthy (good signal for paid/unpaid gate integrity).
- Reliability story is not release-grade yet due to app-side prejoin error-path inconsistency.
- This is a fixable execution problem, not an architecture failure.
