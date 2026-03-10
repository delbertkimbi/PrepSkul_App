-- Add call_timer_started_at: when both participants are in the call and the in-call timer starts.
-- Used so that when a user refreshes and rejoins, they sync to the same remaining time.
alter table public.individual_sessions
  add column if not exists call_timer_started_at timestamp with time zone null;

comment on column public.individual_sessions.call_timer_started_at is
  'When the in-call countdown timer started (both participants in call). Used for timer sync on rejoin.';

-- RPC: ensure call_timer_started_at is set for this session (first caller wins), return the value.
-- Caller must be tutor or learner of the session.
create or replace function public.ensure_call_timer_started(p_session_id uuid)
returns timestamp with time zone
language plpgsql
security definer
set search_path = public
as $$
declare
  v_started timestamp with time zone;
begin
  if not exists (
    select 1 from individual_sessions
    where id = p_session_id and (tutor_id = auth.uid() or learner_id = auth.uid())
  ) then
    return null;
  end if;

  update individual_sessions
  set call_timer_started_at = now()
  where id = p_session_id and call_timer_started_at is null
  returning call_timer_started_at into v_started;

  if v_started is not null then
    return v_started;
  end if;

  select call_timer_started_at into v_started from individual_sessions where id = p_session_id;
  return v_started;
end;
$$;
