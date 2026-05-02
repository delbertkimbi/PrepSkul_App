# GStack Operating Pattern for PrepSkul (Apr 2026)

This note explains how to apply the gstack pattern to PrepSkul so we continuously learn from external updates and clean up features across the app.

## What gstack is (for our use)

Gstack is a role-based execution model for AI-assisted product engineering.  
It structures work into roles and handoffs instead of one big "do everything" prompt.

Core roles:

- Product/CEO role: outcome clarity, user value, priority.
- Engineering Manager role: architecture and scope guardrails.
- Engineer role: implementation and refactors.
- QA role: scenario validation, regressions, evidence.
- Release role: rollout safety, rollback readiness.
- DevOps role: environment, observability, operations.

## Why this helps PrepSkul now

- We can prevent feature drift across web/app by forcing role handoffs.
- We can turn web updates (Agora docs/case studies) into backlog actions quickly.
- We can keep quality and release safety visible, not implicit.

## PrepSkul GStack cycle (repeat weekly)

1. **Scan (Research):**
   - Pull vendor/product updates (Agora, Supabase, Flutter ecosystem) and relevant competitive learning.
2. **Frame (Product/CEO):**
   - Convert findings into user/business impact statements.
3. **Review (EM/Architecture):**
   - Decide adopt/trial/hold for each technical change.
4. **Plan (Execution):**
   - Break into sprint tasks with acceptance criteria and owners.
5. **Build + Verify (Engineer + QA):**
   - Implement in slices, run evidence-first tests.
6. **Ship Control (Release + DevOps):**
   - Stage rollout, monitor KPIs, validate rollback.
7. **Reflect (Post-run):**
   - Keep/remove/adjust decisions and update standards.

## Add a simple Tech Radar layer

For each external update, classify as:

- `adopt`: proven, should standardize now.
- `trial`: run in controlled experiment.
- `assess`: useful but not immediate.
- `hold`: avoid for now.

Every classification must include:

- reason
- impacted features
- risk
- owner
- re-check date

## Operating rituals (lightweight)

- Weekly 30-min "Update Triage":
  - Inputs: release notes, incidents, user pain points.
  - Output: 3-5 prioritized actions with owners.
- Mid-week 20-min "Architecture Check":
  - Validate no cross-platform drift (web/app parity).
- End-week 20-min "Release + Evidence Check":
  - Confirm DoD evidence and KPI movement.

## Minimum artifacts to maintain

- `AGORA_REFERENCE_TECH_UX_INSIGHTS_2026-04.md` (research synthesis)
- `AGORA_2_WEEK_EXECUTION_ADDENDUM_2026-04.md` (execution timeline)
- `AGORA_2_WEEK_TASK_BREAKDOWN_2026-04.csv` (delivery board import)
- A small "Tech Radar" doc (adopt/trial/assess/hold decisions)

## Rules for every new feature/fix

- No implementation without written DoD.
- No release without paid-user join path validation.
- No "looks good" acceptance; evidence must be attached.
- No dependency upgrade without controlled baseline and rerun.

## Immediate application to current roadmap

- Use this pattern to drive:
  - `sprint-1-web-join-stability`
  - `sprint-2-flyer-upload-fallback`
  - `group-19-uat-matrix`
  - `group-20-release-rollout`

This keeps execution strict, measurable, and aligned to business outcomes.
