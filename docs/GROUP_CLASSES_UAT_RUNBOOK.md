# Group Classes UAT Runbook

Owner: QA + Engineering  
Date: 2026-04-25

## Goal

Execute live end-to-end validation for group classes:
- create listing,
- reserve + pay seat,
- verify session visibility,
- join via deep link,
- validate classroom reliability for 1:1, 1:3, 1:5.

Use this alongside:
- `docs/GROUP_CLASSES_EXECUTION_DOD.md`
- `docs/CLASSROOM_RELEASE_RUN_REPORT_TEMPLATE.md`
- `docs/CLASSROOM_QOE_QUERY_CHECKS.sql`
- `docs/GROUP_CLASSES_DB_RUNTIME_CHECKS.sql`

## Required Test Accounts

- `tutor_verified_01` (verified tutor)
- `learner_01` (paid enrollee)
- `learner_02` (second learner for 1:3 / 1:5)
- `learner_03`, `learner_04`, `learner_05` (for 1:5)
- `observer_unpaid_01` (authenticated but not paid/enrolled)

## Environment Preconditions

- Feature flags enabled:
  - `GROUP_CLASSES_ENABLED=true`
  - `CLASSROOM_ORCHESTRATOR_ENABLED=true`
  - `CLASSROOM_DUAL_STREAM_ENABLED=true`
  - `CLASSROOM_QOE_TELEMETRY_ENABLED=true`
- Migrations applied through `080_group_class_share_tokens.sql`
- Payment webhook active in test environment
- Agora token API healthy

## Step 0: DB Runtime Sanity

1. Run SQL pack: `docs/GROUP_CLASSES_DB_RUNTIME_CHECKS.sql`
2. Confirm:
   - RLS enabled on `group_class_listings` and `group_class_enrollments`
   - unique constraints/indexes are present
   - policy list is complete

If any check fails, stop UAT and fix schema/policy first.

## Step 1: Tutor Listing Flow

1. Login as `tutor_verified_01`.
2. Open group classes tutor UI and create listing:
   - title, description, starts_at, duration, capacity, price.
3. Publish listing.
4. Record:
   - `listing_id`
   - `share_token`
   - publish log evidence.

Expected:
- Listing visible in discovery after publish.
- Draft/publish behavior follows API status transitions.

## Step 2: Enrollment + Payment Finalization

1. Login as `learner_01`.
2. Discover listing and reserve seat.
3. Complete payment.
4. Validate in DB:
   - `group_class_enrollments.status='paid'`
   - listing has `individual_session_id` linked
   - `session_participants` row exists for learner + tutor.

Expected:
- enrollment finalization is idempotent,
- My Sessions includes linked session for learner.

## Step 3: Deep-Link Access Control

Use `prepskul://join/class/{share_token}` or HTTPS equivalent.

Cases:
1. `learner_01` (paid): allowed -> video session opens.
2. `observer_unpaid_01` (not paid): blocked -> redirected to discovery/enroll path.
3. `tutor_verified_01` (owner): allowed -> video session opens.

Expected:
- no bypass for unpaid users,
- tutor and paid learners can join.

## Step 4: Reliability Matrix Execution

Execute scenarios and fill run report:
- 1:1 baseline
- 1:3 classroom
- 1:5 classroom
- degraded network (loss, latency, jitter)

For each scenario capture:
- session id,
- correlation id,
- hard drop outcome,
- reconnect UX clarity,
- QoE event presence.

## Step 5: QoE Evidence Queries

Run checks in `docs/CLASSROOM_QOE_QUERY_CHECKS.sql` for each correlation id.

Attach:
- event counts,
- event timeline,
- freeze summary,
- reconnect summary.

Expected:
- events appear consistently for reconnect/tier/freeze transitions.

## Pass Criteria

- No hard-drop regressions in core scenarios.
- Reconnect UX remains clear and non-conflicting.
- Paid learners and tutors can join, unpaid cannot.
- QoE and DB evidence align with observed behavior.

## Fail/Blocker Handling

- Mark scenario `FAIL` in report.
- Capture repro steps + evidence links.
- Add mitigation owner and ETA.
- Re-run only failed scenarios after fix verification.

