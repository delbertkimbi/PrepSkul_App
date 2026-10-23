begin;
create schema if not exists booking_private;
revoke all on schema booking_private from public, anon;
grant usage on schema booking_private to authenticated;

-- RLS must continue hiding other learners' records. Only occupied minutes leave
-- this privileged function; there are no names, identifiers or payment details.
create or replace function booking_private.tutor_busy_windows(p_tutor_id uuid, p_date date)
returns table(start_minute integer, end_minute integer)
language plpgsql stable security definer set search_path = '' as $$
begin
  if auth.uid() is null then raise exception 'Sign in to check availability' using errcode = '42501'; end if;
  if p_date is null or p_date < current_date - 1 or p_date > current_date + 180 then
    raise exception 'Choose a date within the next 180 days' using errcode = '22023';
  end if;
  if not exists (select 1 from public.tutor_profiles t where t.user_id = p_tutor_id and t.status = 'approved' and not coalesce(t.is_hidden,false)) then
    raise exception 'Tutor unavailable' using errcode = '22023';
  end if;
  return query
  with occupied as (
    select (s.scheduled_date - p_date) * 1440 + (extract(epoch from s.scheduled_time::time)/60)::integer as a,
           s.duration_minutes as duration
      from public.individual_sessions s
      where s.tutor_id=p_tutor_id and s.scheduled_date between p_date-1 and p_date+1
        and s.status in ('scheduled','in_progress','completed')
    union all
    select (s.scheduled_date - p_date) * 1440 + (extract(epoch from s.scheduled_time::time)/60)::integer,
           s.duration_minutes
      from public.trial_sessions s
      where s.tutor_id=p_tutor_id and s.scheduled_date between p_date-1 and p_date+1
        and s.status in ('pending','confirmed','completed')
    union all
    select d.offset_days * 1440 + (extract(epoch from (s.times ->> trim(to_char(p_date+d.offset_days,'Day')))::time)/60)::integer, 60
      from public.recurring_sessions s cross join (values (-1),(0),(1)) d(offset_days)
      where s.tutor_id=p_tutor_id and s.status='active'
        and s.start_date::date <= p_date+d.offset_days
        and (s.end_date is null or s.end_date::date >= p_date+d.offset_days)
        and s.times ? trim(to_char(p_date+d.offset_days,'Day'))
  )
  select distinct a, a + duration from occupied where a < 2880 and a + duration > 0;
end;
$$;
revoke all on function booking_private.tutor_busy_windows(uuid,date) from public, anon;
grant execute on function booking_private.tutor_busy_windows(uuid,date) to authenticated;
create or replace function public.tutor_busy_windows(p_tutor_id uuid,p_date date)
returns table(start_minute integer,end_minute integer)
language sql stable security invoker set search_path = '' as $$
  select * from booking_private.tutor_busy_windows(p_tutor_id,p_date);
$$;
revoke all on function public.tutor_busy_windows(uuid,date) from public, anon;
grant execute on function public.tutor_busy_windows(uuid,date) to authenticated;
commit;
