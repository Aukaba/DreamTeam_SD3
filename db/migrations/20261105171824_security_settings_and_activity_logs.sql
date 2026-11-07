-- migrate:up

-- 1. User security & account access settings (1-to-1 with auth.users)
create table if not exists public.user_security_settings (
  user_id uuid primary key references auth.users(id) on delete cascade,
  login_alerts_enabled boolean not null default true,
  keep_signed_in boolean not null default true,
  anonymous_reporting boolean not null default false,
  password_changed_at timestamp with time zone,
  last_global_signout_at timestamp with time zone,
  created_at timestamp with time zone not null default timezone('utc'::text, now()),
  updated_at timestamp with time zone not null default timezone('utc'::text, now())
);

-- 2. Immutable security activity audit logs
create table if not exists public.security_activity_logs (
  id bigint generated always as identity primary key,
  user_id uuid not null references auth.users(id) on delete cascade,
  event_type text not null,
  description text not null,
  platform text,
  created_at timestamp with time zone not null default timezone('utc'::text, now()),
  constraint security_activity_logs_event_type_check check (
    event_type in (
      'password_changed',
      'password_reset_requested',
      'signed_out_other_devices',
      'signed_out_all_devices',
      'security_settings_updated',
      'login_recorded'
    )
  ),
  constraint security_activity_logs_description_len_check check (
    char_length(trim(description)) >= 1 and char_length(description) <= 500
  )
);

-- 3. Composite index covering FK cascades and recent-activity queries
create index if not exists idx_security_activity_logs_user_created
  on public.security_activity_logs (user_id, created_at desc);

-- 4. Backfill default security settings for existing users
insert into public.user_security_settings (user_id)
select u.id
from auth.users u
on conflict (user_id) do nothing;

-- 5. Maintain updated_at timestamp on user_security_settings
create or replace function public.set_updated_at()
returns trigger
language plpgsql
set search_path = public
as $$
begin
  new.updated_at := timezone('utc'::text, now());
  return new;
end;
$$;

drop trigger if exists on_user_security_settings_updated on public.user_security_settings;
create trigger on_user_security_settings_updated
  before update on public.user_security_settings
  for each row
  execute function public.set_updated_at();

-- 6. Provision default security settings automatically on new user signup
create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into public.profiles (id, email, full_name, avatar_url, role, created_at, updated_at)
  values (
    new.id,
    new.email,
    coalesce(
      nullif(trim(new.raw_user_meta_data->>'full_name'), ''),
      split_part(coalesce(new.email, 'User'), '@', 1)
    ),
    new.raw_user_meta_data->>'avatar_url',
    'user',
    timezone('utc'::text, now()),
    timezone('utc'::text, now())
  )
  on conflict (id) do update set
    email = coalesce(excluded.email, public.profiles.email),
    full_name = coalesce(nullif(trim(public.profiles.full_name), ''), excluded.full_name),
    avatar_url = coalesce(public.profiles.avatar_url, excluded.avatar_url),
    role = coalesce(public.profiles.role, 'user'),
    updated_at = timezone('utc'::text, now());

  insert into public.user_security_settings (user_id)
  values (new.id)
  on conflict (user_id) do nothing;

  return new;
end;
$$;

-- 7. Enable Row Level Security (RLS)
alter table public.user_security_settings enable row level security;
alter table public.security_activity_logs enable row level security;

-- 8. RLS Policies for public.user_security_settings
drop policy if exists "Users can view their own security settings." on public.user_security_settings;
create policy "Users can view their own security settings."
  on public.user_security_settings
  for select
  to authenticated
  using ((select auth.uid()) = user_id);

drop policy if exists "Users can insert their own security settings." on public.user_security_settings;
create policy "Users can insert their own security settings."
  on public.user_security_settings
  for insert
  to authenticated
  with check ((select auth.uid()) = user_id);

drop policy if exists "Users can update their own security settings." on public.user_security_settings;
create policy "Users can update their own security settings."
  on public.user_security_settings
  for update
  to authenticated
  using ((select auth.uid()) = user_id)
  with check ((select auth.uid()) = user_id);

-- 9. RLS Policies for public.security_activity_logs (append-only for authenticated owner)
drop policy if exists "Users can view their own security logs." on public.security_activity_logs;
create policy "Users can view their own security logs."
  on public.security_activity_logs
  for select
  to authenticated
  using ((select auth.uid()) = user_id);

drop policy if exists "Users can insert their own security logs." on public.security_activity_logs;
create policy "Users can insert their own security logs."
  on public.security_activity_logs
  for insert
  to authenticated
  with check ((select auth.uid()) = user_id);

-- 10. Least-privilege table & sequence grants (override Supabase default ALL grants)
revoke all on public.user_security_settings from anon, authenticated, public;
grant select, insert, update on public.user_security_settings to authenticated;

revoke all on public.security_activity_logs from anon, authenticated, public;
revoke all on sequence public.security_activity_logs_id_seq from anon, authenticated, public;
grant select, insert on public.security_activity_logs to authenticated;
grant usage, select on sequence public.security_activity_logs_id_seq to authenticated;

-- 11. Harden saved_locations UPDATE policy with explicit WITH CHECK ownership guard
drop policy if exists "Users can update their own saved locations." on public.saved_locations;
create policy "Users can update their own saved locations."
  on public.saved_locations
  for update
  to authenticated
  using ((select auth.uid()) = user_id)
  with check ((select auth.uid()) = user_id);

-- migrate:down
drop trigger if exists on_user_security_settings_updated on public.user_security_settings;
drop table if exists public.security_activity_logs;
drop table if exists public.user_security_settings;
