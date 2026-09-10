-- Base tables for the Wishlist app.
--
-- MUST run before 20260910000000_firebase_bridge.sql (hence the earlier
-- timestamp): the bridge migration creates RLS policies on these tables.
--
-- Conventions the app code relies on — do not "fix" without updating the
-- Dart models + repositories:
--   * All user-id columns are TEXT holding Firebase UIDs (identity is
--     Firebase Auth; see SupabaseSessionBridge + firebase-bridge function).
--   * wishlist_items.id is TEXT: the app generates 32-hex random ids
--     (core id_generator), not uuids.
--   * subscriptions has a composite PK so the app's upsert({subscriber_id,
--     target_user_id}) matches instead of inserting duplicates.
--   * RLS is enabled here; the actual policies live in the bridge migration.
--   * Tables are added to the supabase_realtime publication: the app's
--     watchMine/watchProfile streams need it.
--
-- Apply: supabase db push   (or paste into Supabase -> SQL Editor)

-- 1. profiles -------------------------------------------------------------
create table if not exists public.profiles (
  user_id text primary key,
  username text not null default 'user',
  avatar_url text,
  date_of_birth date,
  city text
);
alter table public.profiles enable row level security;
create index if not exists profiles_username_idx on public.profiles (username);

-- 2. wishlist_items --------------------------------------------------------
create table if not exists public.wishlist_items (
  id text primary key,
  owner_id text not null,
  name text not null,
  description text,
  image_urls text[] not null default '{}',
  latitude double precision,
  longitude double precision,
  place_label text,
  is_hidden boolean not null default false,
  created_at timestamptz not null default now()
);
alter table public.wishlist_items enable row level security;
create index if not exists wishlist_items_owner_idx
  on public.wishlist_items (owner_id);
create index if not exists wishlist_items_owner_visible_idx
  on public.wishlist_items (owner_id, is_hidden);

-- 3. subscriptions ---------------------------------------------------------
create table if not exists public.subscriptions (
  subscriber_id text not null,
  target_user_id text not null,
  created_at timestamptz not null default now(),
  primary key (subscriber_id, target_user_id)
);
alter table public.subscriptions enable row level security;
create index if not exists subscriptions_subscriber_idx
  on public.subscriptions (subscriber_id);

-- 4. Realtime (needed by watchMine / watchProfile live streams) ------------
-- Idempotent: skips tables already in the publication.
do $$
declare
  t text;
begin
  foreach t in array array['profiles', 'wishlist_items'] loop
    if not exists (
      select 1
      from pg_publication_tables
      where pubname = 'supabase_realtime'
        and schemaname = 'public'
        and tablename = t
    ) then
      execute format(
        'alter publication supabase_realtime add table public.%I', t
      );
    end if;
  end loop;
end $$;
