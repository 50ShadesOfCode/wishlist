-- Firebase -> Supabase auth bridge.
--
-- Auth is Firebase; Supabase calls use the anon key, so stock
-- `auth.uid()` checks can't work. The firebase-bridge Edge Function mints a
-- Supabase session whose user_metadata.firebase_uid equals the Firebase UID,
-- and the policies below scope rows on that claim:
--   (auth.jwt() -> 'user_metadata' ->> 'firebase_uid')
--
-- Run in Supabase -> SQL Editor (after the base tables exist, with TEXT
-- user-id columns holding Firebase UIDs).

-- 1. Firebase UID <-> Supabase user id mapping (service_role only:
--    RLS enabled with no policies denies anon/authenticated access).
create table if not exists public.firebase_identities (
  firebase_uid text primary key,
  supabase_user_id uuid not null references auth.users(id) on delete cascade,
  created_at timestamptz not null default now()
);
alter table public.firebase_identities enable row level security;

-- 2. profiles: anyone signed in can read (needed for subscriptions/
--    shared wishlists); only the owner can write their own row.
drop policy if exists "anon all profiles" on public.profiles;
drop policy if exists "profiles read" on public.profiles;
drop policy if exists "profiles write own" on public.profiles;
drop policy if exists "profiles read all" on public.profiles;
drop policy if exists "own profile" on public.profiles;

create policy "profiles read all" on public.profiles
  for select to authenticated using (true);

create policy "own profile" on public.profiles
  for all to authenticated
  using (user_id = (auth.jwt() -> 'user_metadata' ->> 'firebase_uid'))
  with check (user_id = (auth.jwt() -> 'user_metadata' ->> 'firebase_uid'));

-- 3. wishlist_items: visible items are public to signed-in users, hidden
--    ones only to the owner; writes are owner-only.
drop policy if exists "anon all items" on public.wishlist_items;
drop policy if exists "items read visible" on public.wishlist_items;
drop policy if exists "items write own" on public.wishlist_items;

create policy "items read visible" on public.wishlist_items
  for select to authenticated
  using (
    is_hidden = false
    or owner_id = (auth.jwt() -> 'user_metadata' ->> 'firebase_uid')
  );

create policy "items write own" on public.wishlist_items
  for all to authenticated
  using (owner_id = (auth.jwt() -> 'user_metadata' ->> 'firebase_uid'))
  with check (owner_id = (auth.jwt() -> 'user_metadata' ->> 'firebase_uid'));

-- 4. subscriptions: a user manages rows where they are the subscriber;
--    either side can read the relationship.
drop policy if exists "anon all subs" on public.subscriptions;
drop policy if exists "subs own" on public.subscriptions;
drop policy if exists "subs read" on public.subscriptions;
drop policy if exists "subs write own" on public.subscriptions;

create policy "subs read" on public.subscriptions
  for select to authenticated
  using (
    subscriber_id = (auth.jwt() -> 'user_metadata' ->> 'firebase_uid')
    or target_user_id = (auth.jwt() -> 'user_metadata' ->> 'firebase_uid')
  );

create policy "subs write own" on public.subscriptions
  for all to authenticated
  using (subscriber_id = (auth.jwt() -> 'user_metadata' ->> 'firebase_uid'))
  with check (
    subscriber_id = (auth.jwt() -> 'user_metadata' ->> 'firebase_uid')
  );

-- 5. avatars bucket: public read (getPublicUrl), owner-folder writes.
--    Avatar path is "<firebase_uid>/avatar.<ext>".
drop policy if exists "anon avatars" on storage.objects;
drop policy if exists "avatar read" on storage.objects;
drop policy if exists "avatar write own" on storage.objects;

create policy "avatar read" on storage.objects
  for select to authenticated using (bucket_id = 'avatars');

create policy "avatar write own" on storage.objects
  for all to authenticated
  using (
    bucket_id = 'avatars'
    and (storage.foldername(name))[1] =
      (auth.jwt() -> 'user_metadata' ->> 'firebase_uid')
  )
  with check (
    bucket_id = 'avatars'
    and (storage.foldername(name))[1] =
      (auth.jwt() -> 'user_metadata' ->> 'firebase_uid')
  );
