import 'dart:async';

import 'package:auth/auth.dart';
import 'package:chat/chat.dart';
import 'package:core/core.dart';
import 'package:core_ui/core_ui.dart';
import 'package:easy_localization/easy_localization.dart';
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
    // Drain the offline outbox whenever connectivity returns while signed
    // in (SyncService itself no-ops when offline or already syncing).
    _connectivitySub = sl<NetworkInfo>().onConnectivityChanged.listen((online) {
      if (online && _authBloc.state.status == AuthStatus.authenticated) {
        sl<SyncService>().syncNow();
      }
    });
  }

  /// Deep-links notification taps: `item:<id>` opens the wish for editing
  /// (when still present), `chat:<id>` opens the thread.
  void _onNotificationTap(NotificationTap tap) {
    switch (tap.type) {
      case 'item':
        WishlistItem? item;
        for (final e in sl<WishlistBloc>().state.items) {
          if (e.id == tap.id) item = e;
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
  Future<void> _ensureSupabaseProfile(AuthState state) async {
    final user = state.user;
    if (state.status != AuthStatus.authenticated || user == null) {
      _profileEnsuredFor = null;
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
    try {
      await sl<SupabaseSessionBridge>().ensureSession();
      final existing = await sl<GetProfileUseCase>().call(user.id);
      if (existing == null) {
        await sl<UpdateProfileUseCase>().call(
          Profile(
            userId: user.id,
            username: user.displayName ?? user.email.split('@').first,
            avatarUrl: user.photoUrl,
          ),
        );
      }
    } catch (_) {
      // Offline or backend error: retry on next authenticated emission.
      _profileEnsuredFor = null;
    }
  }

  @override
  void dispose() {
    _authSub?.cancel();
    _connectivitySub?.cancel();
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
