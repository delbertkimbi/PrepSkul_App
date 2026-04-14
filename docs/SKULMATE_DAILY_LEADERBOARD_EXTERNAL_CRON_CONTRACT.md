# SkulMate Daily Leaderboard Notification Contract (External Cron)

This contract defines how to send daily "top of chart" notifications in a globally deterministic way:

- Exactly once per user per UTC day
- Independent of app open state
- Driven by an external scheduler (not Vercel Cron)

## 1) Scope

Event: Daily leaderboard summary push + in-app notification for SkulMate players.

Example title format policy:

- No leading emoji
- At most one emoji at the end when useful
- Example: `Daily game chart update ⚡`

## 2) Determinism Rules

Determinism key:

`event_key = skulmate_daily_leaderboard:<yyyy-mm-dd>:<user_id>`

Rules:

1. A user receives at most one notification for each UTC date.
2. Retries must be safe (idempotent) and must not duplicate notifications.
3. Partial failures (push API down, DB timeout) must be resumable.

## 3) Required Tables

### 3.1 Notification Run Ledger

```sql
create table if not exists skulmate_notification_runs (
  id uuid primary key default gen_random_uuid(),
  run_date date not null,                        -- UTC day this run targets
  trigger_source text not null,                  -- e.g. 'external-cron'
  status text not null default 'running',        -- running|completed|failed|partial
  started_at timestamptz not null default now(),
  finished_at timestamptz,
  metadata jsonb not null default '{}'::jsonb
);

create unique index if not exists ux_skulmate_notification_runs_date_source
  on skulmate_notification_runs (run_date, trigger_source);
```

### 3.2 Per-Recipient Delivery Ledger (Idempotency Core)

```sql
create table if not exists skulmate_notification_deliveries (
  id uuid primary key default gen_random_uuid(),
  run_id uuid not null references skulmate_notification_runs(id) on delete cascade,
  run_date date not null,
  user_id uuid not null references profiles(id) on delete cascade,
  event_type text not null,                      -- 'skulmate_daily_leaderboard'
  event_key text not null,                       -- deterministic unique key
  payload jsonb not null,                        -- title/message/action/data
  in_app_status text not null default 'pending', -- pending|sent|failed
  push_status text not null default 'pending',   -- pending|sent|failed|skipped
  in_app_notification_id uuid,                   -- notifications.id if created
  push_provider_id text,                         -- FCM provider id if any
  attempt_count int not null default 0,
  last_error text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create unique index if not exists ux_skulmate_delivery_event_key
  on skulmate_notification_deliveries (event_key);
```

### 3.3 Optional Trigger Idempotency Guard (API Layer)

```sql
create table if not exists api_idempotency_keys (
  key text primary key,
  endpoint text not null,
  response_code int,
  response_body jsonb,
  created_at timestamptz not null default now(),
  expires_at timestamptz
);
```

## 4) Recipient Set Definition

Default recipient set (players):

- Users with at least one non-deleted SkulMate game, or
- Users with at least one SkulMate game session.

Use one canonical SQL query in backend for this set. Do not split logic across clients.

## 5) Top Leader Snapshot Definition

For run date `D`:

- Evaluate daily leaderboard period `[D 00:00:00 UTC, D+1 00:00:00 UTC)`.
- Select top player by:
  1. highest `total_xp`
  2. if tie: higher `games_played`
  3. if tie: lower `rank` (if precomputed)
  4. final tie-breaker: stable `user_id` ascending

Store top snapshot in run metadata:

```json
{
  "top_user_id": "uuid",
  "top_user_name": "string",
  "top_xp": 1234
}
```

## 6) External Cron Trigger Contract

Your external scheduler calls backend endpoint once per UTC day.

### 6.1 Endpoint

`POST /api/cron/skulmate/daily-leaderboard-notify`

### 6.2 Auth

- Header: `Authorization: Bearer <CRON_SHARED_SECRET_OR_JWT>`
- Reject if missing/invalid.

### 6.3 Request Payload

```json
{
  "runDate": "2026-04-14",
  "triggerSource": "external-cron",
  "dryRun": false
}
```

### 6.4 Response

```json
{
  "runId": "uuid",
  "runDate": "2026-04-14",
  "status": "completed",
  "recipientCount": 10234,
  "inAppSent": 10234,
  "pushSent": 9980,
  "failed": 254
}
```

## 7) Execution Algorithm (Server)

1. Start transaction.
2. Upsert into `skulmate_notification_runs` with `(run_date, trigger_source)` unique key.
3. Compute top snapshot once.
4. Build recipient list once.
5. For each recipient, create deterministic `event_key`.
6. Insert into `skulmate_notification_deliveries` with `on conflict(event_key) do nothing`.
7. Commit transaction.
8. Worker loop sends in-app then push for rows with pending statuses.
9. Update delivery row atomically per send attempt.
10. Mark run `completed`/`partial`/`failed`.

Retry behavior:

- Re-running same day is safe due to `event_key` uniqueness.
- Failed rows remain retryable without creating duplicates.

## 8) In-App Notification Payload Contract

Type: `skulmate_daily_leaderboard`

```json
{
  "type": "skulmate_daily_leaderboard",
  "title": "Daily game chart update ⚡",
  "message": "Ava is topping today's game chart with 1240 XP.",
  "actionUrl": "/skulmate/leaderboard",
  "actionText": "View leaderboard",
  "metadata": {
    "period": "daily",
    "top_user_id": "uuid",
    "top_user_name": "Ava",
    "top_xp": 1240,
    "run_date": "2026-04-14"
  }
}
```

## 9) Push Payload Contract (FCM/Data)

```json
{
  "notification": {
    "title": "Daily game chart update ⚡",
    "body": "Ava is topping today's game chart with 1240 XP."
  },
  "data": {
    "type": "skulmate_daily_leaderboard",
    "actionUrl": "/skulmate/leaderboard",
    "period": "daily",
    "runDate": "2026-04-14",
    "topUserId": "uuid"
  }
}
```

## 10) Observability and SLO

Track:

- total recipients
- in-app success %
- push success %
- duplicate prevented count
- retries and dead-letter count

Suggested SLO:

- 99% runs complete within 10 minutes of cron trigger.
- 0 duplicate deliveries per `event_key`.

## 11) Rollout Plan

1. Deploy schema and endpoint.
2. Dry-run for 2 days (`dryRun=true`) and validate counts.
3. Enable push sending.
4. Enable external cron production trigger.
5. Monitor delivery ledger and retry pipeline.

## 12) Non-Goals (for this contract)

- Weekly/monthly summary emails
- Personalized rank trend explanations
- Cross-device read state sync redesign

