# P1 Android Release-Build Smoke Checklist

Owner: __________  
Date: __________  
Build (AAB/APK): __________  
Device(s): __________

## Preflight

- [ ] Build generated from release profile (`--release`), not debug.
- [ ] Correct API base URL/environment for release.
- [ ] Required env vars present (auth, Supabase, SkulMate generation).
- [ ] Database migrations applied/verified for target environment.

## Install + Launch

- [ ] App installs cleanly on fresh device.
- [ ] Cold launch succeeds (no crash/ANR).
- [ ] Warm relaunch succeeds.
- [ ] Login session persistence behaves correctly.

## Critical User Journeys

- [ ] Auth (email/password) successful.
- [ ] Auth (Google) successful.
- [ ] SkulMate upload -> generate -> play -> results complete.
- [ ] Upload tab shows recent 3 + `See more uploads`.
- [ ] Open text source from upload history shows content (not blank/black).

## Error and Recovery

- [ ] Network-off scenario gives actionable error copy.
- [ ] Request timeout scenario exits loading state properly.
- [ ] Credit/free-limit errors are user-friendly and actionable.
- [ ] Return to app after background interruption is stable.

## Performance Spot Check

- [ ] First meaningful screen appears within acceptable time.
- [ ] No severe frame drops in core SkulMate flow.
- [ ] Memory does not spike abnormally during upload/generation.

## Release Safety

- [ ] Crash/analytics monitoring is enabled for release build.
- [ ] Rollback path documented (previous stable build available).
- [ ] Release notes and support escalation path prepared.

## Sign-off

- [ ] Smoke pass complete.
- [ ] Blockers documented.
- [ ] Release approved.

### Blockers

1. __________________________________________
2. __________________________________________
3. __________________________________________

