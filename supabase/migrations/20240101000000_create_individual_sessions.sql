-- Create individual_sessions table
create table if not exists public.individual_sessions (
  id uuid not null default gen_random_uuid (),
  recurring_session_id uuid null,
  tutor_id uuid null,
  learner_id uuid null,
  parent_id uuid null,
  status text not null default 'scheduled'::text,
  scheduled_date date not null,
  scheduled_time text not null,
  -- Short subject/summary of the session (e.g. "Mathematics" / "Physics")
  subject text null,
  duration_minutes integer not null default 60,
  actual_duration_minutes integer null,
  location text not null default 'online'::text,
  meeting_link text null,
  address text null,
  location_description text null,
  session_started_at timestamp with time zone null,
  session_ended_at timestamp with time zone null,
  tutor_joined_at timestamp with time zone null,
  learner_joined_at timestamp with time zone null,
  session_notes text null,
  cancellation_reason text null,
  cancelled_by uuid null,
  created_at timestamp with time zone not null default now(),
  updated_at timestamp with time zone not null default now(),
  constraint individual_sessions_pkey primary key (id),
  constraint individual_sessions_recurring_session_id_fkey foreign key (recurring_session_id) references recurring_sessions (id) on delete set null,
  constraint individual_sessions_tutor_id_fkey foreign key (tutor_id) references profiles (id) on delete cascade,
  constraint individual_sessions_learner_id_fkey foreign key (learner_id) references profiles (id) on delete cascade,
  constraint individual_sessions_parent_id_fkey foreign key (parent_id) references profiles (id) on delete set null,
  constraint individual_sessions_cancelled_by_fkey foreign key (cancelled_by) references profiles (id) on delete set null
);

-- Enable RLS
alter table public.individual_sessions enable row level security;

-- Create policies
create policy "Users can view their own sessions" on public.individual_sessions
  for select using (
    auth.uid() = tutor_id or 
    auth.uid() = learner_id or 
    auth.uid() = parent_id
  );

create policy "Tutors can update their own sessions" on public.individual_sessions
  for update using (
    auth.uid() = tutor_id
  );

create policy "Admins can view all sessions" on public.individual_sessions
  for select using (
    exists (
      select 1 from profiles
      where profiles.id = auth.uid() and profiles.is_admin = true
    )
  );


  id uuid not null default gen_random_uuid (),
  recurring_session_id uuid null,
  tutor_id uuid null,
  learner_id uuid null,
  parent_id uuid null,
  status text not null default 'scheduled'::text,
  scheduled_date date not null,
  scheduled_time text not null,
  -- Short subject/summary of the session (e.g. "Mathematics" / "Physics")
  subject text null,
  duration_minutes integer not null default 60,
  actual_duration_minutes integer null,
  location text not null default 'online'::text,
  meeting_link text null,
  address text null,
  location_description text null,
  session_started_at timestamp with time zone null,
  session_ended_at timestamp with time zone null,
  tutor_joined_at timestamp with time zone null,
  learner_joined_at timestamp with time zone null,
  session_notes text null,
  cancellation_reason text null,
  cancelled_by uuid null,
  created_at timestamp with time zone not null default now(),
  updated_at timestamp with time zone not null default now(),
  constraint individual_sessions_pkey primary key (id),
  constraint individual_sessions_recurring_session_id_fkey foreign key (recurring_session_id) references recurring_sessions (id) on delete set null,
  constraint individual_sessions_tutor_id_fkey foreign key (tutor_id) references profiles (id) on delete cascade,
  constraint individual_sessions_learner_id_fkey foreign key (learner_id) references profiles (id) on delete cascade,
  constraint individual_sessions_parent_id_fkey foreign key (parent_id) references profiles (id) on delete set null,
  constraint individual_sessions_cancelled_by_fkey foreign key (cancelled_by) references profiles (id) on delete set null
);

-- Enable RLS
alter table public.individual_sessions enable row level security;

-- Create policies
create policy "Users can view their own sessions" on public.individual_sessions
  for select using (
    auth.uid() = tutor_id or 
    auth.uid() = learner_id or 
    auth.uid() = parent_id
  );

create policy "Tutors can update their own sessions" on public.individual_sessions
  for update using (
    auth.uid() = tutor_id
  );

create policy "Admins can view all sessions" on public.individual_sessions
  for select using (
    exists (
      select 1 from profiles
      where profiles.id = auth.uid() and profiles.is_admin = true
    )
  );


  id uuid not null default gen_random_uuid (),
  recurring_session_id uuid null,
  tutor_id uuid null,
  learner_id uuid null,
  parent_id uuid null,
  status text not null default 'scheduled'::text,
  scheduled_date date not null,
  scheduled_time text not null,
  -- Short subject/summary of the session (e.g. "Mathematics" / "Physics")
  subject text null,
  duration_minutes integer not null default 60,
  actual_duration_minutes integer null,
  location text not null default 'online'::text,
  meeting_link text null,
  address text null,
  location_description text null,
  session_started_at timestamp with time zone null,
  session_ended_at timestamp with time zone null,
  tutor_joined_at timestamp with time zone null,
  learner_joined_at timestamp with time zone null,
  session_notes text null,
  cancellation_reason text null,
  cancelled_by uuid null,
  created_at timestamp with time zone not null default now(),
  updated_at timestamp with time zone not null default now(),
  constraint individual_sessions_pkey primary key (id),
  constraint individual_sessions_recurring_session_id_fkey foreign key (recurring_session_id) references recurring_sessions (id) on delete set null,
  constraint individual_sessions_tutor_id_fkey foreign key (tutor_id) references profiles (id) on delete cascade,
  constraint individual_sessions_learner_id_fkey foreign key (learner_id) references profiles (id) on delete cascade,
  constraint individual_sessions_parent_id_fkey foreign key (parent_id) references profiles (id) on delete set null,
  constraint individual_sessions_cancelled_by_fkey foreign key (cancelled_by) references profiles (id) on delete set null
);

-- Enable RLS
alter table public.individual_sessions enable row level security;

-- Create policies
create policy "Users can view their own sessions" on public.individual_sessions
  for select using (
    auth.uid() = tutor_id or 
    auth.uid() = learner_id or 
    auth.uid() = parent_id
  );

create policy "Tutors can update their own sessions" on public.individual_sessions
  for update using (
    auth.uid() = tutor_id
  );

create policy "Admins can view all sessions" on public.individual_sessions
  for select using (
    exists (
      select 1 from profiles
      where profiles.id = auth.uid() and profiles.is_admin = true
    )
  );




  id uuid not null default gen_random_uuid (),
  recurring_session_id uuid null,
  tutor_id uuid null,
  learner_id uuid null,
  parent_id uuid null,
  status text not null default 'scheduled'::text,
  scheduled_date date not null,
  scheduled_time text not null,
  -- Short subject/summary of the session (e.g. "Mathematics" / "Physics")
  subject text null,
  duration_minutes integer not null default 60,
  actual_duration_minutes integer null,
  location text not null default 'online'::text,
  meeting_link text null,
  address text null,
  location_description text null,
  session_started_at timestamp with time zone null,
  session_ended_at timestamp with time zone null,
  tutor_joined_at timestamp with time zone null,
  learner_joined_at timestamp with time zone null,
  session_notes text null,
  cancellation_reason text null,
  cancelled_by uuid null,
  created_at timestamp with time zone not null default now(),
  updated_at timestamp with time zone not null default now(),
  constraint individual_sessions_pkey primary key (id),
  constraint individual_sessions_recurring_session_id_fkey foreign key (recurring_session_id) references recurring_sessions (id) on delete set null,
  constraint individual_sessions_tutor_id_fkey foreign key (tutor_id) references profiles (id) on delete cascade,
  constraint individual_sessions_learner_id_fkey foreign key (learner_id) references profiles (id) on delete cascade,
  constraint individual_sessions_parent_id_fkey foreign key (parent_id) references profiles (id) on delete set null,
  constraint individual_sessions_cancelled_by_fkey foreign key (cancelled_by) references profiles (id) on delete set null
);

-- Enable RLS
alter table public.individual_sessions enable row level security;

-- Create policies
create policy "Users can view their own sessions" on public.individual_sessions
  for select using (
    auth.uid() = tutor_id or 
    auth.uid() = learner_id or 
    auth.uid() = parent_id
  );

create policy "Tutors can update their own sessions" on public.individual_sessions
  for update using (
    auth.uid() = tutor_id
  );

create policy "Admins can view all sessions" on public.individual_sessions
  for select using (
    exists (
      select 1 from profiles
      where profiles.id = auth.uid() and profiles.is_admin = true
    )
  );


  id uuid not null default gen_random_uuid (),
  recurring_session_id uuid null,
  tutor_id uuid null,
  learner_id uuid null,
  parent_id uuid null,
  status text not null default 'scheduled'::text,
  scheduled_date date not null,
  scheduled_time text not null,
  -- Short subject/summary of the session (e.g. "Mathematics" / "Physics")
  subject text null,
  duration_minutes integer not null default 60,
  actual_duration_minutes integer null,
  location text not null default 'online'::text,
  meeting_link text null,
  address text null,
  location_description text null,
  session_started_at timestamp with time zone null,
  session_ended_at timestamp with time zone null,
  tutor_joined_at timestamp with time zone null,
  learner_joined_at timestamp with time zone null,
  session_notes text null,
  cancellation_reason text null,
  cancelled_by uuid null,
  created_at timestamp with time zone not null default now(),
  updated_at timestamp with time zone not null default now(),
  constraint individual_sessions_pkey primary key (id),
  constraint individual_sessions_recurring_session_id_fkey foreign key (recurring_session_id) references recurring_sessions (id) on delete set null,
  constraint individual_sessions_tutor_id_fkey foreign key (tutor_id) references profiles (id) on delete cascade,
  constraint individual_sessions_learner_id_fkey foreign key (learner_id) references profiles (id) on delete cascade,
  constraint individual_sessions_parent_id_fkey foreign key (parent_id) references profiles (id) on delete set null,
  constraint individual_sessions_cancelled_by_fkey foreign key (cancelled_by) references profiles (id) on delete set null
);

-- Enable RLS
alter table public.individual_sessions enable row level security;

-- Create policies
create policy "Users can view their own sessions" on public.individual_sessions
  for select using (
    auth.uid() = tutor_id or 
    auth.uid() = learner_id or 
    auth.uid() = parent_id
  );

create policy "Tutors can update their own sessions" on public.individual_sessions
  for update using (
    auth.uid() = tutor_id
  );

create policy "Admins can view all sessions" on public.individual_sessions
  for select using (
    exists (
      select 1 from profiles
      where profiles.id = auth.uid() and profiles.is_admin = true
    )
  );


  id uuid not null default gen_random_uuid (),
  recurring_session_id uuid null,
  tutor_id uuid null,
  learner_id uuid null,
  parent_id uuid null,
  status text not null default 'scheduled'::text,
  scheduled_date date not null,
  scheduled_time text not null,
  -- Short subject/summary of the session (e.g. "Mathematics" / "Physics")
  subject text null,
  duration_minutes integer not null default 60,
  actual_duration_minutes integer null,
  location text not null default 'online'::text,
  meeting_link text null,
  address text null,
  location_description text null,
  session_started_at timestamp with time zone null,
  session_ended_at timestamp with time zone null,
  tutor_joined_at timestamp with time zone null,
  learner_joined_at timestamp with time zone null,
  session_notes text null,
  cancellation_reason text null,
  cancelled_by uuid null,
  created_at timestamp with time zone not null default now(),
  updated_at timestamp with time zone not null default now(),
  constraint individual_sessions_pkey primary key (id),
  constraint individual_sessions_recurring_session_id_fkey foreign key (recurring_session_id) references recurring_sessions (id) on delete set null,
  constraint individual_sessions_tutor_id_fkey foreign key (tutor_id) references profiles (id) on delete cascade,
  constraint individual_sessions_learner_id_fkey foreign key (learner_id) references profiles (id) on delete cascade,
  constraint individual_sessions_parent_id_fkey foreign key (parent_id) references profiles (id) on delete set null,
  constraint individual_sessions_cancelled_by_fkey foreign key (cancelled_by) references profiles (id) on delete set null
);

-- Enable RLS
alter table public.individual_sessions enable row level security;

-- Create policies
create policy "Users can view their own sessions" on public.individual_sessions
  for select using (
    auth.uid() = tutor_id or 
    auth.uid() = learner_id or 
    auth.uid() = parent_id
  );

create policy "Tutors can update their own sessions" on public.individual_sessions
  for update using (
    auth.uid() = tutor_id
  );

create policy "Admins can view all sessions" on public.individual_sessions
  for select using (
    exists (
      select 1 from profiles
      where profiles.id = auth.uid() and profiles.is_admin = true
    )
  );


  id uuid not null default gen_random_uuid (),
  recurring_session_id uuid null,
  tutor_id uuid null,
  learner_id uuid null,
  parent_id uuid null,
  status text not null default 'scheduled'::text,
  scheduled_date date not null,
  scheduled_time text not null,
  -- Short subject/summary of the session (e.g. "Mathematics" / "Physics")
  subject text null,
  duration_minutes integer not null default 60,
  actual_duration_minutes integer null,
  location text not null default 'online'::text,
  meeting_link text null,
  address text null,
  location_description text null,
  session_started_at timestamp with time zone null,
  session_ended_at timestamp with time zone null,
  tutor_joined_at timestamp with time zone null,
  learner_joined_at timestamp with time zone null,
  session_notes text null,
  cancellation_reason text null,
  cancelled_by uuid null,
  created_at timestamp with time zone not null default now(),
  updated_at timestamp with time zone not null default now(),
  constraint individual_sessions_pkey primary key (id),
  constraint individual_sessions_recurring_session_id_fkey foreign key (recurring_session_id) references recurring_sessions (id) on delete set null,
  constraint individual_sessions_tutor_id_fkey foreign key (tutor_id) references profiles (id) on delete cascade,
  constraint individual_sessions_learner_id_fkey foreign key (learner_id) references profiles (id) on delete cascade,
  constraint individual_sessions_parent_id_fkey foreign key (parent_id) references profiles (id) on delete set null,
  constraint individual_sessions_cancelled_by_fkey foreign key (cancelled_by) references profiles (id) on delete set null
);

-- Enable RLS
alter table public.individual_sessions enable row level security;

-- Create policies
create policy "Users can view their own sessions" on public.individual_sessions
  for select using (
    auth.uid() = tutor_id or 
    auth.uid() = learner_id or 
    auth.uid() = parent_id
  );

create policy "Tutors can update their own sessions" on public.individual_sessions
  for update using (
    auth.uid() = tutor_id
  );

create policy "Admins can view all sessions" on public.individual_sessions
  for select using (
    exists (
      select 1 from profiles
      where profiles.id = auth.uid() and profiles.is_admin = true
    )
  );


  id uuid not null default gen_random_uuid (),
  recurring_session_id uuid null,
  tutor_id uuid null,
  learner_id uuid null,
  parent_id uuid null,
  status text not null default 'scheduled'::text,
  scheduled_date date not null,
  scheduled_time text not null,
  -- Short subject/summary of the session (e.g. "Mathematics" / "Physics")
  subject text null,
  duration_minutes integer not null default 60,
  actual_duration_minutes integer null,
  location text not null default 'online'::text,
  meeting_link text null,
  address text null,
  location_description text null,
  session_started_at timestamp with time zone null,
  session_ended_at timestamp with time zone null,
  tutor_joined_at timestamp with time zone null,
  learner_joined_at timestamp with time zone null,
  session_notes text null,
  cancellation_reason text null,
  cancelled_by uuid null,
  created_at timestamp with time zone not null default now(),
  updated_at timestamp with time zone not null default now(),
  constraint individual_sessions_pkey primary key (id),
  constraint individual_sessions_recurring_session_id_fkey foreign key (recurring_session_id) references recurring_sessions (id) on delete set null,
  constraint individual_sessions_tutor_id_fkey foreign key (tutor_id) references profiles (id) on delete cascade,
  constraint individual_sessions_learner_id_fkey foreign key (learner_id) references profiles (id) on delete cascade,
  constraint individual_sessions_parent_id_fkey foreign key (parent_id) references profiles (id) on delete set null,
  constraint individual_sessions_cancelled_by_fkey foreign key (cancelled_by) references profiles (id) on delete set null
);

-- Enable RLS
alter table public.individual_sessions enable row level security;

-- Create policies
create policy "Users can view their own sessions" on public.individual_sessions
  for select using (
    auth.uid() = tutor_id or 
    auth.uid() = learner_id or 
    auth.uid() = parent_id
  );

create policy "Tutors can update their own sessions" on public.individual_sessions
  for update using (
    auth.uid() = tutor_id
  );

create policy "Admins can view all sessions" on public.individual_sessions
  for select using (
    exists (
      select 1 from profiles
      where profiles.id = auth.uid() and profiles.is_admin = true
    )
  );


  id uuid not null default gen_random_uuid (),
  recurring_session_id uuid null,
  tutor_id uuid null,
  learner_id uuid null,
  parent_id uuid null,
  status text not null default 'scheduled'::text,
  scheduled_date date not null,
  scheduled_time text not null,
  -- Short subject/summary of the session (e.g. "Mathematics" / "Physics")
  subject text null,
  duration_minutes integer not null default 60,
  actual_duration_minutes integer null,
  location text not null default 'online'::text,
  meeting_link text null,
  address text null,
  location_description text null,
  session_started_at timestamp with time zone null,
  session_ended_at timestamp with time zone null,
  tutor_joined_at timestamp with time zone null,
  learner_joined_at timestamp with time zone null,
  session_notes text null,
  cancellation_reason text null,
  cancelled_by uuid null,
  created_at timestamp with time zone not null default now(),
  updated_at timestamp with time zone not null default now(),
  constraint individual_sessions_pkey primary key (id),
  constraint individual_sessions_recurring_session_id_fkey foreign key (recurring_session_id) references recurring_sessions (id) on delete set null,
  constraint individual_sessions_tutor_id_fkey foreign key (tutor_id) references profiles (id) on delete cascade,
  constraint individual_sessions_learner_id_fkey foreign key (learner_id) references profiles (id) on delete cascade,
  constraint individual_sessions_parent_id_fkey foreign key (parent_id) references profiles (id) on delete set null,
  constraint individual_sessions_cancelled_by_fkey foreign key (cancelled_by) references profiles (id) on delete set null
);

-- Enable RLS
alter table public.individual_sessions enable row level security;

-- Create policies
create policy "Users can view their own sessions" on public.individual_sessions
  for select using (
    auth.uid() = tutor_id or 
    auth.uid() = learner_id or 
    auth.uid() = parent_id
  );

create policy "Tutors can update their own sessions" on public.individual_sessions
  for update using (
    auth.uid() = tutor_id
  );

create policy "Admins can view all sessions" on public.individual_sessions
  for select using (
    exists (
      select 1 from profiles
      where profiles.id = auth.uid() and profiles.is_admin = true
    )
  );




  id uuid not null default gen_random_uuid (),
  recurring_session_id uuid null,
  tutor_id uuid null,
  learner_id uuid null,
  parent_id uuid null,
  status text not null default 'scheduled'::text,
  scheduled_date date not null,
  scheduled_time text not null,
  -- Short subject/summary of the session (e.g. "Mathematics" / "Physics")
  subject text null,
  duration_minutes integer not null default 60,
  actual_duration_minutes integer null,
  location text not null default 'online'::text,
  meeting_link text null,
  address text null,
  location_description text null,
  session_started_at timestamp with time zone null,
  session_ended_at timestamp with time zone null,
  tutor_joined_at timestamp with time zone null,
  learner_joined_at timestamp with time zone null,
  session_notes text null,
  cancellation_reason text null,
  cancelled_by uuid null,
  created_at timestamp with time zone not null default now(),
  updated_at timestamp with time zone not null default now(),
  constraint individual_sessions_pkey primary key (id),
  constraint individual_sessions_recurring_session_id_fkey foreign key (recurring_session_id) references recurring_sessions (id) on delete set null,
  constraint individual_sessions_tutor_id_fkey foreign key (tutor_id) references profiles (id) on delete cascade,
  constraint individual_sessions_learner_id_fkey foreign key (learner_id) references profiles (id) on delete cascade,
  constraint individual_sessions_parent_id_fkey foreign key (parent_id) references profiles (id) on delete set null,
  constraint individual_sessions_cancelled_by_fkey foreign key (cancelled_by) references profiles (id) on delete set null
);

-- Enable RLS
alter table public.individual_sessions enable row level security;

-- Create policies
create policy "Users can view their own sessions" on public.individual_sessions
  for select using (
    auth.uid() = tutor_id or 
    auth.uid() = learner_id or 
    auth.uid() = parent_id
  );

create policy "Tutors can update their own sessions" on public.individual_sessions
  for update using (
    auth.uid() = tutor_id
  );

create policy "Admins can view all sessions" on public.individual_sessions
  for select using (
    exists (
      select 1 from profiles
      where profiles.id = auth.uid() and profiles.is_admin = true
    )
  );


  id uuid not null default gen_random_uuid (),
  recurring_session_id uuid null,
  tutor_id uuid null,
  learner_id uuid null,
  parent_id uuid null,
  status text not null default 'scheduled'::text,
  scheduled_date date not null,
  scheduled_time text not null,
  -- Short subject/summary of the session (e.g. "Mathematics" / "Physics")
  subject text null,
  duration_minutes integer not null default 60,
  actual_duration_minutes integer null,
  location text not null default 'online'::text,
  meeting_link text null,
  address text null,
  location_description text null,
  session_started_at timestamp with time zone null,
  session_ended_at timestamp with time zone null,
  tutor_joined_at timestamp with time zone null,
  learner_joined_at timestamp with time zone null,
  session_notes text null,
  cancellation_reason text null,
  cancelled_by uuid null,
  created_at timestamp with time zone not null default now(),
  updated_at timestamp with time zone not null default now(),
  constraint individual_sessions_pkey primary key (id),
  constraint individual_sessions_recurring_session_id_fkey foreign key (recurring_session_id) references recurring_sessions (id) on delete set null,
  constraint individual_sessions_tutor_id_fkey foreign key (tutor_id) references profiles (id) on delete cascade,
  constraint individual_sessions_learner_id_fkey foreign key (learner_id) references profiles (id) on delete cascade,
  constraint individual_sessions_parent_id_fkey foreign key (parent_id) references profiles (id) on delete set null,
  constraint individual_sessions_cancelled_by_fkey foreign key (cancelled_by) references profiles (id) on delete set null
);

-- Enable RLS
alter table public.individual_sessions enable row level security;

-- Create policies
create policy "Users can view their own sessions" on public.individual_sessions
  for select using (
    auth.uid() = tutor_id or 
    auth.uid() = learner_id or 
    auth.uid() = parent_id
  );

create policy "Tutors can update their own sessions" on public.individual_sessions
  for update using (
    auth.uid() = tutor_id
  );

create policy "Admins can view all sessions" on public.individual_sessions
  for select using (
    exists (
      select 1 from profiles
      where profiles.id = auth.uid() and profiles.is_admin = true
    )
  );


  id uuid not null default gen_random_uuid (),
  recurring_session_id uuid null,
  tutor_id uuid null,
  learner_id uuid null,
  parent_id uuid null,
  status text not null default 'scheduled'::text,
  scheduled_date date not null,
  scheduled_time text not null,
  -- Short subject/summary of the session (e.g. "Mathematics" / "Physics")
  subject text null,
  duration_minutes integer not null default 60,
  actual_duration_minutes integer null,
  location text not null default 'online'::text,
  meeting_link text null,
  address text null,
  location_description text null,
  session_started_at timestamp with time zone null,
  session_ended_at timestamp with time zone null,
  tutor_joined_at timestamp with time zone null,
  learner_joined_at timestamp with time zone null,
  session_notes text null,
  cancellation_reason text null,
  cancelled_by uuid null,
  created_at timestamp with time zone not null default now(),
  updated_at timestamp with time zone not null default now(),
  constraint individual_sessions_pkey primary key (id),
  constraint individual_sessions_recurring_session_id_fkey foreign key (recurring_session_id) references recurring_sessions (id) on delete set null,
  constraint individual_sessions_tutor_id_fkey foreign key (tutor_id) references profiles (id) on delete cascade,
  constraint individual_sessions_learner_id_fkey foreign key (learner_id) references profiles (id) on delete cascade,
  constraint individual_sessions_parent_id_fkey foreign key (parent_id) references profiles (id) on delete set null,
  constraint individual_sessions_cancelled_by_fkey foreign key (cancelled_by) references profiles (id) on delete set null
);

-- Enable RLS
alter table public.individual_sessions enable row level security;

-- Create policies
create policy "Users can view their own sessions" on public.individual_sessions
  for select using (
    auth.uid() = tutor_id or 
    auth.uid() = learner_id or 
    auth.uid() = parent_id
  );

create policy "Tutors can update their own sessions" on public.individual_sessions
  for update using (
    auth.uid() = tutor_id
  );

create policy "Admins can view all sessions" on public.individual_sessions
  for select using (
    exists (
      select 1 from profiles
      where profiles.id = auth.uid() and profiles.is_admin = true
    )
  );


  id uuid not null default gen_random_uuid (),
  recurring_session_id uuid null,
  tutor_id uuid null,
  learner_id uuid null,
  parent_id uuid null,
  status text not null default 'scheduled'::text,
  scheduled_date date not null,
  scheduled_time text not null,
  -- Short subject/summary of the session (e.g. "Mathematics" / "Physics")
  subject text null,
  duration_minutes integer not null default 60,
  actual_duration_minutes integer null,
  location text not null default 'online'::text,
  meeting_link text null,
  address text null,
  location_description text null,
  session_started_at timestamp with time zone null,
  session_ended_at timestamp with time zone null,
  tutor_joined_at timestamp with time zone null,
  learner_joined_at timestamp with time zone null,
  session_notes text null,
  cancellation_reason text null,
  cancelled_by uuid null,
  created_at timestamp with time zone not null default now(),
  updated_at timestamp with time zone not null default now(),
  constraint individual_sessions_pkey primary key (id),
  constraint individual_sessions_recurring_session_id_fkey foreign key (recurring_session_id) references recurring_sessions (id) on delete set null,
  constraint individual_sessions_tutor_id_fkey foreign key (tutor_id) references profiles (id) on delete cascade,
  constraint individual_sessions_learner_id_fkey foreign key (learner_id) references profiles (id) on delete cascade,
  constraint individual_sessions_parent_id_fkey foreign key (parent_id) references profiles (id) on delete set null,
  constraint individual_sessions_cancelled_by_fkey foreign key (cancelled_by) references profiles (id) on delete set null
);

-- Enable RLS
alter table public.individual_sessions enable row level security;

-- Create policies
create policy "Users can view their own sessions" on public.individual_sessions
  for select using (
    auth.uid() = tutor_id or 
    auth.uid() = learner_id or 
    auth.uid() = parent_id
  );

create policy "Tutors can update their own sessions" on public.individual_sessions
  for update using (
    auth.uid() = tutor_id
  );

create policy "Admins can view all sessions" on public.individual_sessions
  for select using (
    exists (
      select 1 from profiles
      where profiles.id = auth.uid() and profiles.is_admin = true
    )
  );


  id uuid not null default gen_random_uuid (),
  recurring_session_id uuid null,
  tutor_id uuid null,
  learner_id uuid null,
  parent_id uuid null,
  status text not null default 'scheduled'::text,
  scheduled_date date not null,
  scheduled_time text not null,
  -- Short subject/summary of the session (e.g. "Mathematics" / "Physics")
  subject text null,
  duration_minutes integer not null default 60,
  actual_duration_minutes integer null,
  location text not null default 'online'::text,
  meeting_link text null,
  address text null,
  location_description text null,
  session_started_at timestamp with time zone null,
  session_ended_at timestamp with time zone null,
  tutor_joined_at timestamp with time zone null,
  learner_joined_at timestamp with time zone null,
  session_notes text null,
  cancellation_reason text null,
  cancelled_by uuid null,
  created_at timestamp with time zone not null default now(),
  updated_at timestamp with time zone not null default now(),
  constraint individual_sessions_pkey primary key (id),
  constraint individual_sessions_recurring_session_id_fkey foreign key (recurring_session_id) references recurring_sessions (id) on delete set null,
  constraint individual_sessions_tutor_id_fkey foreign key (tutor_id) references profiles (id) on delete cascade,
  constraint individual_sessions_learner_id_fkey foreign key (learner_id) references profiles (id) on delete cascade,
  constraint individual_sessions_parent_id_fkey foreign key (parent_id) references profiles (id) on delete set null,
  constraint individual_sessions_cancelled_by_fkey foreign key (cancelled_by) references profiles (id) on delete set null
);

-- Enable RLS
alter table public.individual_sessions enable row level security;

-- Create policies
create policy "Users can view their own sessions" on public.individual_sessions
  for select using (
    auth.uid() = tutor_id or 
    auth.uid() = learner_id or 
    auth.uid() = parent_id
  );

create policy "Tutors can update their own sessions" on public.individual_sessions
  for update using (
    auth.uid() = tutor_id
  );

create policy "Admins can view all sessions" on public.individual_sessions
  for select using (
    exists (
      select 1 from profiles
      where profiles.id = auth.uid() and profiles.is_admin = true
    )
  );


  id uuid not null default gen_random_uuid (),
  recurring_session_id uuid null,
  tutor_id uuid null,
  learner_id uuid null,
  parent_id uuid null,
  status text not null default 'scheduled'::text,
  scheduled_date date not null,
  scheduled_time text not null,
  -- Short subject/summary of the session (e.g. "Mathematics" / "Physics")
  subject text null,
  duration_minutes integer not null default 60,
  actual_duration_minutes integer null,
  location text not null default 'online'::text,
  meeting_link text null,
  address text null,
  location_description text null,
  session_started_at timestamp with time zone null,
  session_ended_at timestamp with time zone null,
  tutor_joined_at timestamp with time zone null,
  learner_joined_at timestamp with time zone null,
  session_notes text null,
  cancellation_reason text null,
  cancelled_by uuid null,
  created_at timestamp with time zone not null default now(),
  updated_at timestamp with time zone not null default now(),
  constraint individual_sessions_pkey primary key (id),
  constraint individual_sessions_recurring_session_id_fkey foreign key (recurring_session_id) references recurring_sessions (id) on delete set null,
  constraint individual_sessions_tutor_id_fkey foreign key (tutor_id) references profiles (id) on delete cascade,
  constraint individual_sessions_learner_id_fkey foreign key (learner_id) references profiles (id) on delete cascade,
  constraint individual_sessions_parent_id_fkey foreign key (parent_id) references profiles (id) on delete set null,
  constraint individual_sessions_cancelled_by_fkey foreign key (cancelled_by) references profiles (id) on delete set null
);

-- Enable RLS
alter table public.individual_sessions enable row level security;

-- Create policies
create policy "Users can view their own sessions" on public.individual_sessions
  for select using (
    auth.uid() = tutor_id or 
    auth.uid() = learner_id or 
    auth.uid() = parent_id
  );

create policy "Tutors can update their own sessions" on public.individual_sessions
  for update using (
    auth.uid() = tutor_id
  );

create policy "Admins can view all sessions" on public.individual_sessions
  for select using (
    exists (
      select 1 from profiles
      where profiles.id = auth.uid() and profiles.is_admin = true
    )
  );


  id uuid not null default gen_random_uuid (),
  recurring_session_id uuid null,
  tutor_id uuid null,
  learner_id uuid null,
  parent_id uuid null,
  status text not null default 'scheduled'::text,
  scheduled_date date not null,
  scheduled_time text not null,
  -- Short subject/summary of the session (e.g. "Mathematics" / "Physics")
  subject text null,
  duration_minutes integer not null default 60,
  actual_duration_minutes integer null,
  location text not null default 'online'::text,
  meeting_link text null,
  address text null,
  location_description text null,
  session_started_at timestamp with time zone null,
  session_ended_at timestamp with time zone null,
  tutor_joined_at timestamp with time zone null,
  learner_joined_at timestamp with time zone null,
  session_notes text null,
  cancellation_reason text null,
  cancelled_by uuid null,
  created_at timestamp with time zone not null default now(),
  updated_at timestamp with time zone not null default now(),
  constraint individual_sessions_pkey primary key (id),
  constraint individual_sessions_recurring_session_id_fkey foreign key (recurring_session_id) references recurring_sessions (id) on delete set null,
  constraint individual_sessions_tutor_id_fkey foreign key (tutor_id) references profiles (id) on delete cascade,
  constraint individual_sessions_learner_id_fkey foreign key (learner_id) references profiles (id) on delete cascade,
  constraint individual_sessions_parent_id_fkey foreign key (parent_id) references profiles (id) on delete set null,
  constraint individual_sessions_cancelled_by_fkey foreign key (cancelled_by) references profiles (id) on delete set null
);

-- Enable RLS
alter table public.individual_sessions enable row level security;

-- Create policies
create policy "Users can view their own sessions" on public.individual_sessions
  for select using (
    auth.uid() = tutor_id or 
    auth.uid() = learner_id or 
    auth.uid() = parent_id
  );

create policy "Tutors can update their own sessions" on public.individual_sessions
  for update using (
    auth.uid() = tutor_id
  );

create policy "Admins can view all sessions" on public.individual_sessions
  for select using (
    exists (
      select 1 from profiles
      where profiles.id = auth.uid() and profiles.is_admin = true
    )
  );


  id uuid not null default gen_random_uuid (),
  recurring_session_id uuid null,
  tutor_id uuid null,
  learner_id uuid null,
  parent_id uuid null,
  status text not null default 'scheduled'::text,
  scheduled_date date not null,
  scheduled_time text not null,
  -- Short subject/summary of the session (e.g. "Mathematics" / "Physics")
  subject text null,
  duration_minutes integer not null default 60,
  actual_duration_minutes integer null,
  location text not null default 'online'::text,
  meeting_link text null,
  address text null,
  location_description text null,
  session_started_at timestamp with time zone null,
  session_ended_at timestamp with time zone null,
  tutor_joined_at timestamp with time zone null,
  learner_joined_at timestamp with time zone null,
  session_notes text null,
  cancellation_reason text null,
  cancelled_by uuid null,
  created_at timestamp with time zone not null default now(),
  updated_at timestamp with time zone not null default now(),
  constraint individual_sessions_pkey primary key (id),
  constraint individual_sessions_recurring_session_id_fkey foreign key (recurring_session_id) references recurring_sessions (id) on delete set null,
  constraint individual_sessions_tutor_id_fkey foreign key (tutor_id) references profiles (id) on delete cascade,
  constraint individual_sessions_learner_id_fkey foreign key (learner_id) references profiles (id) on delete cascade,
  constraint individual_sessions_parent_id_fkey foreign key (parent_id) references profiles (id) on delete set null,
  constraint individual_sessions_cancelled_by_fkey foreign key (cancelled_by) references profiles (id) on delete set null
);

-- Enable RLS
alter table public.individual_sessions enable row level security;

-- Create policies
create policy "Users can view their own sessions" on public.individual_sessions
  for select using (
    auth.uid() = tutor_id or 
    auth.uid() = learner_id or 
    auth.uid() = parent_id
  );

create policy "Tutors can update their own sessions" on public.individual_sessions
  for update using (
    auth.uid() = tutor_id
  );

create policy "Admins can view all sessions" on public.individual_sessions
  for select using (
    exists (
      select 1 from profiles
      where profiles.id = auth.uid() and profiles.is_admin = true
    )
  );


  id uuid not null default gen_random_uuid (),
  recurring_session_id uuid null,
  tutor_id uuid null,
  learner_id uuid null,
  parent_id uuid null,
  status text not null default 'scheduled'::text,
  scheduled_date date not null,
  scheduled_time text not null,
  -- Short subject/summary of the session (e.g. "Mathematics" / "Physics")
  subject text null,
  duration_minutes integer not null default 60,
  actual_duration_minutes integer null,
  location text not null default 'online'::text,
  meeting_link text null,
  address text null,
  location_description text null,
  session_started_at timestamp with time zone null,
  session_ended_at timestamp with time zone null,
  tutor_joined_at timestamp with time zone null,
  learner_joined_at timestamp with time zone null,
  session_notes text null,
  cancellation_reason text null,
  cancelled_by uuid null,
  created_at timestamp with time zone not null default now(),
  updated_at timestamp with time zone not null default now(),
  constraint individual_sessions_pkey primary key (id),
  constraint individual_sessions_recurring_session_id_fkey foreign key (recurring_session_id) references recurring_sessions (id) on delete set null,
  constraint individual_sessions_tutor_id_fkey foreign key (tutor_id) references profiles (id) on delete cascade,
  constraint individual_sessions_learner_id_fkey foreign key (learner_id) references profiles (id) on delete cascade,
  constraint individual_sessions_parent_id_fkey foreign key (parent_id) references profiles (id) on delete set null,
  constraint individual_sessions_cancelled_by_fkey foreign key (cancelled_by) references profiles (id) on delete set null
);

-- Enable RLS
alter table public.individual_sessions enable row level security;

-- Create policies
create policy "Users can view their own sessions" on public.individual_sessions
  for select using (
    auth.uid() = tutor_id or 
    auth.uid() = learner_id or 
    auth.uid() = parent_id
  );

create policy "Tutors can update their own sessions" on public.individual_sessions
  for update using (
    auth.uid() = tutor_id
  );

create policy "Admins can view all sessions" on public.individual_sessions
  for select using (
    exists (
      select 1 from profiles
      where profiles.id = auth.uid() and profiles.is_admin = true
    )
  );


  id uuid not null default gen_random_uuid (),
  recurring_session_id uuid null,
  tutor_id uuid null,
  learner_id uuid null,
  parent_id uuid null,
  status text not null default 'scheduled'::text,
  scheduled_date date not null,
  scheduled_time text not null,
  -- Short subject/summary of the session (e.g. "Mathematics" / "Physics")
  subject text null,
  duration_minutes integer not null default 60,
  actual_duration_minutes integer null,
  location text not null default 'online'::text,
  meeting_link text null,
  address text null,
  location_description text null,
  session_started_at timestamp with time zone null,
  session_ended_at timestamp with time zone null,
  tutor_joined_at timestamp with time zone null,
  learner_joined_at timestamp with time zone null,
  session_notes text null,
  cancellation_reason text null,
  cancelled_by uuid null,
  created_at timestamp with time zone not null default now(),
  updated_at timestamp with time zone not null default now(),
  constraint individual_sessions_pkey primary key (id),
  constraint individual_sessions_recurring_session_id_fkey foreign key (recurring_session_id) references recurring_sessions (id) on delete set null,
  constraint individual_sessions_tutor_id_fkey foreign key (tutor_id) references profiles (id) on delete cascade,
  constraint individual_sessions_learner_id_fkey foreign key (learner_id) references profiles (id) on delete cascade,
  constraint individual_sessions_parent_id_fkey foreign key (parent_id) references profiles (id) on delete set null,
  constraint individual_sessions_cancelled_by_fkey foreign key (cancelled_by) references profiles (id) on delete set null
);

-- Enable RLS
alter table public.individual_sessions enable row level security;

-- Create policies
create policy "Users can view their own sessions" on public.individual_sessions
  for select using (
    auth.uid() = tutor_id or 
    auth.uid() = learner_id or 
    auth.uid() = parent_id
  );

create policy "Tutors can update their own sessions" on public.individual_sessions
  for update using (
    auth.uid() = tutor_id
  );

create policy "Admins can view all sessions" on public.individual_sessions
  for select using (
    exists (
      select 1 from profiles
      where profiles.id = auth.uid() and profiles.is_admin = true
    )
  );


  id uuid not null default gen_random_uuid (),
  recurring_session_id uuid null,
  tutor_id uuid null,
  learner_id uuid null,
  parent_id uuid null,
  status text not null default 'scheduled'::text,
  scheduled_date date not null,
  scheduled_time text not null,
  -- Short subject/summary of the session (e.g. "Mathematics" / "Physics")
  subject text null,
  duration_minutes integer not null default 60,
  actual_duration_minutes integer null,
  location text not null default 'online'::text,
  meeting_link text null,
  address text null,
  location_description text null,
  session_started_at timestamp with time zone null,
  session_ended_at timestamp with time zone null,
  tutor_joined_at timestamp with time zone null,
  learner_joined_at timestamp with time zone null,
  session_notes text null,
  cancellation_reason text null,
  cancelled_by uuid null,
  created_at timestamp with time zone not null default now(),
  updated_at timestamp with time zone not null default now(),
  constraint individual_sessions_pkey primary key (id),
  constraint individual_sessions_recurring_session_id_fkey foreign key (recurring_session_id) references recurring_sessions (id) on delete set null,
  constraint individual_sessions_tutor_id_fkey foreign key (tutor_id) references profiles (id) on delete cascade,
  constraint individual_sessions_learner_id_fkey foreign key (learner_id) references profiles (id) on delete cascade,
  constraint individual_sessions_parent_id_fkey foreign key (parent_id) references profiles (id) on delete set null,
  constraint individual_sessions_cancelled_by_fkey foreign key (cancelled_by) references profiles (id) on delete set null
);

-- Enable RLS
alter table public.individual_sessions enable row level security;

-- Create policies
create policy "Users can view their own sessions" on public.individual_sessions
  for select using (
    auth.uid() = tutor_id or 
    auth.uid() = learner_id or 
    auth.uid() = parent_id
  );

create policy "Tutors can update their own sessions" on public.individual_sessions
  for update using (
    auth.uid() = tutor_id
  );

create policy "Admins can view all sessions" on public.individual_sessions
  for select using (
    exists (
      select 1 from profiles
      where profiles.id = auth.uid() and profiles.is_admin = true
    )
  );


  id uuid not null default gen_random_uuid (),
  recurring_session_id uuid null,
  tutor_id uuid null,
  learner_id uuid null,
  parent_id uuid null,
  status text not null default 'scheduled'::text,
  scheduled_date date not null,
  scheduled_time text not null,
  -- Short subject/summary of the session (e.g. "Mathematics" / "Physics")
  subject text null,
  duration_minutes integer not null default 60,
  actual_duration_minutes integer null,
  location text not null default 'online'::text,
  meeting_link text null,
  address text null,
  location_description text null,
  session_started_at timestamp with time zone null,
  session_ended_at timestamp with time zone null,
  tutor_joined_at timestamp with time zone null,
  learner_joined_at timestamp with time zone null,
  session_notes text null,
  cancellation_reason text null,
  cancelled_by uuid null,
  created_at timestamp with time zone not null default now(),
  updated_at timestamp with time zone not null default now(),
  constraint individual_sessions_pkey primary key (id),
  constraint individual_sessions_recurring_session_id_fkey foreign key (recurring_session_id) references recurring_sessions (id) on delete set null,
  constraint individual_sessions_tutor_id_fkey foreign key (tutor_id) references profiles (id) on delete cascade,
  constraint individual_sessions_learner_id_fkey foreign key (learner_id) references profiles (id) on delete cascade,
  constraint individual_sessions_parent_id_fkey foreign key (parent_id) references profiles (id) on delete set null,
  constraint individual_sessions_cancelled_by_fkey foreign key (cancelled_by) references profiles (id) on delete set null
);

-- Enable RLS
alter table public.individual_sessions enable row level security;

-- Create policies
create policy "Users can view their own sessions" on public.individual_sessions
  for select using (
    auth.uid() = tutor_id or 
    auth.uid() = learner_id or 
    auth.uid() = parent_id
  );

create policy "Tutors can update their own sessions" on public.individual_sessions
  for update using (
    auth.uid() = tutor_id
  );

create policy "Admins can view all sessions" on public.individual_sessions
  for select using (
    exists (
      select 1 from profiles
      where profiles.id = auth.uid() and profiles.is_admin = true
    )
  );


  id uuid not null default gen_random_uuid (),
  recurring_session_id uuid null,
  tutor_id uuid null,
  learner_id uuid null,
  parent_id uuid null,
  status text not null default 'scheduled'::text,
  scheduled_date date not null,
  scheduled_time text not null,
  -- Short subject/summary of the session (e.g. "Mathematics" / "Physics")
  subject text null,
  duration_minutes integer not null default 60,
  actual_duration_minutes integer null,
  location text not null default 'online'::text,
  meeting_link text null,
  address text null,
  location_description text null,
  session_started_at timestamp with time zone null,
  session_ended_at timestamp with time zone null,
  tutor_joined_at timestamp with time zone null,
  learner_joined_at timestamp with time zone null,
  session_notes text null,
  cancellation_reason text null,
  cancelled_by uuid null,
  created_at timestamp with time zone not null default now(),
  updated_at timestamp with time zone not null default now(),
  constraint individual_sessions_pkey primary key (id),
  constraint individual_sessions_recurring_session_id_fkey foreign key (recurring_session_id) references recurring_sessions (id) on delete set null,
  constraint individual_sessions_tutor_id_fkey foreign key (tutor_id) references profiles (id) on delete cascade,
  constraint individual_sessions_learner_id_fkey foreign key (learner_id) references profiles (id) on delete cascade,
  constraint individual_sessions_parent_id_fkey foreign key (parent_id) references profiles (id) on delete set null,
  constraint individual_sessions_cancelled_by_fkey foreign key (cancelled_by) references profiles (id) on delete set null
);

-- Enable RLS
alter table public.individual_sessions enable row level security;

-- Create policies
create policy "Users can view their own sessions" on public.individual_sessions
  for select using (
    auth.uid() = tutor_id or 
    auth.uid() = learner_id or 
    auth.uid() = parent_id
  );

create policy "Tutors can update their own sessions" on public.individual_sessions
  for update using (
    auth.uid() = tutor_id
  );

create policy "Admins can view all sessions" on public.individual_sessions
  for select using (
    exists (
      select 1 from profiles
      where profiles.id = auth.uid() and profiles.is_admin = true
    )
  );


  id uuid not null default gen_random_uuid (),
  recurring_session_id uuid null,
  tutor_id uuid null,
  learner_id uuid null,
  parent_id uuid null,
  status text not null default 'scheduled'::text,
  scheduled_date date not null,
  scheduled_time text not null,
  -- Short subject/summary of the session (e.g. "Mathematics" / "Physics")
  subject text null,
  duration_minutes integer not null default 60,
  actual_duration_minutes integer null,
  location text not null default 'online'::text,
  meeting_link text null,
  address text null,
  location_description text null,
  session_started_at timestamp with time zone null,
  session_ended_at timestamp with time zone null,
  tutor_joined_at timestamp with time zone null,
  learner_joined_at timestamp with time zone null,
  session_notes text null,
  cancellation_reason text null,
  cancelled_by uuid null,
  created_at timestamp with time zone not null default now(),
  updated_at timestamp with time zone not null default now(),
  constraint individual_sessions_pkey primary key (id),
  constraint individual_sessions_recurring_session_id_fkey foreign key (recurring_session_id) references recurring_sessions (id) on delete set null,
  constraint individual_sessions_tutor_id_fkey foreign key (tutor_id) references profiles (id) on delete cascade,
  constraint individual_sessions_learner_id_fkey foreign key (learner_id) references profiles (id) on delete cascade,
  constraint individual_sessions_parent_id_fkey foreign key (parent_id) references profiles (id) on delete set null,
  constraint individual_sessions_cancelled_by_fkey foreign key (cancelled_by) references profiles (id) on delete set null
);

-- Enable RLS
alter table public.individual_sessions enable row level security;

-- Create policies
create policy "Users can view their own sessions" on public.individual_sessions
  for select using (
    auth.uid() = tutor_id or 
    auth.uid() = learner_id or 
    auth.uid() = parent_id
  );

create policy "Tutors can update their own sessions" on public.individual_sessions
  for update using (
    auth.uid() = tutor_id
  );

create policy "Admins can view all sessions" on public.individual_sessions
  for select using (
    exists (
      select 1 from profiles
      where profiles.id = auth.uid() and profiles.is_admin = true
    )
  );


  id uuid not null default gen_random_uuid (),
  recurring_session_id uuid null,
  tutor_id uuid null,
  learner_id uuid null,
  parent_id uuid null,
  status text not null default 'scheduled'::text,
  scheduled_date date not null,
  scheduled_time text not null,
  -- Short subject/summary of the session (e.g. "Mathematics" / "Physics")
  subject text null,
  duration_minutes integer not null default 60,
  actual_duration_minutes integer null,
  location text not null default 'online'::text,
  meeting_link text null,
  address text null,
  location_description text null,
  session_started_at timestamp with time zone null,
  session_ended_at timestamp with time zone null,
  tutor_joined_at timestamp with time zone null,
  learner_joined_at timestamp with time zone null,
  session_notes text null,
  cancellation_reason text null,
  cancelled_by uuid null,
  created_at timestamp with time zone not null default now(),
  updated_at timestamp with time zone not null default now(),
  constraint individual_sessions_pkey primary key (id),
  constraint individual_sessions_recurring_session_id_fkey foreign key (recurring_session_id) references recurring_sessions (id) on delete set null,
  constraint individual_sessions_tutor_id_fkey foreign key (tutor_id) references profiles (id) on delete cascade,
  constraint individual_sessions_learner_id_fkey foreign key (learner_id) references profiles (id) on delete cascade,
  constraint individual_sessions_parent_id_fkey foreign key (parent_id) references profiles (id) on delete set null,
  constraint individual_sessions_cancelled_by_fkey foreign key (cancelled_by) references profiles (id) on delete set null
);

-- Enable RLS
alter table public.individual_sessions enable row level security;

-- Create policies
create policy "Users can view their own sessions" on public.individual_sessions
  for select using (
    auth.uid() = tutor_id or 
    auth.uid() = learner_id or 
    auth.uid() = parent_id
  );

create policy "Tutors can update their own sessions" on public.individual_sessions
  for update using (
    auth.uid() = tutor_id
  );

create policy "Admins can view all sessions" on public.individual_sessions
  for select using (
    exists (
      select 1 from profiles
      where profiles.id = auth.uid() and profiles.is_admin = true
    )
  );


  id uuid not null default gen_random_uuid (),
  recurring_session_id uuid null,
  tutor_id uuid null,
  learner_id uuid null,
  parent_id uuid null,
  status text not null default 'scheduled'::text,
  scheduled_date date not null,
  scheduled_time text not null,
  -- Short subject/summary of the session (e.g. "Mathematics" / "Physics")
  subject text null,
  duration_minutes integer not null default 60,
  actual_duration_minutes integer null,
  location text not null default 'online'::text,
  meeting_link text null,
  address text null,
  location_description text null,
  session_started_at timestamp with time zone null,
  session_ended_at timestamp with time zone null,
  tutor_joined_at timestamp with time zone null,
  learner_joined_at timestamp with time zone null,
  session_notes text null,
  cancellation_reason text null,
  cancelled_by uuid null,
  created_at timestamp with time zone not null default now(),
  updated_at timestamp with time zone not null default now(),
  constraint individual_sessions_pkey primary key (id),
  constraint individual_sessions_recurring_session_id_fkey foreign key (recurring_session_id) references recurring_sessions (id) on delete set null,
  constraint individual_sessions_tutor_id_fkey foreign key (tutor_id) references profiles (id) on delete cascade,
  constraint individual_sessions_learner_id_fkey foreign key (learner_id) references profiles (id) on delete cascade,
  constraint individual_sessions_parent_id_fkey foreign key (parent_id) references profiles (id) on delete set null,
  constraint individual_sessions_cancelled_by_fkey foreign key (cancelled_by) references profiles (id) on delete set null
);

-- Enable RLS
alter table public.individual_sessions enable row level security;

-- Create policies
create policy "Users can view their own sessions" on public.individual_sessions
  for select using (
    auth.uid() = tutor_id or 
    auth.uid() = learner_id or 
    auth.uid() = parent_id
  );

create policy "Tutors can update their own sessions" on public.individual_sessions
  for update using (
    auth.uid() = tutor_id
  );

create policy "Admins can view all sessions" on public.individual_sessions
  for select using (
    exists (
      select 1 from profiles
      where profiles.id = auth.uid() and profiles.is_admin = true
    )
  );


  id uuid not null default gen_random_uuid (),
  recurring_session_id uuid null,
  tutor_id uuid null,
  learner_id uuid null,
  parent_id uuid null,
  status text not null default 'scheduled'::text,
  scheduled_date date not null,
  scheduled_time text not null,
  -- Short subject/summary of the session (e.g. "Mathematics" / "Physics")
  subject text null,
  duration_minutes integer not null default 60,
  actual_duration_minutes integer null,
  location text not null default 'online'::text,
  meeting_link text null,
  address text null,
  location_description text null,
  session_started_at timestamp with time zone null,
  session_ended_at timestamp with time zone null,
  tutor_joined_at timestamp with time zone null,
  learner_joined_at timestamp with time zone null,
  session_notes text null,
  cancellation_reason text null,
  cancelled_by uuid null,
  created_at timestamp with time zone not null default now(),
  updated_at timestamp with time zone not null default now(),
  constraint individual_sessions_pkey primary key (id),
  constraint individual_sessions_recurring_session_id_fkey foreign key (recurring_session_id) references recurring_sessions (id) on delete set null,
  constraint individual_sessions_tutor_id_fkey foreign key (tutor_id) references profiles (id) on delete cascade,
  constraint individual_sessions_learner_id_fkey foreign key (learner_id) references profiles (id) on delete cascade,
  constraint individual_sessions_parent_id_fkey foreign key (parent_id) references profiles (id) on delete set null,
  constraint individual_sessions_cancelled_by_fkey foreign key (cancelled_by) references profiles (id) on delete set null
);

-- Enable RLS
alter table public.individual_sessions enable row level security;

-- Create policies
create policy "Users can view their own sessions" on public.individual_sessions
  for select using (
    auth.uid() = tutor_id or 
    auth.uid() = learner_id or 
    auth.uid() = parent_id
  );

create policy "Tutors can update their own sessions" on public.individual_sessions
  for update using (
    auth.uid() = tutor_id
  );

create policy "Admins can view all sessions" on public.individual_sessions
  for select using (
    exists (
      select 1 from profiles
      where profiles.id = auth.uid() and profiles.is_admin = true
    )
  );


  id uuid not null default gen_random_uuid (),
  recurring_session_id uuid null,
  tutor_id uuid null,
  learner_id uuid null,
  parent_id uuid null,
  status text not null default 'scheduled'::text,
  scheduled_date date not null,
  scheduled_time text not null,
  -- Short subject/summary of the session (e.g. "Mathematics" / "Physics")
  subject text null,
  duration_minutes integer not null default 60,
  actual_duration_minutes integer null,
  location text not null default 'online'::text,
  meeting_link text null,
  address text null,
  location_description text null,
  session_started_at timestamp with time zone null,
  session_ended_at timestamp with time zone null,
  tutor_joined_at timestamp with time zone null,
  learner_joined_at timestamp with time zone null,
  session_notes text null,
  cancellation_reason text null,
  cancelled_by uuid null,
  created_at timestamp with time zone not null default now(),
  updated_at timestamp with time zone not null default now(),
  constraint individual_sessions_pkey primary key (id),
  constraint individual_sessions_recurring_session_id_fkey foreign key (recurring_session_id) references recurring_sessions (id) on delete set null,
  constraint individual_sessions_tutor_id_fkey foreign key (tutor_id) references profiles (id) on delete cascade,
  constraint individual_sessions_learner_id_fkey foreign key (learner_id) references profiles (id) on delete cascade,
  constraint individual_sessions_parent_id_fkey foreign key (parent_id) references profiles (id) on delete set null,
  constraint individual_sessions_cancelled_by_fkey foreign key (cancelled_by) references profiles (id) on delete set null
);

-- Enable RLS
alter table public.individual_sessions enable row level security;

-- Create policies
create policy "Users can view their own sessions" on public.individual_sessions
  for select using (
    auth.uid() = tutor_id or 
    auth.uid() = learner_id or 
    auth.uid() = parent_id
  );

create policy "Tutors can update their own sessions" on public.individual_sessions
  for update using (
    auth.uid() = tutor_id
  );

create policy "Admins can view all sessions" on public.individual_sessions
  for select using (
    exists (
      select 1 from profiles
      where profiles.id = auth.uid() and profiles.is_admin = true
    )
  );

