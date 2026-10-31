-- migrate:up

-- 1. Create table for user saved and picked locations
create table if not exists public.saved_locations (
  id uuid primary key default gen_random_uuid(),
  user_id uuid references auth.users(id) on delete cascade not null,
  title text not null,
  address text not null,
  latitude double precision not null,
  longitude double precision not null,
  category text default 'custom',
  created_at timestamp with time zone default now() not null,
  updated_at timestamp with time zone default now() not null
);

-- 2. Performance indexes
-- Index foreign key to avoid full table scans on user deletion/queries
create index if not exists idx_saved_locations_user_id on public.saved_locations (user_id);
-- Composite index on coordinates for fast bounding box / proximity lookups
create index if not exists idx_saved_locations_coords on public.saved_locations (latitude, longitude);

-- 3. Enable Row Level Security (RLS)
alter table public.saved_locations enable row level security;

-- 4. RLS Policies
-- Use (select auth.uid()) to evaluate once per query plan instead of once per row
create policy "Users can view their own saved locations."
  on public.saved_locations
  for select
  to authenticated
  using ((select auth.uid()) = user_id);

create policy "Users can insert their own saved locations."
  on public.saved_locations
  for insert
  to authenticated
  with check ((select auth.uid()) = user_id);

create policy "Users can update their own saved locations."
  on public.saved_locations
  for update
  to authenticated
  using ((select auth.uid()) = user_id);

create policy "Users can delete their own saved locations."
  on public.saved_locations
  for delete
  to authenticated
  using ((select auth.uid()) = user_id);

-- 5. Updated_at trigger function
create or replace function public.set_updated_at()
returns trigger as $$
begin
  new.updated_at = now();
  return new;
end;
$$ language plpgsql set search_path = '';

drop trigger if exists on_saved_locations_updated on public.saved_locations;
create trigger on_saved_locations_updated
  before update on public.saved_locations
  for each row
  execute procedure public.set_updated_at();

-- migrate:down
drop trigger if exists on_saved_locations_updated on public.saved_locations;
drop function if exists public.set_updated_at();
drop table if exists public.saved_locations;

