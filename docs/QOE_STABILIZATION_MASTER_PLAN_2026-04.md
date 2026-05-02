# PrepSkul QoE Stabilization Master Plan (1:1 + Group)

This replaces feature-first execution with reliability-first execution.

## Objective

Reduce failed session experiences across users by stabilizing core live-session quality before further feature expansion.

Scope:

- One-on-one sessions
- Group sessions
- Web + app clients
- Prejoin, join, in-session, reconnect, and session-end paths

## Stability-first rule

No new UX/features ship until reliability gates are met:

- Join success (paid + authorized users) >= 98% in monitored cohort
- First remote frame (P95) <= 6s
- Mid-session drop rate <= 2%
- Reconnect success <= 15s for >= 95% reconnect attempts
- Critical QoE blocker count = 0 for release candidate

## Step-by-step execution

### Step 1: Baseline and segmentation

- Build failure taxonomy from real logs:
  - prejoin failures
  - token/auth failures
  - media-device failures
  - network/congestion failures
  - reconnect failures
  - UI state desync failures
- Segment by platform and session type (1:1 vs group).

DoD:

- Baseline dashboard/report by segment.
- Top 5 failure clusters identified with incidence.

### Step 2: Session state machine hardening

- Enforce one shared lifecycle model:
  - `idle -> prejoin_check -> joining -> connected -> degraded -> reconnecting -> resumed -> ending -> ended|failed`
- Remove divergent ad-hoc transitions across screens/services.
- Add deterministic user-safe fallbacks for each failure class.

DoD:

- State transition tests pass for 1:1 and group.
- No invalid transition paths in logs for 3 consecutive runs.

### Step 3: Prejoin reliability lock

- Standardize token + auth + enrollment diagnostics.
- Enforce retry policy and timeout budget consistency.
- Add explicit “blocked vs retryable” UX.

DoD:

- Paid authorized path succeeds 3/3 in repeated runs.
- Unpaid/unauthorized blocked with clear reason + next step.

### Step 4: Media quality and reconnect stabilization

- Tune default bitrate/fallback policy for low bandwidth.
- Improve reconnect backoff and stream re-subscribe logic.
- Introduce audio-first fallback under severe degradation.

DoD:

- Reconnect success and recovery-time target met.
- Session continuity improved in weak-network test matrix.

### Step 5: Cross-platform parity and UI resilience

- Align 1:1 and group failure handling UX:
  - same severity levels
  - same action buttons
  - same diagnostics mapping
- Fix stuck UI states (spinner/black screen/dead controls).

DoD:

- UX parity checklist complete on web + app.
- Regression suite green for session navigation + rejoin flows.

### Step 6: Controlled rollout

- Gate behind feature flags per segment.
- Ramp gradually and monitor live QoE metrics.
- Predefined rollback triggers.

DoD:

- Rollout report shows improved QoE trends.
- No blocker regressions after ramp.

## Execution order against current roadmap

Priority override:

1. `sprint-1-web-join-stability`
2. New QoE lane (this plan)
3. UAT matrix (`group-19-uat-matrix`)
4. Rollout prep (`group-20-release-rollout`)
5. Secondary feature tasks

## Founder operating cadence (daily)

- 15 min reliability standup:
  - yesterday failures
  - today highest-risk fix
  - release risk color
- End-of-day scorecard:
  - join success
  - P95 first frame
  - drop rate
  - reconnect success
  - top unresolved blocker
