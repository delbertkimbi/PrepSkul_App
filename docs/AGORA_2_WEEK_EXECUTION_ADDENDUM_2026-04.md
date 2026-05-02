# Agora + Group Classes: 2-Week Execution Addendum

This addendum operationalizes `AGORA_REFERENCE_TECH_UX_INSIGHTS_2026-04.md` into a strict 10-working-day execution plan.

## Scope of this 2-week window

- Stabilize web join/token path and finish evidence (`sprint-1-web-join-stability`).
- Complete flyer fallback parity to close Sprint 2 slice (`sprint-2-flyer-upload-fallback`).
- Produce release-grade UAT evidence (`group-19-uat-matrix`).
- Prepare rollout controls and rollback readiness (`group-20-release-rollout`).

## Team roles (owners)

- **EM/Tech Lead**: final gate, risk decisions, merge/release approvals.
- **Frontend App Engineer**: Flutter group-class UX, fallback rendering, tests.
- **Web/API Engineer**: CORS, host normalization, token prejoin path hardening.
- **QA Engineer**: UAT matrix execution, evidence capture, regression pass.
- **Product/Design**: UX acceptance on create/discovery/join flows.
- **Data/Observability Engineer**: QoE KPI instrumentation checks and dashboard.

## Success criteria (must all pass)

- Web prejoin token fetch: 3/3 success in test runs, no status-0 CORS failures.
- Paid learner can join; unpaid learner is blocked with clear UX.
- Flyer fallback works on all listing surfaces (uploaded flyer -> tutor avatar -> safe placeholder).
- UAT matrix (1:1, 1:3, 1:5) complete with evidence artifacts.
- Rollout and rollback playbook reviewed and approved by EM + QA + Product.

## Day-by-day plan (10 working days)

### Day 1 - Baseline and freeze

- **Owner:** EM + Web/API Engineer + QA
- Lock current dependency versions (no opportunistic upgrades).
- Capture current failure baseline:
  - web token prejoin success rate
  - status-0/CORS incidence
  - paid vs unpaid join behavior
- Create run sheet for daily checks.
- **Exit DoD:**
  - Baseline metrics logged in release run report template.
  - Known failure modes documented with reproducible steps.

### Day 2 - Web API host normalization and CORS hardening

- **Owner:** Web/API Engineer
- Normalize API base resolution for web environments.
- Harden CORS headers for group-class/token-related endpoints.
- Add explicit structured error bodies for prejoin failures.
- **Exit DoD:**
  - Local + staging web token calls succeed from intended origins.
  - No ambiguous network errors without diagnostic context.

### Day 3 - Token prejoin reliability pass

- **Owner:** Web/API Engineer + QA
- Test 3 repeated prejoin attempts per scenario (paid/unpaid).
- Validate paid passes and unpaid blocks consistently.
- Add regression tests for authorization parity.
- **Exit DoD:**
  - 3/3 token prejoin success for paid flows.
  - Unpaid block verified and logged.

### Day 4 - App parity for flyer fallback (list + detail)

- **Owner:** Frontend App Engineer
- Ensure fallback hierarchy on all relevant app surfaces:
  - `flyer_image_url` first
  - tutor avatar fallback
  - safe local placeholder
- Align card/detail rendering behavior and loading states.
- **Exit DoD:**
  - Visual parity verified for tutor + learner flows.
  - Null/invalid URL cases handled without crash.

### Day 5 - Tests + UX polish checkpoint

- **Owner:** Frontend App Engineer + Product/Design + QA
- Add/adjust tests for flyer fallback parity and no-regression assertions.
- UX pass for empty states, status messages, and CTA clarity.
- **Exit DoD:**
  - Relevant app tests green.
  - Product signoff on affected screens.

### Day 6 - UAT matrix run 1 (1:1 and 1:3)

- **Owner:** QA
- Run full path: create -> enroll -> pay -> join.
- Capture screenshots/logs/result states per step.
- Record defects with severity.
- **Exit DoD:**
  - Evidence complete for 1:1 and 1:3.
  - Defect list triaged with owners and ETA.

### Day 7 - UAT matrix run 2 (1:5) + defect fixes

- **Owner:** QA + Engineering
- Execute 1:5 path and validate participant behavior under load.
- Fix priority defects from Day 6.
- Re-run impacted scenarios.
- **Exit DoD:**
  - 1:5 evidence complete.
  - Critical blockers resolved or formally risk-accepted by EM.

### Day 8 - Observability and KPI readiness

- **Owner:** Data/Observability Engineer + Web/API Engineer
- Verify telemetry for:
  - join success
  - first remote frame time
  - reconnect count
  - join failures by reason
- Add missing instrumentation where needed.
- **Exit DoD:**
  - KPI dashboard/report query can show week-over-week baseline.
  - Failure reasons are categorized (not generic).

### Day 9 - Rollout and rollback rehearsal

- **Owner:** EM + Web/API Engineer + QA
- Prepare staged rollout flags and percentage ramp.
- Run rollback drill and verify restoration timing.
- Validate communication template for incidents.
- **Exit DoD:**
  - Rollout plan approved.
  - Rollback tested and timed.

### Day 10 - Final release gate review

- **Owner:** EM + QA + Product
- Review all evidence, open risks, and residual defects.
- Decide: ship / hold / partial rollout.
- Publish final gate status note.
- **Exit DoD:**
  - Release decision documented with signoffs.
  - If shipping: release window and owner on-call confirmed.

## Deliverables checklist

- Updated run report artifact for `group-19-uat-matrix`.
- Technical hardening notes for `sprint-1-web-join-stability`.
- UI/test evidence for `sprint-2-flyer-upload-fallback`.
- Rollout/rollback checklist for `group-20-release-rollout`.
- KPI snapshot before/after hardening.

## Risk register (top 5)

- CORS regressions after environment changes.
- Token service dependency mismatch across web/app.
- Edge-case enrollment states (reserved vs paid) causing join mismatch.
- Media quality degradation on low-end/weak-network devices.
- Incomplete telemetry creating false confidence.

## Mitigation triggers

- If prejoin fails more than 1 in 10 attempts in staging: stop rollout prep and fix first.
- If paid learner join fails in any UAT lane: block release gate.
- If unpaid learner can join in any lane: immediate rollback/patch required.
- If fallback image path breaks UX in tutor or learner lane: hold Sprint 2 closeout.

## Required signoffs

- Engineering: EM/Tech Lead
- QA: Test lead
- Product: Product owner/design approver

Without all three signoffs, do not move to general rollout.
