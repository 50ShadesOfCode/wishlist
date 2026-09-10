# Wishlist App

Flutter wishlist application — users create wishlists, connect via subscriptions,
discuss wishes in secret chats, and pin sale places on maps.

Source code lives in [`wishlist_app/`](./wishlist_app) (created as requested:
a dedicated folder with the corresponding name).

## Structure (Clean Architecture, per-feature packages)

```text
wishlist_app/                 # runnable Flutter app (Flutter 3.47.3 / Dart 3.13.3)
  lib/
    main.dart                 # Firebase + Supabase + Hive + DI + EasyLocalization bootstrap
    app.dart                  # MaterialApp.router, light/dark theme
    di/injection.dart         # get_it wiring for all features
    router/app_router.dart    # go_router: auth guard + bottom-nav shell
    services/                 # supabase_session_bridge, sync_service
                              # (theme + notifications live in core/)
  assets/translations/{en,ru}.json
  core/                       # failures, exceptions, usecases, network_info,
                              # secure/prefs/hive/outbox storage, logger,
                              # validators, ThemeController, NotificationService
  core_ui/                    # app_colors, app_fonts, app_dimens, app_theme +
                              # widgets/material_ui/*, widgets/cupertino_ui/*, widgets/common/*
  features/
    auth/                     # email/pass + Google + Apple, change/restore password
    profile/                  # picture, username, dob, city + settings
                              # (theme, logout, delete) — Telegram-style combined page
    wishlist/                 # CRUD + hide, image carousel, map place,
                              # subscriptions + local notifications
    chat/                     # secret discussions, photo sharing, Firebase;
                              # deleteChatsForItem() destroys chats on item delete
```

Each feature package follows `data / domain / presentation` (Clean Architecture)
with `flutter_bloc` state management and path dependencies on `core` / `core_ui`.

## Tech stack (exact versions)

Flutter 3.47.3, Dart 3.13.3, new split `material_ui` / `cupertino_ui` widgets
(all UI imports use `package:material_ui/material_ui.dart` and
`package:cupertino_ui/cupertino_ui.dart`, matching `flutter_form_builder` v11).

Storage: Supabase (remote DB), `isar_plus ^1.3.9` (local DB abstraction),
`flutter_secure_storage ^11.0.0` (secrets), `shared_preferences ^2.5.5`
(non-secrets), `hive_ce ^2.19.3` (Supabase cache). Firebase (`firebase_core`,
`cloud_firestore`, `firebase_auth`) backs chats. See per-package `pubspec.yaml`
for the full pinned list (`flutter_bloc ^9.1.1`, `go_router ^18.0.1`,
`get_it ^9.2.1` + `injectable ^3.0.0`, `easy_localization ^3.0.8`,
`flutter_local_notifications ^22.3.0`, `flutter_map ^8.3.2`,
`geolocator ^14.0.3`, `local_auth ^3.0.2`, `image_picker ^1.2.3`,
`url_launcher ^6.3.2`, `logging`, `flutter_dotenv`, `flutter_lints`,
`build_runner`, `equatable`, `json_serializable`, `cupertino_icons`,
`flutter_svg`, `shimmer`, `carousel_slider`, `dropdown_button2 ^3.1.0`
(v3 `DropdownItem` + `valueListenable` API), `skeletonizer`,
`flutter_form_builder ^11.0.0`).

## Setup

1. `cd wishlist_app && cp .env.example .env` (repo root `.env.example` also copied)
   and fill `SUPABASE_URL` / `SUPABASE_ANON_KEY`.
2. Add Firebase config (`google-services.json` / `GoogleService-Info.plist`) —
   required for chats; app still analyzes/tests without it.
3. `flutter pub get && flutter analyze && flutter test`
4. Supabase tables: `profiles`, `wishlist_items`, `subscriptions`;
   storage buckets: `avatars`. Firestore collections: `chats/{id}/messages`.

## Notes / TODOs

- `WishlistRepository.deleteItem` callers must also call
  `ChatRepository.deleteChatsForItem(itemId)` (wired in UI delete flow).
- Theme toggle persists locally via `PrefsService`; wire `ProfilePage.onChangeTheme`
  to app-level `ThemeMode` for full effect.
- Avatar/item photo uploads use Supabase `avatars` bucket; chat photos-note
  production upload to Firebase Storage (local path placeholder now).
