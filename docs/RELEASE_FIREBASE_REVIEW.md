# Firebase app review release — 8 October 2026

Canonical checkout: `prepskul_app_delbert`, branch `delbert`, origin `delbertkimbi/PrepSkul_App`.
Android application ID and iOS bundle ID remain `com.prepskul.prepskul`. This is the existing app on a branch. Firebase Hosting publishes its web build; it does not submit a new store app.

## Build safely

```sh
node scripts/inject-env.js
flutter build web --release
node scripts/check-release-config.js
flutter test test/features/skulmate/widgets/mascot_state_mapping_test.dart test/features/skulmate/session_route_service_test.dart
```

The injector reads the local root environment or shell and writes only an explicit public allowlist into `assets/config/client.env` and browser configuration. The generated `.env` stays gitignored. Root `.env` is no longer an asset. Production Supabase configuration must be an anon JWT or publishable key, never a service-role key. Keep root secrets local and on authorised servers.

The current script deliberately creates a **review configuration with payments unavailable**. Payment migration to an authenticated, server-authoritative order flow is required before a full live release. Other integrations that depended on client-held server secrets must also be audited. Do not solve missing functionality by adding secrets back into the allowlist.

The artifact checker searches for known private values from local `.env` and common encoded forms. It is a regression check, not proof that every possible hardcoded secret has been found. Credentials previously committed or distributed need rotation and incident review; new build cleanup does not revoke old copies.

## Deployment targets

Existing Firebase project/site: `operating-axis-420213`.
Existing live URL: `https://operating-axis-420213.web.app`.

Safe review publication, after the user chooses this release scope:

```sh
firebase hosting:channel:deploy app-review-oct8 --expires 7d --project operating-axis-420213 --non-interactive
```

A preview has the same configured Supabase/backend endpoints; it is **not an isolated data sandbox**. Use designated test accounts. Payment calls are blocked. Do not test charge-producing flows.

Live replacement requires payment/API readiness or explicit acceptance of the limited release:

```sh
firebase deploy --only hosting --project operating-axis-420213 --non-interactive
```

Deployment also requires checking auth redirect allowlists and API CORS for the exact hosted origin. The new tutor-session routes called by this app are missing from the inspected website checkout. Locate, deploy and exercise the authenticated routes before describing the whole learning/voice experience as production-ready.

## Verification and rollback

After publication, inspect the returned URL, app boot, public config asset, GLB loading, onboarding, login with a designated account, session resume, API errors and voice permission/interruption. Do not equate a successful HTML response with a successful learning session.

Record Firebase release/channel ID, app commit and backend/schema revisions. A preview expires automatically; a live rollback uses the previously verified Firebase Hosting release. Keep the previous app/API contracts compatible during rollback.

## Current evidence

- JavaScript Flutter web release build passed after root environment removal.
- Known private-value scan of that build returned no matches; root `.env` asset absent.
- Native Android/iOS store builds and end-to-end authenticated voice/payment flows are not established by that web build.
- Deployment status and exact test results are recorded in the task's final report; this document is not a claim that publication occurred.
