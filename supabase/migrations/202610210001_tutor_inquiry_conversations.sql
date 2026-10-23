-- A learner can ask an approved tutor a question before booking.
begin;
alter table public.conversations add column if not exists is_inquiry boolean not null default false;
alter table public.conversations drop constraint one_context;
alter table public.conversations add constraint one_context check (
  num_nonnulls(trial_session_id, booking_request_id, recurring_session_id, individual_session_id)
  + is_inquiry::integer = 1
);
create unique index if not exists conversations_inquiry_pair
  on public.conversations(student_id, tutor_id) where is_inquiry;

create policy "Inquiry creation belongs to the learner" on public.conversations
  as restrictive for insert to authenticated
  with check (not is_inquiry or (
    student_id = auth.uid() and tutor_id <> auth.uid()
    and exists (select 1 from public.tutor_profiles t
      where t.user_id = tutor_id and t.status = 'approved' and not coalesce(t.is_hidden, false))
  ));

create or replace function public.open_tutor_inquiry(p_tutor_id uuid)
returns uuid language plpgsql security definer set search_path = '' as $$
declare
  learner uuid := auth.uid();
  conversation_id uuid;
begin
  if learner is null then raise exception 'Sign in to message a tutor' using errcode = '42501'; end if;
  if learner = p_tutor_id then raise exception 'Cannot message yourself' using errcode = '22023'; end if;
  if not exists (select 1 from public.profiles where id = learner and user_type in ('student', 'parent')) then
    raise exception 'A learner account is required' using errcode = '42501';
  end if;
  if not exists (select 1 from public.tutor_profiles where user_id = p_tutor_id and status = 'approved' and not coalesce(is_hidden, false)) then
    raise exception 'This tutor is not available for enquiries' using errcode = '42501';
  end if;
  perform pg_advisory_xact_lock(hashtextextended(learner::text || ':' || p_tutor_id::text, 0));
  if exists (select 1 from public.conversations where student_id = learner and tutor_id = p_tutor_id and status = 'blocked') then
    raise exception 'Messaging is unavailable for this conversation' using errcode = '42501';
  end if;
  select id into conversation_id from public.conversations
    where student_id = learner and tutor_id = p_tutor_id and status = 'active'
    and (expires_at is null or expires_at > now())
    order by created_at desc limit 1;
  if conversation_id is not null then return conversation_id; end if;
  insert into public.conversations(student_id,tutor_id,is_inquiry,status)
    values (learner,p_tutor_id,true,'active')
    on conflict (student_id,tutor_id) where is_inquiry
    do update set status = 'active', expires_at = null, updated_at = now()
    returning id into conversation_id;
  return conversation_id;
end;
$$;
revoke all on function public.open_tutor_inquiry(uuid) from public, anon;
grant execute on function public.open_tutor_inquiry(uuid) to authenticated;
commit;
