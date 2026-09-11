import 'dart:async';

import 'package:auth/auth.dart';
import 'package:chat/chat.dart';
import 'package:core/core.dart';
import 'package:core_ui/core_ui.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:firebase_auth/firebase_auth.dart' hide AuthProvider;
import 'package:material_ui/material_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:profile/profile.dart';
import 'package:wishlist/wishlist.dart';

import 'di/injection.dart';
import 'router/app_router.dart';
import 'services/supabase_session_bridge.dart';
import 'services/sync_service.dart';

class WishlistApp extends StatefulWidget {
  const WishlistApp({super.key});

  @override
  State<WishlistApp> createState() => _WishlistAppState();
}

class _WishlistAppState extends State<WishlistApp> {
  late final AuthBloc _authBloc;
  late final GoRouter _router;
  late final ThemeController _theme;
  StreamSubscription<AuthState>? _authSub;
  StreamSubscription<bool>? _connectivitySub;
  StreamSubscription<User?>? _firebaseSessionSub;
  Timer? _reconnectDebounce;
  String? _profileEnsuredFor;

  @override
  void initState() {
    super.initState();
    _authBloc = sl<AuthBloc>()..add(const AuthChecked());
    _theme = sl<ThemeController>();
    // Created once: rebuilding GoRouter would reset the navigation stack.
    // Auth-driven redirects are handled by refreshListenable inside.
    _router = createRouter(_authBloc);
    _authSub = _authBloc.stream.listen(_ensureSupabaseProfile);
    sl<NotificationService>().onTap = _onNotificationTap;
    // Killed-app launch via a notification tap: queue until authenticated
    // (routed at the end of _ensureSupabaseProfile).
    sl<NotificationService>().getInitialTap().then((tap) {
      if (tap == null) return;
      if (_authBloc.state.status == AuthStatus.authenticated) {
        _onNotificationTap(tap);
      } else {
        _pendingLaunchTap = tap;
      }
    });
    // Expired/revoked session observer: Firebase signs out (or the token
    // becomes invalid) outside the bloc's control — e.g. password change on
    // another device, admin revocation. Re-check auth so the guard routes
    // back to sign-in instead of stranding the user on authed pages.
    _firebaseSessionSub = FirebaseAuth.instance.authStateChanges().listen((
      fbUser,
    ) {
      if (fbUser == null &&
          _authBloc.state.status == AuthStatus.authenticated) {
        _authBloc.add(const AuthChecked());
      }
    });
    // Drain the offline outbox whenever connectivity returns while signed
    // in (SyncService itself no-ops when offline or already syncing).
    // Edges are debounced: radio flaps (tunnel/lift/elevator) would
    // otherwise trigger a sync storm of full queue drains.
    _connectivitySub = sl<NetworkInfo>().onConnectivityChanged.listen((online) {
      _reconnectDebounce?.cancel();
      if (!online) return;
      _reconnectDebounce = Timer(reconnectDebounce, () {
        if (_authBloc.state.status == AuthStatus.authenticated) {
          sl<SyncService>().syncNow();
        }
      });
    });
  }

  /// Quiet period after a connectivity edge before draining the outbox.
  static const reconnectDebounce = Duration(seconds: 2);

  /// Notification tap that arrived before auth resolved (e.g. killed-app
  /// launch): held until the first authenticated emission, then routed.
  NotificationTap? _pendingLaunchTap;

  /// Deep-links notification taps: `item:<id>` opens the wish for editing
  /// (falling back to a server fetch when the item isn't in memory),
  /// `chat:<id>` opens the thread.
  Future<void> _onNotificationTap(NotificationTap tap) async {
    switch (tap.type) {
      case 'item':
        WishlistItem? item;
        try {
          for (final e in sl<WishlistBloc>().state.items) {
            if (e.id == tap.id) item = e;
          }
        } catch (_) {
          item = null;
        }
        // In-memory miss (restarted app, unfetched list): fall back to the
        // online-only fetch instead of dropping the deep link.
        if (item == null) {
          try {
            if (sl.isRegistered<GetItemByIdUseCase>()) {
              item = await sl<GetItemByIdUseCase>().call(tap.id);
            }
          } catch (_) {
            item = null;
          }
        }
        if (item != null) _router.push('/wishlist/edit', extra: item);
      case 'chat':
        _router.push('/chats/${tap.id}');
    }
  }

  /// Bridges Firebase Auth into a Supabase session (RLS identity) and
  /// creates the matching Supabase `profiles` row on first registration
  /// (email sign-up or first Google/Apple sign-in). Idempotent: only runs
  /// once per user and skips when the session/row already exists.
  ///
  /// Profile auto-create runs only on confirmed-online absence: an offline
  /// `getProfile` returning null (no cache) must never trigger an upsert —
  /// that would queue a clobbering offline op over the real row.
  Future<void> _ensureSupabaseProfile(AuthState state) async {
    final user = state.user;
    if (state.status != AuthStatus.authenticated || user == null) {
      _profileEnsuredFor = null;
      if (sl.isRegistered<SyncService>()) {
        sl<SyncService>().currentUserId = null;
      }
      // Privacy: singleton blocs keep the previous user's state; reset them
      // to initial on every sign-out so the next user starts clean.
      // Dispatched as events (not direct emits) so subscriptions cancel
      // properly inside each bloc.
      if (sl.isRegistered<WishlistBloc>()) {
        sl<WishlistBloc>().add(const WishlistReset());
      }
      if (sl.isRegistered<ProfileBloc>()) {
        sl<ProfileBloc>().add(const ProfileReset());
      }
      if (sl.isRegistered<ChatBloc>()) {
        sl<ChatBloc>().add(const ChatReset());
      }
      await sl<SupabaseSessionBridge>().clear();
      return;
    }
    if (_profileEnsuredFor == user.id) return;
    _profileEnsuredFor = user.id;
    // Scope sync + purge another user's queued ops before any replay.
    if (sl.isRegistered<SyncService>()) {
      sl<SyncService>().currentUserId = user.id;
    }
    try {
      if (sl.isRegistered<OutboxService>()) {
        final dropped = await sl<OutboxService>().purgeForeignOps(user.id);
        if (dropped > 0) {
          appLogger.info('Purged $dropped foreign outbox ops on sign-in');
        }
      }
    } catch (_) {
      // Purge is best-effort; SyncService skips foreign ops anyway.
    }
    try {
      await sl<SupabaseSessionBridge>().ensureSession();
      final online = await sl<NetworkInfo>().isConnected;
      if (!online) {
        // Offline: session/profile work waits for reconnect (the
        // connectivity listener triggers SyncService then).
        _profileEnsuredFor = null;
        return;
      }
      Profile? existing;
      try {
        existing = await sl<GetProfileUseCase>().call(user.id);
      } catch (e) {
        // 401/expiry: force a fresh Firebase token + re-bridge once, then
        // retry the fetch before giving up for this emission.
        if (_looksUnauthorized(e)) {
          await sl<SupabaseSessionBridge>().ensureSession(forceRefresh: true);
          existing = await sl<GetProfileUseCase>().call(user.id);
        } else {
          rethrow;
        }
      }
      if (existing == null) {
        // Column-preserving: only the identity columns are set for a new
        // row; an existing row is never overwritten here (the upsert would
        // clobber columns edited on another device).
        await sl<UpdateProfileUseCase>().call(
          Profile(
            userId: user.id,
            username: user.displayName ?? user.email.split('@').first,
            avatarUrl: user.photoUrl,
          ),
        );
      }
      // Route a killed-app launch tap now that auth + profile resolved.
      final launchTap = _pendingLaunchTap;
      _pendingLaunchTap = null;
      if (launchTap != null) await _onNotificationTap(launchTap);
      // Drain any queued offline ops for this user.
      if (await sl<NetworkInfo>().isConnected) {
        await sl<SyncService>().syncNow();
      }
    } catch (e) {
      // Offline or backend error: retry on next authenticated emission.
      appLogger.warning('Supabase profile ensure failed: $e');
      _profileEnsuredFor = null;
    }
  }

  bool _looksUnauthorized(Object e) {
    final text = e.toString().toLowerCase();
    return text.contains('401') ||
        text.contains('unauthorized') ||
        text.contains('jwt') ||
        text.contains('expired');
  }

  @override
  void dispose() {
    _authSub?.cancel();
    _connectivitySub?.cancel();
    _firebaseSessionSub?.cancel();
    _reconnectDebounce?.cancel();
    // Release the Hive handle held by the outbox (single-handle discipline:
    // caches are app-lifetime singletons, closed here alongside the root
    // widget rather than per-operation).
    if (sl.isRegistered<OutboxService>()) {
      sl<OutboxService>().dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider.value(
      value: _authBloc,
      child: ListenableBuilder(
        listenable: _theme,
        builder: (_, _) => MaterialApp.router(
          title: 'Wishlist',
          theme: AppTheme.light(),
          darkTheme: AppTheme.dark(),
          themeMode: _theme.mode,
          locale: context.locale,
          supportedLocales: context.supportedLocales,
          localizationsDelegates: context.localizationDelegates,
          routerConfig: _router,
        ),
      ),
    );
  }
}
