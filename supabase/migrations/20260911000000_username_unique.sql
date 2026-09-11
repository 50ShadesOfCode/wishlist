-- Case-insensitive username uniqueness.
--
-- The app checks `isUsernameTaken` via `ilike` before saving (friendly form
-- error), but concurrent sign-ups can race the check. This unique index on
-- `lower(username)` is the final arbiter: the loser gets a 23505 that the
-- repository maps to a failure instead of silently duplicating a username.
--
-- Apply: supabase db push   (or paste into Supabase -> SQL Editor)

create unique index if not exists profiles_username_lower_uidx
  on public.profiles (lower(username));
