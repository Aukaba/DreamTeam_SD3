-- migrate:up

-- 1. Provision the role column on public.profiles with strict values ('user', 'admin')
alter table public.profiles
  add column if not exists role text not null default 'user';

update public.profiles
set role = 'user'
where role is null or role not in ('user', 'admin');

alter table public.profiles
  alter column role set default 'user',
  alter column role set not null;

do $$
begin
  if not exists (
    select 1
    from pg_constraint
    where conname = 'profiles_role_check'
      and conrelid = 'public.profiles'::regclass
  ) then
    alter table public.profiles
      add constraint profiles_role_check check (role in ('user', 'admin'));
  end if;
end
$$;

-- 2. Prevent ordinary/authenticated clients from self-assigning or mutating roles
create or replace function public.enforce_profile_role_security()
returns trigger
language plpgsql
set search_path = public
as $$
declare
  v_jwt_role text := coalesce(current_setting('request.jwt.claim.role', true), '');
  v_is_client_request boolean := current_user in ('anon', 'authenticated')
    or v_jwt_role in ('anon', 'authenticated');
begin
  if tg_op = 'INSERT' then
    new.role := coalesce(new.role, 'user');
    if v_is_client_request and new.role <> 'user' then
      raise exception 'Cannot assign privileged role'
        using errcode = '42501';
    end if;
  elsif tg_op = 'UPDATE' then
    if v_is_client_request and new.role is distinct from old.role then
      raise exception 'Modifying role is not permitted'
        using errcode = '42501';
    end if;
    new.role := coalesce(new.role, old.role, 'user');
  end if;

  return new;
end;
$$;

drop trigger if exists on_profiles_enforce_role_security on public.profiles;
create trigger on_profiles_enforce_role_security
  before insert or update on public.profiles
  for each row execute function public.enforce_profile_role_security();

-- 3. Sync verified role into server-only auth.users.raw_app_meta_data
create or replace function public.sync_profile_role_to_app_metadata()
returns trigger
language plpgsql
security definer
set search_path = public, auth
as $$
begin
  update auth.users
  set raw_app_meta_data = coalesce(raw_app_meta_data, '{}'::jsonb)
    || jsonb_build_object('role', new.role)
  where id = new.id
    and coalesce(raw_app_meta_data ->> 'role', '') is distinct from new.role;

  return new;
end;
$$;

drop trigger if exists on_profiles_sync_role_metadata on public.profiles;
create trigger on_profiles_sync_role_metadata
  after insert or update of role on public.profiles
  for each row execute function public.sync_profile_role_to_app_metadata();

-- Backfill server-only app_metadata.role for existing users
update auth.users u
set raw_app_meta_data = coalesce(u.raw_app_meta_data, '{}'::jsonb)
  || jsonb_build_object('role', p.role)
from public.profiles p
where p.id = u.id
  and coalesce(u.raw_app_meta_data ->> 'role', '') is distinct from p.role;

-- 4. Trusted server-side role & admin authorization checks (SECURITY DEFINER avoids RLS recursion)
create or replace function public.get_my_role()
returns text
language plpgsql
stable
security definer
set search_path = public, auth
as $$
declare
  v_uid uuid := auth.uid();
  v_profile_role text;
  v_app_role text;
begin
  if v_uid is null then
    return null;
  end if;

  select
    p.role,
    u.raw_app_meta_data ->> 'role'
  into
    v_profile_role,
    v_app_role
  from auth.users u
  left join public.profiles p on p.id = u.id
  where u.id = v_uid;

  if v_profile_role is null then
    return null;
  end if;

  if v_profile_role = 'admin' and v_app_role = 'admin' then
    return 'admin';
  elsif v_profile_role = 'user' then
    return 'user';
  end if;

  return null;
end;
$$;

create or replace function public.verify_admin_access()
returns boolean
language sql
stable
security definer
set search_path = public, auth
as $$
  select coalesce(public.get_my_role() = 'admin', false);
$$;

revoke all on function public.get_my_role() from public, anon;
grant execute on function public.get_my_role() to authenticated, service_role;

revoke all on function public.verify_admin_access() from public, anon;
grant execute on function public.verify_admin_access() to authenticated, service_role;

-- 5. Harden RLS policies on public.profiles so users cannot escalate their own role
drop policy if exists "Public profiles are viewable by everyone." on public.profiles;
drop policy if exists "Users can view their own profile." on public.profiles;
create policy "Users can view their own profile." on public.profiles
  for select to authenticated
  using (
    (select auth.uid()) = id
    or (select public.verify_admin_access())
  );

drop policy if exists "Users can insert their own profile." on public.profiles;
create policy "Users can insert their own profile." on public.profiles
  for insert to authenticated
  with check (
    (select auth.uid()) = id
    and role = 'user'
  );

drop policy if exists "Users can update own profile." on public.profiles;
create policy "Users can update own profile." on public.profiles
  for update to authenticated
  using ((select auth.uid()) = id)
  with check (
    (select auth.uid()) = id
    and role = (select public.get_my_role())
  );

-- 6. Update signup trigger to always provision 'user' role and never trust user_metadata
create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into public.profiles (id, email, full_name, avatar_url, role)
  values (
    new.id,
    new.email,
    coalesce(
      nullif(trim(new.raw_user_meta_data ->> 'full_name'), ''),
      split_part(coalesce(new.email, 'User'), '@', 1)
    ),
    new.raw_user_meta_data ->> 'avatar_url',
    'user'
  )
  on conflict (id) do update set
    email = coalesce(excluded.email, public.profiles.email),
    full_name = coalesce(nullif(trim(public.profiles.full_name), ''), excluded.full_name),
    avatar_url = coalesce(public.profiles.avatar_url, excluded.avatar_url),
    role = coalesce(public.profiles.role, 'user');

  if to_regclass('public.user_security_settings') is not null then
    execute 'insert into public.user_security_settings (user_id) values ($1) on conflict (user_id) do nothing'
      using new.id;
  end if;

  return new;
end;
$$;

notify pgrst, 'reload schema';

-- migrate:down
drop policy if exists "Users can update own profile." on public.profiles;
create policy "Users can update own profile." on public.profiles
  for update to authenticated
  using ((select auth.uid()) = id)
  with check ((select auth.uid()) = id);

drop policy if exists "Users can insert their own profile." on public.profiles;
create policy "Users can insert their own profile." on public.profiles
  for insert to authenticated
  with check ((select auth.uid()) = id);

drop policy if exists "Users can view their own profile." on public.profiles;
create policy "Users can view their own profile." on public.profiles
  for select to authenticated
  using ((select auth.uid()) = id);

revoke all on function public.verify_admin_access() from authenticated, service_role;
drop function if exists public.verify_admin_access();

revoke all on function public.get_my_role() from authenticated, service_role;
drop function if exists public.get_my_role();

drop trigger if exists on_profiles_sync_role_metadata on public.profiles;
drop function if exists public.sync_profile_role_to_app_metadata();

drop trigger if exists on_profiles_enforce_role_security on public.profiles;
drop function if exists public.enforce_profile_role_security();
