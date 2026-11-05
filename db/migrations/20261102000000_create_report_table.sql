-- migrate:up

-- 1. Create table for community hazard reports
create table if not exists public."ReportTable" (
  "reportID" text primary key default gen_random_uuid()::text,
  user_id uuid references auth.users(id) on delete set null,
  hazard_category text not null,
  detected_hazard text,
  severity_level text,
  confidence integer,
  location_address text,
  latitude double precision,
  longitude double precision,
  image_url text,
  created_at timestamp with time zone default timezone('utc'::text, now()) not null
);

-- 2. Performance indexes
create index if not exists "idx_ReportTable_user_id" on public."ReportTable"(user_id);
create index if not exists "idx_ReportTable_created_at" on public."ReportTable"(created_at desc);
create index if not exists "idx_ReportTable_category" on public."ReportTable"(hazard_category);

-- 3. Enable Row Level Security (RLS)
alter table public."ReportTable" enable row level security;

-- 4. Grant access to API roles
grant all on table public."ReportTable" to authenticated;
grant all on table public."ReportTable" to anon;
grant all on table public."ReportTable" to service_role;

-- 5. RLS Policies
drop policy if exists "Allow public read access to hazard reports" on public."ReportTable";
create policy "Allow public read access to hazard reports"
on public."ReportTable"
for select
to public
using (true);

drop policy if exists "Allow authenticated users to insert hazard reports" on public."ReportTable";
create policy "Allow authenticated users to insert hazard reports"
on public."ReportTable"
for insert
to authenticated
with check (true);

drop policy if exists "Allow anon users to insert hazard reports" on public."ReportTable";
create policy "Allow anon users to insert hazard reports"
on public."ReportTable"
for insert
to anon
with check (true);

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

-- migrate:down
drop table if exists public."ReportTable" cascade;

