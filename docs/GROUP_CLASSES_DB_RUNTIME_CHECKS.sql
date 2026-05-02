-- Group Classes runtime DB verification checks
-- Run after applying migrations 079 and 080.

-- 1) Tables and key columns exist
select table_name, column_name
from information_schema.columns
where table_schema = 'public'
  and table_name in ('group_class_listings', 'group_class_enrollments')
  and column_name in (
    'id',
    'tutor_id',
    'individual_session_id',
    'capacity',
    'status',
    'share_token',
    'listing_id',
    'user_id',
    'payment_request_id'
  )
order by table_name, column_name;

-- 2) Unique share token index exists
select indexname, indexdef
from pg_indexes
where schemaname = 'public'
  and tablename = 'group_class_listings'
  and indexname = 'idx_group_class_listings_share_token';

-- 3) Enrollment uniqueness constraint exists
select conname, pg_get_constraintdef(c.oid) as constraint_def
from pg_constraint c
join pg_class t on t.oid = c.conrelid
join pg_namespace n on n.oid = t.relnamespace
where n.nspname = 'public'
  and t.relname = 'group_class_enrollments'
  and conname = 'group_class_enrollments_unique_listing_user';

-- 4) RLS enabled on both tables
select relname as table_name, relrowsecurity as rls_enabled
from pg_class
where relname in ('group_class_listings', 'group_class_enrollments')
order by relname;

-- 5) RLS policies present
select tablename, policyname, permissive, roles, cmd
from pg_policies
where schemaname = 'public'
  and tablename in ('group_class_listings', 'group_class_enrollments')
order by tablename, policyname;

-- 6) Paid enrollment to listing-session linkage sanity check
-- Replace :user_id with a real user UUID as needed.
select
  gce.id as enrollment_id,
  gce.status as enrollment_status,
  gce.user_id,
  gcl.id as listing_id,
  gcl.individual_session_id,
  gcl.status as listing_status
from public.group_class_enrollments gce
join public.group_class_listings gcl on gcl.id = gce.listing_id
where gce.status = 'paid'
  and gce.user_id = :user_id
order by gce.created_at desc
limit 20;

-- 7) Session participant parity check for paid group enrollments
-- Replace :user_id as needed.
select
  gce.user_id,
  gcl.individual_session_id,
  exists (
    select 1
    from public.session_participants sp
    where sp.user_id = gce.user_id
      and sp.individual_session_id = gcl.individual_session_id
  ) as learner_participant_exists
from public.group_class_enrollments gce
join public.group_class_listings gcl on gcl.id = gce.listing_id
where gce.status = 'paid'
  and gcl.individual_session_id is not null
  and gce.user_id = :user_id
order by gce.created_at desc
limit 20;

