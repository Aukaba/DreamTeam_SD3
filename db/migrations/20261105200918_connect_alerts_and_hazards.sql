-- migrate:up

-- 1. Codify and extend public."ReportTable" for full Map Hazard, Recent Hazard, and Alert support
create table if not exists public."ReportTable" (
  "reportID" text primary key default (gen_random_uuid())::text,
  user_id uuid references auth.users(id) on delete set null,
  hazard_category text not null,
  detected_hazard text,
  description text,
  severity_level text,
  confidence integer,
  location_address text,
  latitude double precision,
  longitude double precision,
  image_url text,
  status text not null default 'active',
  created_at timestamp with time zone not null default timezone('utc'::text, now())
);

alter table public."ReportTable"
  add column if not exists description text;

alter table public."ReportTable"
  add column if not exists status text not null default 'active';

do $$
begin
  if not exists (
    select 1
    from pg_constraint c
    join pg_class t on c.conrelid = t.oid
    join pg_namespace n on t.relnamespace = n.oid
    where n.nspname = 'public'
      and t.relname = 'ReportTable'
      and c.conname = 'ReportTable_status_check'
  ) then
    alter table public."ReportTable"
      add constraint "ReportTable_status_check"
      check (status in ('active', 'resolved', 'archived'));
  end if;
end $$;

create index if not exists "idx_ReportTable_user_id"
  on public."ReportTable" (user_id);

create index if not exists "idx_ReportTable_created_at"
  on public."ReportTable" (created_at desc);

create index if not exists "idx_ReportTable_category"
  on public."ReportTable" (hazard_category);

create index if not exists "idx_ReportTable_active_coords_created"
  on public."ReportTable" (created_at desc, latitude, longitude)
  where status = 'active' and latitude is not null and longitude is not null;

alter table public."ReportTable" enable row level security;

drop policy if exists "Allow public read access to hazard reports" on public."ReportTable";
create policy "Allow public read access to hazard reports"
  on public."ReportTable"
  for select
  to public
  using (true);

drop policy if exists "Allow anon users to insert hazard reports" on public."ReportTable";
create policy "Allow anon users to insert hazard reports"
  on public."ReportTable"
  for insert
  to anon
  with check (user_id is null);

drop policy if exists "Allow authenticated users to insert hazard reports" on public."ReportTable";
create policy "Allow authenticated users to insert hazard reports"
  on public."ReportTable"
  for insert
  to authenticated
  with check (user_id is null or (select auth.uid()) = user_id);

drop policy if exists "Allow users to update own hazard reports" on public."ReportTable";
create policy "Allow users to update own hazard reports"
  on public."ReportTable"
  for update
  to authenticated
  using ((select auth.uid()) = user_id)
  with check ((select auth.uid()) = user_id);

drop policy if exists "Allow users to delete own hazard reports" on public."ReportTable";
create policy "Allow users to delete own hazard reports"
  on public."ReportTable"
  for delete
  to authenticated
  using ((select auth.uid()) = user_id);

revoke all on public."ReportTable" from anon, authenticated, public;
grant select, insert on public."ReportTable" to anon;
grant select, insert, update, delete on public."ReportTable" to authenticated;

-- 2. Alerts table (supports Hazard Alerts, Community Updates, and System Notices)
create table if not exists public.alerts (
  id uuid primary key default gen_random_uuid(),
  alert_type text not null,
  title text not null,
  body text not null,
  location_label text not null default 'System Notice',
  latitude double precision,
  longitude double precision,
  severity_level text,
  report_id text unique references public."ReportTable"("reportID") on delete cascade,
  target_user_id uuid references auth.users(id) on delete cascade,
  is_active boolean not null default true,
  created_at timestamp with time zone not null default timezone('utc'::text, now()),
  updated_at timestamp with time zone not null default timezone('utc'::text, now()),
  constraint alerts_alert_type_check check (
    alert_type in ('hazard', 'community', 'system')
  ),
  constraint alerts_severity_level_check check (
    severity_level is null or severity_level in ('Low', 'Medium', 'High')
  ),
  constraint alerts_coordinates_check check (
    (latitude is null and longitude is null)
    or (
      latitude between -90.0 and 90.0
      and longitude between -180.0 and 180.0
    )
  )
);

create index if not exists idx_alerts_public_active_created
  on public.alerts (alert_type, created_at desc)
  where is_active = true and target_user_id is null;

create index if not exists idx_alerts_target_user_created
  on public.alerts (target_user_id, created_at desc)
  where target_user_id is not null;

-- 3. Per-user read and dismissed state for alerts
create table if not exists public.user_alert_states (
  user_id uuid not null references auth.users(id) on delete cascade,
  alert_id uuid not null references public.alerts(id) on delete cascade,
  is_read boolean not null default true,
  is_dismissed boolean not null default false,
  read_at timestamp with time zone,
  created_at timestamp with time zone not null default timezone('utc'::text, now()),
  updated_at timestamp with time zone not null default timezone('utc'::text, now()),
  primary key (user_id, alert_id)
);

create index if not exists idx_user_alert_states_alert_id
  on public.user_alert_states (alert_id);

drop trigger if exists on_alerts_updated on public.alerts;
create trigger on_alerts_updated
  before update on public.alerts
  for each row
  execute function public.set_updated_at();

drop trigger if exists on_user_alert_states_updated on public.user_alert_states;
create trigger on_user_alert_states_updated
  before update on public.user_alert_states
  for each row
  execute function public.set_updated_at();

-- 4. Automatically synchronize Hazard & Community alerts from public."ReportTable"
create or replace function public.sync_alert_from_hazard_report()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_category_raw text;
  v_category_lower text;
  v_severity text;
  v_alert_type text;
  v_title text;
  v_raw_addr text;
  v_short_addr text;
  v_location_label text;
  v_body text;
  v_has_valid_coords boolean;
begin
  v_has_valid_coords := (
    new.latitude is not null
    and new.longitude is not null
    and new.latitude between -90.0 and 90.0
    and new.longitude between -180.0 and 180.0
  );

  if not v_has_valid_coords then
    if tg_op = 'UPDATE' then
      update public.alerts
      set is_active = false,
          updated_at = timezone('utc'::text, now())
      where report_id = new."reportID";
    end if;
    return new;
  end if;

  v_category_raw := coalesce(nullif(trim(new.hazard_category), ''), 'Hazard');
  v_category_lower := lower(v_category_raw);

  v_severity := case
    when lower(coalesce(new.severity_level, '')) like '%high%'
      or lower(coalesce(new.severity_level, '')) like '%critical%' then 'High'
    when lower(coalesce(new.severity_level, '')) like '%low%' then 'Low'
    else 'Medium'
  end;

  if v_severity = 'High'
     or v_category_lower like '%flood%'
     or v_category_lower like '%fire%'
     or v_category_lower like '%accident%'
     or v_category_lower like '%streetlight%'
     or v_category_lower like '%lighting%' then
    v_alert_type := 'hazard';
  else
    v_alert_type := 'community';
  end if;

  v_title := coalesce(nullif(trim(new.detected_hazard), ''), initcap(v_category_raw));

  v_raw_addr := coalesce(nullif(trim(new.location_address), ''), '');
  if v_raw_addr = '' or lower(v_raw_addr) = 'current location' then
    v_location_label := 'Reported nearby';
  else
    v_short_addr := trim(
      concat_ws(
        ', ',
        nullif(trim(split_part(v_raw_addr, ',', 1)), ''),
        nullif(trim(split_part(v_raw_addr, ',', 2)), '')
      )
    );
    if v_short_addr = '' then
      v_short_addr := left(v_raw_addr, 72);
    else
      v_short_addr := left(v_short_addr, 72);
    end if;

    if lower(v_short_addr) like 'near %' then
      v_location_label := v_short_addr;
    else
      v_location_label := 'Near ' || v_short_addr;
    end if;
  end if;

  if nullif(trim(new.description), '') is not null then
    v_body := left(trim(new.description), 280);
  elsif v_alert_type = 'hazard' then
    v_body := 'A user reported ' || lower(v_category_raw) || ' ' || lower(v_location_label) || ' (' || v_severity || ' severity).';
  else
    v_body := 'Community report: ' || lower(v_category_raw) || ' ' || lower(v_location_label) || '. Use alternative routes if needed.';
  end if;

  insert into public.alerts (
    alert_type,
    title,
    body,
    location_label,
    latitude,
    longitude,
    severity_level,
    report_id,
    target_user_id,
    is_active,
    created_at,
    updated_at
  )
  values (
    v_alert_type,
    v_title,
    v_body,
    v_location_label,
    new.latitude,
    new.longitude,
    v_severity,
    new."reportID",
    null,
    coalesce(new.status, 'active') = 'active',
    coalesce(new.created_at, timezone('utc'::text, now())),
    timezone('utc'::text, now())
  )
  on conflict (report_id) do update set
    alert_type = excluded.alert_type,
    title = excluded.title,
    body = excluded.body,
    location_label = excluded.location_label,
    latitude = excluded.latitude,
    longitude = excluded.longitude,
    severity_level = excluded.severity_level,
    is_active = excluded.is_active,
    updated_at = timezone('utc'::text, now());

  return new;
end;
$$;

revoke execute on function public.sync_alert_from_hazard_report() from public, anon, authenticated;

drop trigger if exists on_report_table_sync_alert on public."ReportTable";
create trigger on_report_table_sync_alert
  after insert or update on public."ReportTable"
  for each row
  execute function public.sync_alert_from_hazard_report();

-- 5. Automatically create personal System Alerts on security events when login_alerts_enabled is true
create or replace function public.create_system_alert_from_security_log()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_alerts_enabled boolean;
  v_title text;
begin
  if new.event_type not in (
    'password_changed',
    'password_reset_requested',
    'signed_out_other_devices',
    'signed_out_all_devices'
  ) then
    return new;
  end if;

  select coalesce(s.login_alerts_enabled, true)
    into v_alerts_enabled
  from public.user_security_settings s
  where s.user_id = new.user_id;

  if coalesce(v_alerts_enabled, true) then
    v_title := case new.event_type
      when 'password_changed' then 'Password updated'
      when 'password_reset_requested' then 'Password reset requested'
      when 'signed_out_other_devices' then 'Other sessions signed out'
      when 'signed_out_all_devices' then 'Signed out of all devices'
      else 'Security activity notice'
    end;

    insert into public.alerts (
      alert_type,
      title,
      body,
      location_label,
      target_user_id,
      is_active,
      created_at,
      updated_at
    )
    values (
      'system',
      v_title,
      new.description,
      'Security Notice',
      new.user_id,
      true,
      coalesce(new.created_at, timezone('utc'::text, now())),
      timezone('utc'::text, now())
    );
  end if;

  return new;
end;
$$;

revoke execute on function public.create_system_alert_from_security_log() from public, anon, authenticated;

drop trigger if exists on_security_log_create_system_alert on public.security_activity_logs;
create trigger on_security_log_create_system_alert
  after insert on public.security_activity_logs
  for each row
  execute function public.create_system_alert_from_security_log();

-- 6. Backfill alerts from existing active located rows in public."ReportTable"
insert into public.alerts (
  alert_type,
  title,
  body,
  location_label,
  latitude,
  longitude,
  severity_level,
  report_id,
  target_user_id,
  is_active,
  created_at,
  updated_at
)
select
  case
    when (
      lower(coalesce(r.severity_level, '')) like '%high%'
      or lower(coalesce(r.severity_level, '')) like '%critical%'
      or lower(coalesce(r.hazard_category, '')) like '%flood%'
      or lower(coalesce(r.hazard_category, '')) like '%fire%'
      or lower(coalesce(r.hazard_category, '')) like '%accident%'
      or lower(coalesce(r.hazard_category, '')) like '%streetlight%'
      or lower(coalesce(r.hazard_category, '')) like '%lighting%'
    ) then 'hazard'
    else 'community'
  end as alert_type,
  coalesce(nullif(trim(r.detected_hazard), ''), initcap(coalesce(nullif(trim(r.hazard_category), ''), 'Hazard'))) as title,
  case
    when nullif(trim(r.description), '') is not null then left(trim(r.description), 280)
    when (
      lower(coalesce(r.severity_level, '')) like '%high%'
      or lower(coalesce(r.severity_level, '')) like '%critical%'
      or lower(coalesce(r.hazard_category, '')) like '%flood%'
      or lower(coalesce(r.hazard_category, '')) like '%fire%'
      or lower(coalesce(r.hazard_category, '')) like '%accident%'
      or lower(coalesce(r.hazard_category, '')) like '%streetlight%'
      or lower(coalesce(r.hazard_category, '')) like '%lighting%'
    ) then 'A user reported ' || lower(coalesce(nullif(trim(r.hazard_category), ''), 'hazard')) || ' near ' ||
           coalesce(
             nullif(
               trim(concat_ws(', ', nullif(trim(split_part(coalesce(r.location_address, ''), ',', 1)), ''), nullif(trim(split_part(coalesce(r.location_address, ''), ',', 2)), ''))),
               ''
             ),
             'your area'
           ) || ' (' ||
           case
             when lower(coalesce(r.severity_level, '')) like '%high%' then 'High'
             when lower(coalesce(r.severity_level, '')) like '%low%' then 'Low'
             else 'Medium'
           end || ' severity).'
    else 'Community report: ' || lower(coalesce(nullif(trim(r.hazard_category), ''), 'road issue')) || ' near ' ||
         coalesce(
           nullif(
             trim(concat_ws(', ', nullif(trim(split_part(coalesce(r.location_address, ''), ',', 1)), ''), nullif(trim(split_part(coalesce(r.location_address, ''), ',', 2)), ''))),
             ''
           ),
           'your area'
         ) || '. Use alternative routes if needed.'
  end as body,
  case
    when coalesce(nullif(trim(r.location_address), ''), '') = ''
      or lower(trim(r.location_address)) = 'current location' then 'Reported nearby'
    when lower(trim(r.location_address)) like 'near %' then left(trim(r.location_address), 72)
    else 'Near ' || left(
      trim(concat_ws(', ', nullif(trim(split_part(r.location_address, ',', 1)), ''), nullif(trim(split_part(r.location_address, ',', 2)), ''))),
      67
    )
  end as location_label,
  r.latitude,
  r.longitude,
  case
    when lower(coalesce(r.severity_level, '')) like '%high%'
      or lower(coalesce(r.severity_level, '')) like '%critical%' then 'High'
    when lower(coalesce(r.severity_level, '')) like '%low%' then 'Low'
    else 'Medium'
  end as severity_level,
  r."reportID" as report_id,
  null as target_user_id,
  coalesce(r.status, 'active') = 'active' as is_active,
  r.created_at,
  timezone('utc'::text, now())
from public."ReportTable" r
where r.latitude is not null
  and r.longitude is not null
  and r.latitude between -90.0 and 90.0
  and r.longitude between -180.0 and 180.0
on conflict (report_id) do nothing;

-- 7. Seed active SafeRoute system status notice
insert into public.alerts (
  id,
  alert_type,
  title,
  body,
  location_label,
  target_user_id,
  is_active
)
values (
  '00000000-0000-4000-8000-000000000001',
  'system',
  'Live Hazard Monitoring Active',
  'SafeRoute Gemini AI hazard verification and real-time Cebu road alerts are active across your area.',
  'System Notice',
  null,
  true
)
on conflict (id) do nothing;

-- 8. Enable Row Level Security (RLS) on new tables
alter table public.alerts enable row level security;
alter table public.user_alert_states enable row level security;

-- 9. RLS Policies for public.alerts
drop policy if exists "Anyone can view public active alerts." on public.alerts;
create policy "Anyone can view public active alerts."
  on public.alerts
  for select
  to anon, authenticated
  using (is_active = true and target_user_id is null);

drop policy if exists "Users can view their own targeted alerts." on public.alerts;
create policy "Users can view their own targeted alerts."
  on public.alerts
  for select
  to authenticated
  using (is_active = true and (select auth.uid()) = target_user_id);

-- 10. RLS Policies for public.user_alert_states
drop policy if exists "Users can view their own alert states." on public.user_alert_states;
create policy "Users can view their own alert states."
  on public.user_alert_states
  for select
  to authenticated
  using ((select auth.uid()) = user_id);

drop policy if exists "Users can insert their own alert states." on public.user_alert_states;
create policy "Users can insert their own alert states."
  on public.user_alert_states
  for insert
  to authenticated
  with check ((select auth.uid()) = user_id);

drop policy if exists "Users can update their own alert states." on public.user_alert_states;
create policy "Users can update their own alert states."
  on public.user_alert_states
  for update
  to authenticated
  using ((select auth.uid()) = user_id)
  with check ((select auth.uid()) = user_id);

drop policy if exists "Users can delete their own alert states." on public.user_alert_states;
create policy "Users can delete their own alert states."
  on public.user_alert_states
  for delete
  to authenticated
  using ((select auth.uid()) = user_id);

-- 11. Least-privilege table grants (override Supabase default ALL grants)
revoke all on public.alerts from anon, authenticated, public;
grant select on public.alerts to anon, authenticated;

revoke all on public.user_alert_states from anon, authenticated, public;
grant select, insert, update, delete on public.user_alert_states to authenticated;

-- migrate:down
drop trigger if exists on_security_log_create_system_alert on public.security_activity_logs;
drop function if exists public.create_system_alert_from_security_log();

drop trigger if exists on_report_table_sync_alert on public."ReportTable";
drop function if exists public.sync_alert_from_hazard_report();

drop trigger if exists on_user_alert_states_updated on public.user_alert_states;
drop trigger if exists on_alerts_updated on public.alerts;

drop table if exists public.user_alert_states;
drop table if exists public.alerts;

drop index if exists public."idx_ReportTable_active_coords_created";
alter table public."ReportTable" drop constraint if exists "ReportTable_status_check";
alter table public."ReportTable" drop column if exists status;
alter table public."ReportTable" drop column if exists description;
