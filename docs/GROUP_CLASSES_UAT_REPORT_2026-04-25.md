# Group Classes UAT Report (Run 1)

Run Date: 2026-04-25  
Run Owner:  
Environment: staging  
Build/Commit:  

## Global pre-check

- [ ] `GROUP_CLASSES_ENABLED=true`
- [ ] `CLASSROOM_ORCHESTRATOR_ENABLED=true`
- [ ] `CLASSROOM_DUAL_STREAM_ENABLED=true`
- [ ] `CLASSROOM_QOE_TELEMETRY_ENABLED=true`
- [ ] Migrations through `080_group_class_share_tokens.sql` applied
- [ ] Payment webhook active in environment
- [ ] DB runtime checks passed (`docs/GROUP_CLASSES_DB_RUNTIME_CHECKS.sql`)

## Listing + Enrollment + Session Linkage

- Listing ID:
- Share Token:
- Tutor ID:
- Learner ID:
- Enrollment ID:
- Payment Request ID:
- Linked `individual_session_id`:
- `session_participants` learner row exists: `yes/no`
- `session_participants` tutor row exists: `yes/no`
- Result: `PASS/FAIL`
- Evidence links:
- Notes:

## Deep-Link Access Control

### Paid learner join (`learner_01`)
- Input link:
- Outcome: `allowed/blocked`
- Navigated to video session: `yes/no`
- Result: `PASS/FAIL`
- Evidence:

### Unpaid user join (`observer_unpaid_01`)
- Input link:
- Outcome: `allowed/blocked`
- Redirected to discovery/enroll path: `yes/no`
- Result: `PASS/FAIL`
- Evidence:

### Tutor owner join (`tutor_verified_01`)
- Input link:
- Outcome: `allowed/blocked`
- Navigated to video session: `yes/no`
- Result: `PASS/FAIL`
- Evidence:

## Scenario: 1:1 baseline

- Session ID:
- Correlation ID:
- Participants:
- Start/End:
- Hard drop observed: `yes/no`
- Reconnect UX clear/non-conflicting: `yes/no`
- QoE events present: `yes/no`
- Result: `PASS/FAIL`
- Evidence links:
- Notes:

## Scenario: 1:3 classroom

- Session ID:
- Correlation ID:
- Participants:
- Start/End:
- Hard drop observed: `yes/no`
- Reconnect UX clear/non-conflicting: `yes/no`
- QoE events present: `yes/no`
- Result: `PASS/FAIL`
- Evidence links:
- Notes:

## Scenario: 1:5 classroom

- Session ID:
- Correlation ID:
- Participants:
- Start/End:
- Hard drop observed: `yes/no`
- Reconnect UX clear/non-conflicting: `yes/no`
- QoE events present: `yes/no`
- Result: `PASS/FAIL`
- Evidence links:
- Notes:

## Degraded Network Scenarios

### Loss profile
- Session ID:
- Correlation ID:
- Injection profile:
- Reconnect/freeze behavior acceptable: `yes/no`
- QoE events present: `yes/no`
- Result: `PASS/FAIL`
- Evidence:

### Latency profile
- Session ID:
- Correlation ID:
- Injection profile:
- Reconnect/freeze behavior acceptable: `yes/no`
- QoE events present: `yes/no`
- Result: `PASS/FAIL`
- Evidence:

### Jitter profile
- Session ID:
- Correlation ID:
- Injection profile:
- Reconnect/freeze behavior acceptable: `yes/no`
- QoE events present: `yes/no`
- Result: `PASS/FAIL`
- Evidence:

## QoE query outputs attached

- [ ] Event count summary per correlation ID
- [ ] Event timeline per correlation ID
- [ ] Freeze summary
- [ ] Reconnect summary

## Final gate decision

- Group classes UAT gate: `PASS/FAIL`
- Release reliability gate: `PASS/FAIL`
- Blockers:
- Mitigations:
- Rollout recommendation:
  - `internal only`
  - `expand to verified tutor cohort`
  - `hold rollout`

Engineering signoff:  
QA signoff:  
Product signoff:  
Date:

