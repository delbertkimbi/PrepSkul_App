# P2 Release Candidate, UAT, Rollback, and Monitoring

Owner: __________  
Date: __________  
Target release: __________ (version name + build number)

## Purpose

Single runbook to cut an RC, collect UAT sign-off, know how to roll back, and watch production after ship. Cross-links other checklists rather than duplicating them.

## References (complete before RC)

- P0 smoke: `P0_SMOKE_REGRESSION_CHECKLIST.md`
- Android release smoke: `P1_ANDROID_RELEASE_SMOKE_CHECKLIST.md`
- Network behavior: `P1_NETWORK_RESILIENCE_CHECKLIST.md`
- Migrations: `P1_MIGRATION_ROLLOUT_VERIFICATION.md`
- Backend: `PrepSkul_Web/docs/SKULMATE_BACKEND_READINESS_STATUS.md` (if SkulMate ships)
- Store listing: `P2_STORE_READINESS_CHECKLIST.md`
- Security posture: `P2_SECURITY_PRIVACY_AUDIT_STATUS.md`

## 1. Release candidate (RC)

- [ ] **Freeze scope**: only blocker fixes after RC; everything else is a follow-up release.
- [ ] **Tag** the RC commit (example: `rc/1.0.0+12` or project convention).
- [ ] **Build** release AAB from that tag; record SHA and CI job link.
- [ ] **Distribute** RC to internal testers + UAT (Play internal testing track or equivalent).
- [ ] **Changelog**: short user-facing “what changed” for testers and store notes.

## 2. User acceptance testing (UAT)

**Sign-off criteria (all must pass or have a documented waiver):**

- [ ] Auth and session recovery (login, cold start).
- [ ] Core booking/tutor flows used in production (as applicable).
- [ ] SkulMate: upload (text/doc/image as supported) → generate → play → results → library; upload tab “see more” and open text source.
- [ ] Payments/booking money paths if this release touches them (separate sign-off owner).
- [ ] No P0 regressions from `P0_SMOKE_REGRESSION_CHECKLIST.md`.

**Record:** tester names/roles, date, build ID, pass/fail, and linked issues for failures.

## 3. Rollback plan

### Mobile app (Play)

- [ ] Know how to **halt rollout** or **roll back** to previous release in Play Console (staged rollout).
- [ ] Confirm **previous stable version** still installable and acceptable for users who do not update immediately.
- [ ] If a bad build is in the wild: document **minimum action** (pause rollout vs. emergency fix vs. hotfix branch).

### Backend (Vercel / API)

- [ ] **Previous deployment** is one click away (Vercel rollback to last good deployment).
- [ ] Env vars documented in `PrepSkul_Web/VERCEL_ENV_VARS_REQUIRED.md`; no surprise changes at release time.

### Database (Supabase)

- [ ] Prefer **forward fixes** for schema issues; destructive rollback is rare.
- [ ] For migration-specific rollback, follow `P1_MIGRATION_ROLLOUT_VERIFICATION.md` mitigation section and keep backups aligned with policy.

### Comms

- [ ] Owner for **status message** to users (support channel / in-app if applicable) if incident occurs.

## 4. Monitoring after release

**First 24–72 hours — watch:**

- [ ] **Play Console**: crashes, ANRs, uninstall spikes (Android vitals).
- [ ] **Supabase**: auth errors, DB error rates, storage/upload failures (dashboards and logs).
- [ ] **Vercel / API**: 5xx rate, latency, timeout spikes on `/api/skulmate/generate` and other hot routes.
- [ ] **Firebase** (if used for messaging): delivery issues are secondary to core app stability.

**Thresholds (fill in for your org):**

- Crash rate: __________ % sessions or DAU threshold
- API 5xx: __________ % of requests or sustained minutes
- SkulMate generation failure rate: __________ (if measurable)

**On-call / ownership:** name who checks dashboards daily for the first week: __________

## 5. Exit criteria for “release complete”

- [ ] RC tagged and UAT signed off.
- [ ] Production rollout completed per plan (staged or full).
- [ ] Monitoring checklist executed for day 1; no open P0 incidents.
- [ ] Post-release retro scheduled (optional): what to automate next (integration tests, alerts).
