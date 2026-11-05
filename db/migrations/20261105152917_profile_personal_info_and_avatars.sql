-- migrate:up

-- 1. Add personal information and contact columns to public.profiles
alter table public.profiles
  add column if not exists role text default 'user',
  add column if not exists username text,
  add column if not exists phone_number text,
  add column if not exists address text,
  add column if not exists emergency_contact_name text,
  add column if not exists emergency_contact_phone text,
  add column if not exists updated_at timestamp with time zone default timezone('utc'::text, now()) not null;

alter table public.profiles
  alter column role set default 'user';

update public.profiles
  set role = 'user'
  where role is null;

-- 2. Backfill any existing auth.users missing a public.profiles row
insert into public.profiles (id, email, full_name, avatar_url, role)
select
  u.id,
  u.email,
  coalesce(
    nullif(trim(u.raw_user_meta_data->>'full_name'), ''),
    split_part(coalesce(u.email, 'User'), '@', 1)
  ),
  u.raw_user_meta_data->>'avatar_url',
  'user'
from auth.users u
on conflict (id) do nothing;

-- 3. Update handle_new_user() with explicit search_path and safe conflict handling
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
  return new;
end;
$$;

-- 4. Maintain updated_at and protect role column from client privilege escalation
create or replace function public.protect_and_touch_profile()
returns trigger
language plpgsql
set search_path = public
as $$
begin
  new.updated_at := timezone('utc'::text, now());
  if current_user = 'authenticated'
     or coalesce(current_setting('request.jwt.claim.role', true), '') = 'authenticated' then
    new.role := coalesce(old.role, 'user');
  else
    new.role := coalesce(new.role, old.role, 'user');
  end if;
  return new;
end;
$$;

drop trigger if exists on_profiles_updated on public.profiles;
create trigger on_profiles_updated
  before update on public.profiles
  for each row
  execute function public.protect_and_touch_profile();

-- 5. Enable RLS and configure strict owner-only policies on public.profiles
alter table public.profiles enable row level security;

drop policy if exists "Public profiles are viewable by everyone." on public.profiles;
drop policy if exists "Enable insert for authenticated users only" on public.profiles;
drop policy if exists "Users can view their own profile." on public.profiles;
drop policy if exists "Users can insert their own profile." on public.profiles;
drop policy if exists "Users can update own profile." on public.profiles;

create policy "Users can view their own profile."
  on public.profiles
  for select
  to authenticated
  using ((select auth.uid()) = id);

create policy "Users can insert their own profile."
  on public.profiles
  for insert
  to authenticated
  with check ((select auth.uid()) = id);

create policy "Users can update own profile."
  on public.profiles
  for update
  to authenticated
  using ((select auth.uid()) = id)
  with check ((select auth.uid()) = id);

revoke all on public.profiles from anon;
grant select, insert, update on public.profiles to authenticated;

-- 6. Create Supabase Storage bucket for profile avatars (5 MB limit, image MIME types)
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values (
  'avatars',
  'avatars',
  true,
  5242880,
  array['image/jpeg', 'image/png', 'image/webp', 'image/gif']
)
on conflict (id) do update set
  public = excluded.public,
  file_size_limit = excluded.file_size_limit,
  allowed_mime_types = excluded.allowed_mime_types;

-- 7. Storage RLS policies for avatars (SELECT + INSERT + UPDATE + DELETE)
drop policy if exists "Avatar images are publicly accessible." on storage.objects;
create policy "Avatar images are publicly accessible."
  on storage.objects
  for select
  using (bucket_id = 'avatars');

drop policy if exists "Users can upload their own avatar." on storage.objects;
create policy "Users can upload their own avatar."
  on storage.objects
  for insert
  to authenticated
  with check (
    bucket_id = 'avatars'
    and (storage.foldername(name))[1] = (select auth.uid())::text
  );

drop policy if exists "Users can update their own avatar." on storage.objects;
create policy "Users can update their own avatar."
  on storage.objects
  for update
  to authenticated
  using (
    bucket_id = 'avatars'
    and (storage.foldername(name))[1] = (select auth.uid())::text
  )
  with check (
    bucket_id = 'avatars'
    and (storage.foldername(name))[1] = (select auth.uid())::text
  );

drop policy if exists "Users can delete their own avatar." on storage.objects;
create policy "Users can delete their own avatar."
  on storage.objects
  for delete
  to authenticated
  using (
    bucket_id = 'avatars'
    and (storage.foldername(name))[1] = (select auth.uid())::text
  );

-- migrate:down
drop policy if exists "Users can delete their own avatar." on storage.objects;
drop policy if exists "Users can update their own avatar." on storage.objects;
drop policy if exists "Users can upload their own avatar." on storage.objects;
drop policy if exists "Avatar images are publicly accessible." on storage.objects;

drop trigger if exists on_profiles_updated on public.profiles;
drop function if exists public.protect_and_touch_profile();

alter table public.profiles
  drop column if exists emergency_contact_phone,
  drop column if exists emergency_contact_name,
  drop column if exists address,
  drop column if exists phone_number,
  drop column if exists username,
  drop column if exists updated_at;
