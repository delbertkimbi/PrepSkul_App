# GC-206 Prejoin Reliability Pass Report (2026-04-27)

Task: Run paid vs unpaid prejoin reliability pass (3/3) and record evidence.

## Method used

Executed the same backend prejoin authorization suites three consecutive times to detect instability/flakiness in token gating logic:

- `__tests__/group-classes/group-class-token-parity.test.ts`
- `__tests__/agora/session-service-authz.test.ts`

Command pattern:

- `npm test -- <suite A> <suite B>` repeated 3x sequentially.

## Results (3-pass matrix)

- **Run 1**: PASS
  - Suites: 2/2
  - Tests: 8/8
- **Run 2**: PASS
  - Suites: 2/2
  - Tests: 8/8
- **Run 3**: PASS
  - Suites: 2/2
  - Tests: 8/8

Aggregate:

- **6/6 suites passed**
- **24/24 tests passed**
- No intermittent failures observed across repeated runs.

## What this validates

- Session access authorization is stable for participant role checks.
- Unauthorized/non-participant paths are consistently blocked.
- Token parity logic remains intact across repeated execution.

## Scope caveat

This is automated backend reliability evidence (not full browser/manual UAT lane execution).  
Full end-to-end create -> enroll -> pay -> join evidence per lane remains covered under `group-19-uat-matrix`.

## Decision

- `gc-206` criteria met for automated reliability pass (3/3).
- Proceed to `gc-207` (regression tests for join authorization parity expansion).
