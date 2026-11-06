-- migrate:up

-- 1. Partial spatial bounding-box index on public."ReportTable" for fast hazard-aware corridor queries
create index if not exists "idx_ReportTable_active_bbox"
  on public."ReportTable" (latitude, longitude, severity_level)
  where status = 'active' and latitude is not null and longitude is not null;

-- 2. Saved routes table for user-bookmarked safe routes and cached turn-by-turn geometry/steps
create table if not exists public.saved_routes (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  title text not null,
  origin_label text not null,
  origin_lat double precision not null,
  origin_lng double precision not null,
  destination_label text not null,
  destination_lat double precision not null,
  destination_lng double precision not null,
  travel_mode text not null default 'walking',
  avoid_hazards boolean not null default true,
  distance_meters double precision not null default 0,
  duration_seconds integer not null default 0,
  hazard_count integer not null default 0,
  risk_level text not null default 'safe',
  route_summary text,
  route_polyline jsonb not null default '[]'::jsonb,
  route_steps jsonb not null default '[]'::jsonb,
  is_favorite boolean not null default true,
  last_used_at timestamp with time zone,
  created_at timestamp with time zone not null default timezone('utc'::text, now()),
  updated_at timestamp with time zone not null default timezone('utc'::text, now()),
  constraint saved_routes_title_len_check check (
    char_length(trim(title)) between 1 and 140
  ),
  constraint saved_routes_labels_len_check check (
    char_length(trim(origin_label)) >= 1
    and char_length(trim(destination_label)) >= 1
  ),
  constraint saved_routes_coords_check check (
    origin_lat between -90.0 and 90.0
    and origin_lng between -180.0 and 180.0
    and destination_lat between -90.0 and 90.0
    and destination_lng between -180.0 and 180.0
  ),
  constraint saved_routes_travel_mode_check check (
    travel_mode in ('walking', 'cycling', 'driving')
  ),
  constraint saved_routes_risk_level_check check (
    risk_level in ('safe', 'low', 'moderate', 'high')
  ),
  constraint saved_routes_metrics_non_negative_check check (
    distance_meters >= 0
    and duration_seconds >= 0
    and hazard_count >= 0
  ),
  constraint saved_routes_json_arrays_check check (
    jsonb_typeof(route_polyline) = 'array'
    and jsonb_typeof(route_steps) = 'array'
  )
);

-- Covers user_id foreign key cascades and sorted user route queries
create index if not exists idx_saved_routes_user_updated
  on public.saved_routes (user_id, updated_at desc);

drop trigger if exists on_saved_routes_updated on public.saved_routes;
create trigger on_saved_routes_updated
  before update on public.saved_routes
  for each row
  execute function public.set_updated_at();

-- 3. Turn-by-turn navigation sessions table for live trip tracking, hazard reroutes, and recent suggestions
create table if not exists public.navigation_sessions (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  saved_route_id uuid references public.saved_routes(id) on delete set null,
  origin_label text not null,
  origin_lat double precision not null,
  origin_lng double precision not null,
  destination_label text not null,
  destination_lat double precision not null,
  destination_lng double precision not null,
  travel_mode text not null default 'walking',
  avoid_hazards boolean not null default true,
  distance_meters double precision not null default 0,
  duration_seconds integer not null default 0,
  hazards_avoided integer not null default 0,
  hazards_on_route integer not null default 0,
  reroute_count integer not null default 0,
  status text not null default 'active',
  started_at timestamp with time zone not null default timezone('utc'::text, now()),
  completed_at timestamp with time zone,
  updated_at timestamp with time zone not null default timezone('utc'::text, now()),
  constraint navigation_sessions_coords_check check (
    origin_lat between -90.0 and 90.0
    and origin_lng between -180.0 and 180.0
    and destination_lat between -90.0 and 90.0
    and destination_lng between -180.0 and 180.0
  ),
  constraint navigation_sessions_travel_mode_check check (
    travel_mode in ('walking', 'cycling', 'driving')
  ),
  constraint navigation_sessions_status_check check (
    status in ('active', 'completed', 'cancelled')
  ),
  constraint navigation_sessions_metrics_non_negative_check check (
    distance_meters >= 0
    and duration_seconds >= 0
    and hazards_avoided >= 0
    and hazards_on_route >= 0
    and reroute_count >= 0
  )
);

-- Covers user_id foreign key cascades and recent session queries
create index if not exists idx_navigation_sessions_user_started
  on public.navigation_sessions (user_id, started_at desc);

-- Partial index on nullable foreign key saved_route_id for fast ON DELETE SET NULL
create index if not exists idx_navigation_sessions_saved_route_id
  on public.navigation_sessions (saved_route_id)
  where saved_route_id is not null;

drop trigger if exists on_navigation_sessions_updated on public.navigation_sessions;
create trigger on_navigation_sessions_updated
  before update on public.navigation_sessions
  for each row
  execute function public.set_updated_at();

-- 4. Corridor active-hazard lookup RPC (SECURITY INVOKER so RLS on ReportTable is always respected)
create or replace function public.get_active_hazards_in_corridor(
  p_min_lat double precision,
  p_max_lat double precision,
  p_min_lng double precision,
  p_max_lng double precision,
  p_max_age_days integer default 30
)
returns table (
  report_id text,
  hazard_category text,
  detected_hazard text,
  description text,
  severity_level text,
  confidence integer,
  location_address text,
  latitude double precision,
  longitude double precision,
  avoidance_radius_m double precision,
  severity_weight double precision,
  created_at timestamp with time zone
)
language sql
stable
security invoker
set search_path = public
as $$
  select
    r."reportID" as report_id,
    r.hazard_category,
    r.detected_hazard,
    r.description,
    r.severity_level,
    r.confidence,
    r.location_address,
    r.latitude,
    r.longitude,
    case
      when lower(coalesce(r.hazard_category, '')) like '%flood%'
        or lower(coalesce(r.hazard_category, '')) like '%fire%'
        or lower(coalesce(r.hazard_category, '')) like '%blocked%' then 100.0
      when lower(coalesce(r.severity_level, '')) like '%high%'
        or lower(coalesce(r.severity_level, '')) like '%critical%'
        or lower(coalesce(r.hazard_category, '')) like '%accident%'
        or lower(coalesce(r.hazard_category, '')) like '%fallen%' then 85.0
      when lower(coalesce(r.severity_level, '')) like '%low%' then 45.0
      else 65.0
    end as avoidance_radius_m,
    case
      when lower(coalesce(r.severity_level, '')) like '%high%'
        or lower(coalesce(r.severity_level, '')) like '%critical%'
        or lower(coalesce(r.hazard_category, '')) like '%flood%'
        or lower(coalesce(r.hazard_category, '')) like '%fire%'
        or lower(coalesce(r.hazard_category, '')) like '%blocked%' then 120.0
      when lower(coalesce(r.severity_level, '')) like '%low%' then 30.0
      else 65.0
    end as severity_weight,
    r.created_at
  from public."ReportTable" r
  where r.status = 'active'
    and r.latitude is not null
    and r.longitude is not null
    and r.latitude between least(p_min_lat, p_max_lat) and greatest(p_min_lat, p_max_lat)
    and r.longitude between least(p_min_lng, p_max_lng) and greatest(p_min_lng, p_max_lng)
    and (
      p_max_age_days is null
      or p_max_age_days <= 0
      or r.created_at >= timezone('utc'::text, now()) - make_interval(days => p_max_age_days)
    )
  order by severity_weight desc, r.created_at desc
  limit 250;
$$;

revoke all on function public.get_active_hazards_in_corridor(
  double precision,
  double precision,
  double precision,
  double precision,
  integer
) from public;

grant execute on function public.get_active_hazards_in_corridor(
  double precision,
  double precision,
  double precision,
  double precision,
  integer
) to anon, authenticated, service_role;

-- 5. Enable Row Level Security (RLS) on new tables
alter table public.saved_routes enable row level security;
alter table public.navigation_sessions enable row level security;

-- 6. RLS Policies for public.saved_routes (owner-only with cached (select auth.uid()))
drop policy if exists "Users can view their own saved routes." on public.saved_routes;
create policy "Users can view their own saved routes."
  on public.saved_routes
  for select
  to authenticated
  using ((select auth.uid()) = user_id);

drop policy if exists "Users can insert their own saved routes." on public.saved_routes;
create policy "Users can insert their own saved routes."
  on public.saved_routes
  for insert
  to authenticated
  with check ((select auth.uid()) = user_id);

drop policy if exists "Users can update their own saved routes." on public.saved_routes;
create policy "Users can update their own saved routes."
  on public.saved_routes
  for update
  to authenticated
  using ((select auth.uid()) = user_id)
  with check ((select auth.uid()) = user_id);

drop policy if exists "Users can delete their own saved routes." on public.saved_routes;
create policy "Users can delete their own saved routes."
  on public.saved_routes
  for delete
  to authenticated
  using ((select auth.uid()) = user_id);

-- 7. RLS Policies for public.navigation_sessions (owner-only with cached (select auth.uid()))
drop policy if exists "Users can view their own navigation sessions." on public.navigation_sessions;
create policy "Users can view their own navigation sessions."
  on public.navigation_sessions
  for select
  to authenticated
  using ((select auth.uid()) = user_id);

drop policy if exists "Users can insert their own navigation sessions." on public.navigation_sessions;
create policy "Users can insert their own navigation sessions."
  on public.navigation_sessions
  for insert
  to authenticated
  with check ((select auth.uid()) = user_id);

drop policy if exists "Users can update their own navigation sessions." on public.navigation_sessions;
create policy "Users can update their own navigation sessions."
  on public.navigation_sessions
  for update
  to authenticated
  using ((select auth.uid()) = user_id)
  with check ((select auth.uid()) = user_id);

drop policy if exists "Users can delete their own navigation sessions." on public.navigation_sessions;
create policy "Users can delete their own navigation sessions."
  on public.navigation_sessions
  for delete
  to authenticated
  using ((select auth.uid()) = user_id);

-- 8. Least-privilege table grants + Data API exposure grants
revoke all on public.saved_routes from anon, authenticated, public;
grant select, insert, update, delete on public.saved_routes to authenticated;
grant all on public.saved_routes to service_role;

revoke all on public.navigation_sessions from anon, authenticated, public;
grant select, insert, update, delete on public.navigation_sessions to authenticated;
grant all on public.navigation_sessions to service_role;

notify pgrst, 'reload schema';

-- migrate:down
drop function if exists public.get_active_hazards_in_corridor(
  double precision,
  double precision,
  double precision,
  double precision,
  integer
);

drop trigger if exists on_navigation_sessions_updated on public.navigation_sessions;
drop table if exists public.navigation_sessions;

drop trigger if exists on_saved_routes_updated on public.saved_routes;
drop table if exists public.saved_routes;

drop index if exists public."idx_ReportTable_active_bbox";

notify pgrst, 'reload schema';
