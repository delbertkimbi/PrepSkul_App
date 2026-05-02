# GC-204 CORS Hardening Report (2026-04-27)

Task: Harden CORS policy for group-class and token endpoints.

## What was hardened

### 1) Shared CORS helper made stricter and reusable

Updated:

- `PrepSkul_Web/lib/services/group-classes/cors.ts`

Changes:

- Added option support for endpoint-specific methods/headers.
- Added `Vary` header:
  - `Origin, Access-Control-Request-Method, Access-Control-Request-Headers`
- For unknown origins, no longer reflects arbitrary origin with credentials.
  - Uses `Access-Control-Allow-Origin: *` and does not add credential allowance.
- Kept allowed-origin behavior for trusted domains and local/private-network dev.

### 2) Agora token route now uses shared CORS helper

Updated:

- `PrepSkul_Web/app/api/agora/token/route.ts`

Changes:

- Removed duplicated/manual CORS origin logic in both `POST` and `OPTIONS`.
- Replaced with `buildCorsHeaders(request, { methods, allowHeaders })`.
- Ensures consistent CORS behavior between token route and group classes route.

### 3) Added regression coverage for hardening

Added test:

- `PrepSkul_Web/__tests__/group-classes/cors-hardening.test.ts`

Asserts:

- Shared helper has unknown-origin wildcard fallback.
- Agora token route uses shared CORS helper.
- Group-classes route keeps preflight via shared helper.

## Verification evidence

Command:

- `npm test -- __tests__/group-classes/group-class-routes.test.ts __tests__/group-classes/cors-hardening.test.ts __tests__/group-classes/group-class-token-parity.test.ts __tests__/agora/session-service-authz.test.ts`

Result:

- **4/4 suites passed**
- **16/16 tests passed**

Lint:

- No linter errors in edited backend files.

## Outcome

- CORS policy is now centralized, consistent, and safer across:
  - `/api/group-classes/*`
  - `/api/agora/token`
- Ready to move to `gc-205` (explicit prejoin diagnostics).
