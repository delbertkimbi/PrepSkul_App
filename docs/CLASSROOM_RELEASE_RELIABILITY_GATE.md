# Classroom Release Reliability Gate

Owner: Engineering + QA  
Scope: Video classroom reliability before broad rollout

## Required scenarios

- 1:1 baseline (tutor + learner)
- 1:3 classroom (tutor + 3 learners)
- 1:5 classroom (tutor + 5 learners)
- Degraded network runs:
  - packet loss bursts
  - latency spikes
  - jitter bursts

## Pass criteria (must all pass)

- No hard call drop caused by reconnect loop in mandatory scenarios.
- Reconnect outcomes are visible in `session_qoe_events`.
- Stream switch events are visible in `session_qoe_events`.
- Quality tier transitions are visible in `session_qoe_events`.
- Freeze start/end telemetry is present for induced freeze conditions.
- Session UX remains understandable (no conflicting state banners).

## Rollout controls (must be enabled/configured)

- `CLASSROOM_ORCHESTRATOR_ENABLED`
- `CLASSROOM_DUAL_STREAM_ENABLED`
- `CLASSROOM_QOE_TELEMETRY_ENABLED`

## Evidence capture checklist

- [ ] Test run artifacts/logs attached for 1:1, 1:3, 1:5.
- [ ] Degraded network run artifacts attached.
- [ ] Representative telemetry query output attached for each event type.
- [ ] Final signoff from Engineering + QA.

## Execution script (run order)

1. Confirm rollout flags are ON in environment:
   - `CLASSROOM_ORCHESTRATOR_ENABLED=true`
   - `CLASSROOM_DUAL_STREAM_ENABLED=true`
   - `CLASSROOM_QOE_TELEMETRY_ENABLED=true`
2. Run scenario matrix in this order:
   - 1:1 baseline
   - 1:3
   - 1:5
   - degraded network matrix (loss, latency, jitter)
3. For each run:
   - record `session_id`, start/end timestamps, and test participants
   - capture UI video/screenshots for state transitions (joining/reconnecting/resumed)
   - export QoE query output (event timeline + counts)
4. Mark scenario result as pass/fail with reason.
5. Block release if any mandatory scenario fails.

## QoE query checks (must pass)

For each reliability run, verify these event families exist in `session_qoe_events`:

- `quality_tier_changed`
- `remote_stream_type_changed`
- reconnect outcomes:
  - `reconnect_attempt`
  - `reconnect_success` or `reconnect_failed`/`reconnect_exhausted`
- freeze lifecycle:
  - `remote_freeze_start`
  - `remote_freeze_end`

Example validation query pattern:

```sql
select
  event_name,
  count(*) as event_count
from public.session_qoe_events
where correlation_id = :correlation_id
group by event_name
order by event_name;
```

## Scenario result template

Use one block per run:

- Scenario: `1:1 | 1:3 | 1:5 | degraded-loss | degraded-latency | degraded-jitter`
- Session ID:
- Correlation ID:
- Start/End:
- Hard drop observed: `yes/no`
- Reconnect UX clear/non-conflicting: `yes/no`
- QoE events present: `yes/no` (attach query output)
- Result: `PASS/FAIL`
- Notes:

## Signoff

- Engineering signoff:
- QA signoff:
- Date:

## Report template

Use `docs/CLASSROOM_RELEASE_RUN_REPORT_TEMPLATE.md` to capture all scenario evidence and final gate decision.
