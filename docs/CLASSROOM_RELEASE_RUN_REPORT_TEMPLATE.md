# Classroom Release Run Report (Template)

Run Date:  
Run Owner:  
Environment:  
Build/Commit:  

## Global pre-check

- [ ] `CLASSROOM_ORCHESTRATOR_ENABLED=true`
- [ ] `CLASSROOM_DUAL_STREAM_ENABLED=true`
- [ ] `CLASSROOM_QOE_TELEMETRY_ENABLED=true`
- [ ] Telemetry table accessible: `session_qoe_events`

## Scenario: 1:1 baseline

- Session ID:
- Correlation ID:
- Participants:
- Start/End:
- Hard drop observed: `yes/no`
- Reconnect UX clear/non-conflicting: `yes/no`
- QoE events present: `yes/no`
- Result: `PASS/FAIL`
- Evidence links (video/screenshots/logs):
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
- Evidence links (video/screenshots/logs):
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
- Evidence links (video/screenshots/logs):
- Notes:

## Scenario: degraded network (loss)

- Session ID:
- Correlation ID:
- Injection profile:
- Start/End:
- Reconnect/freeze behavior acceptable: `yes/no`
- QoE events present: `yes/no`
- Result: `PASS/FAIL`
- Evidence links:
- Notes:

## Scenario: degraded network (latency)

- Session ID:
- Correlation ID:
- Injection profile:
- Start/End:
- Reconnect/freeze behavior acceptable: `yes/no`
- QoE events present: `yes/no`
- Result: `PASS/FAIL`
- Evidence links:
- Notes:

## Scenario: degraded network (jitter)

- Session ID:
- Correlation ID:
- Injection profile:
- Start/End:
- Reconnect/freeze behavior acceptable: `yes/no`
- QoE events present: `yes/no`
- Result: `PASS/FAIL`
- Evidence links:
- Notes:

## QoE query outputs attached

- [ ] Event count summary per correlation ID
- [ ] Event timeline per correlation ID
- [ ] Freeze summary
- [ ] Reconnect summary

## Final gate decision

- Release Reliability Gate: `PASS/FAIL`
- Blockers (if any):
- Mitigation actions:

Engineering signoff:  
QA signoff:  
Date:
