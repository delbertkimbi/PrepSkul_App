-- Classroom QoE telemetry validation queries
-- Use these after each reliability gate run.

-- 1) Event counts by event name for a single correlation id
select
  event_name,
  count(*) as event_count
from public.session_qoe_events
where correlation_id = :correlation_id
group by event_name
order by event_name;

-- 2) Timeline for a single correlation id
select
  event_at,
  event_name,
  event_source,
  payload
from public.session_qoe_events
where correlation_id = :correlation_id
order by event_at asc;

-- 3) Freeze windows summary (start/end counts)
select
  sum(case when event_name = 'remote_freeze_start' then 1 else 0 end) as freeze_start_count,
  sum(case when event_name = 'remote_freeze_end' then 1 else 0 end) as freeze_end_count
from public.session_qoe_events
where correlation_id = :correlation_id;

-- 4) Reconnect outcome summary
select
  sum(case when event_name = 'reconnect_attempt' then 1 else 0 end) as reconnect_attempts,
  sum(case when event_name = 'reconnect_success' then 1 else 0 end) as reconnect_successes,
  sum(case when event_name in ('reconnect_failed', 'reconnect_exhausted') then 1 else 0 end) as reconnect_failures
from public.session_qoe_events
where correlation_id = :correlation_id;
