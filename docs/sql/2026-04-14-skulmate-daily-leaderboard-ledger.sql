-- SkulMate daily leaderboard deterministic notification ledger
-- Target: Supabase Postgres
-- Run order: safe to run once (idempotent DDL)

create extension if not exists pgcrypto;

-- 1) Notification run ledger
create table if not exists public.skulmate_notification_runs (
  id uuid primary key default gen_random_uuid(),
  run_date date not null,                         -- UTC day
  trigger_source text not null,                   -- e.g. external-cron
  status text not null default 'running',         -- running|completed|failed|partial
  started_at timestamptz not null default now(),
  finished_at timestamptz,
  metadata jsonb not null default '{}'::jsonb
);

create unique index if not exists ux_skulmate_notification_runs_date_source
  on public.skulmate_notification_runs (run_date, trigger_source);

create index if not exists ix_skulmate_notification_runs_status_started
  on public.skulmate_notification_runs (status, started_at desc);

-- 2) Per-recipient deterministic delivery ledger
create table if not exists public.skulmate_notification_deliveries (
  id uuid primary key default gen_random_uuid(),
  run_id uuid not null references public.skulmate_notification_runs(id) on delete cascade,
  run_date date not null,
  user_id uuid not null references public.profiles(id) on delete cascade,
  event_type text not null,                        -- skulmate_daily_leaderboard
  event_key text not null,                         -- deterministic unique key
  payload jsonb not null,                          -- title/message/action/data

  in_app_status text not null default 'pending',   -- pending|sent|failed
  push_status text not null default 'pending',     -- pending|sent|failed|skipped

  in_app_notification_id uuid,                     -- notifications.id if created
  push_provider_id text,                           -- fcm provider id
  attempt_count int not null default 0,
  last_error text,

  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create unique index if not exists ux_skulmate_delivery_event_key
  on public.skulmate_notification_deliveries (event_key);

create index if not exists ix_skulmate_delivery_pending
  on public.skulmate_notification_deliveries (in_app_status, push_status, created_at);

create index if not exists ix_skulmate_delivery_user_date
  on public.skulmate_notification_deliveries (user_id, run_date desc);

-- 3) Optional API idempotency table
create table if not exists public.api_idempotency_keys (
  key text primary key,
  endpoint text not null,
  response_code int,
  response_body jsonb,
  created_at timestamptz not null default now(),
  expires_at timestamptz
);

create index if not exists ix_api_idempotency_endpoint_created
  on public.api_idempotency_keys (endpoint, created_at desc);

-- 4) Updated-at trigger function
create or replace function public.set_updated_at_timestamp()
returns trigger
language plpgsql
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

drop trigger if exists trg_skulmate_notification_deliveries_updated_at
  on public.skulmate_notification_deliveries;

create trigger trg_skulmate_notification_deliveries_updated_at
before update on public.skulmate_notification_deliveries
for each row
execute function public.set_updated_at_timestamp();

-- 5) RLS
alter table public.skulmate_notification_runs enable row level security;
alter table public.skulmate_notification_deliveries enable row level security;
alter table public.api_idempotency_keys enable row level security;

-- Client users do not need direct access.
drop policy if exists "No direct client access runs" on public.skulmate_notification_runs;
create policy "No direct client access runs"
  on public.skulmate_notification_runs
  for all
  using (false)
  with check (false);

drop policy if exists "No direct client access deliveries" on public.skulmate_notification_deliveries;
create policy "No direct client access deliveries"
  on public.skulmate_notification_deliveries
  for all
  using (false)
  with check (false);

drop policy if exists "No direct client access idempotency" on public.api_idempotency_keys;
create policy "No direct client access idempotency"
  on public.api_idempotency_keys
  for all
  using (false)
  with check (false);

-- 6) Helper view: current UTC day top leaderboard
create or replace view public.skulmate_daily_top_view as
select
  l.period_start::date as run_date,
  l.user_id,
  coalesce(p.full_name, l.user_name, 'Player') as user_name,
  l.total_xp,
  l.games_played,
  l.rank
from public.skulmate_leaderboards l
left join public.profiles p on p.id = l.user_id
where l.period = 'daily';

