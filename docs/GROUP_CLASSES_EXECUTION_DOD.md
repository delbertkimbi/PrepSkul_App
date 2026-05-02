# Group Classes Implementation DoD

Owner: Engineering  
Contributors: Product, Design, QA, Data  
Status: In execution  
Date: 2026-04-25

## Scope

This checklist covers the delivered implementation for group classes:
- verified tutor listing creation/publish,
- learner seat reservation and payment-driven enrollment finalization,
- `session_participants` parity for class join authorization,
- optional deep-link class join entry (`/join/class/:token`),
- app + backend coverage tests and release-run instructions.

## Completed Deliverables

- [x] Migrations:
  - `079_group_class_listings_and_enrollments.sql`
  - `080_group_class_share_tokens.sql`
- [x] Backend routes:
  - `GET/POST /api/group-classes`
  - `PATCH /api/group-classes/[id]`
  - `POST /api/group-classes/[id]/publish`
  - `POST /api/group-classes/[id]/enroll`
  - `GET /api/group-classes/join/[token]`
- [x] Payment lifecycle integration:
  - group enrollment finalization in payment webhook
  - session linking and `session_participants` upsert
- [x] App flows:
  - tutor group-class create/publish screen
  - learner group-class discovery + reserve CTA
  - My Sessions visibility for paid participant enrollments
  - deep-link join resolution path in app startup deep-link handler
- [x] Observability:
  - structured logs for create/publish/enroll/idempotency events

## Test Evidence

- Backend tests:
  - `PrepSkul_Web/__tests__/group-classes/group-class-service.test.ts`
  - `PrepSkul_Web/__tests__/group-classes/group-class-token-parity.test.ts`
  - `PrepSkul_Web/__tests__/group-classes/group-class-routes.test.ts`
- App tests:
  - `test/features/group_classes/group_classes_ui_flow_test.dart`
  - `test/features/group_classes/my_sessions_group_visibility_test.dart`
  - `test/features/group_classes/group_class_join_deeplink_test.dart`
  - `test/features/group_classes/group_class_db_runtime_checks_test.dart`

## Runtime DB Verification (Manual)

Run:
- `docs/GROUP_CLASSES_DB_RUNTIME_CHECKS.sql`

Required pass:
- RLS enabled for `group_class_listings` and `group_class_enrollments`
- required policies present
- unique constraints/indexes present
- paid enrollments link to `individual_session_id` and participant rows

## Release/UAT Matrix (Pending Human Validation)

- [ ] Create listing (draft + publish) with verified tutor account
- [ ] Enroll learner seat and complete payment
- [ ] Confirm learner appears in `session_participants`
- [ ] Confirm learner sees class session in My Sessions
- [ ] Validate `/join/class/:token` outcomes:
  - paid learner: allowed
  - unpaid/non-enrolled learner: blocked
  - tutor owner: allowed
- [ ] Reliability run alignment: include 1:1, 1:3, 1:5 scenarios where group classes feed live session attendance
- [ ] Execute `docs/GROUP_CLASSES_UAT_RUNBOOK.md` and publish filled report at:
  - `docs/GROUP_CLASSES_UAT_REPORT_2026-04-25.md` (or latest run date variant)

## Rollout Guardrails

- Start with internal/staff cohort only
- Expand by verified tutors cohort
- Monitor:
  - listing create/publish error rate
  - enrollment conflict/full-class rejection rate
  - payment-finalization to participant-upsert success rate
  - join-link validation failure rate
- QA env toggles and setup:
  - `docs/QA_ENV_SETUP.md`

## Final Gate

- [ ] Engineering signoff
- [ ] QA signoff
- [ ] Product signoff
- [ ] Support readiness note

