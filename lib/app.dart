import 'dart:async';

import 'package:auth/auth.dart';
import 'package:core_ui/core_ui.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:profile/profile.dart';

import 'di/injection.dart';
import 'router/app_router.dart';
import 'services/supabase_session_bridge.dart';

class WishlistApp extends StatefulWidget {
  const WishlistApp({super.key});

  @override
  State<WishlistApp> createState() => _WishlistAppState();
}

class _WishlistAppState extends State<WishlistApp> {
  late final AuthBloc _authBloc;
  late final GoRouter _router;
  final ThemeMode _mode = ThemeMode.system;
  StreamSubscription<AuthState>? _authSub;
  String? _profileEnsuredFor;

  @override
  void initState() {
    super.initState();
    _authBloc = sl<AuthBloc>()..add(const AuthChecked());
    // Created once: rebuilding GoRouter would reset the navigation stack.
    // Auth-driven redirects are handled by refreshListenable inside.
    _router = createRouter(_authBloc);
    _authSub = _authBloc.stream.listen(_ensureSupabaseProfile);
  }

  /// Bridges Firebase Auth into a Supabase session (RLS identity) and
  /// creates the matching Supabase `profiles` row on first registration
  /// (email sign-up or first Google/Apple sign-in). Idempotent: only runs
  /// once per user and skips when the session/row already exists.
  Future<void> _ensureSupabaseProfile(AuthState state) async {
    final user = state.user;
    if (state.status != AuthStatus.authenticated || user == null) {
      _profileEnsuredFor = null;
      await sl<SupabaseSessionBridge>().clear();
      return;
    }
    if (_profileEnsuredFor == user.id) return;
    _profileEnsuredFor = user.id;
    try {
      await sl<SupabaseSessionBridge>().ensureSession();
      final repo = sl<ProfileRepository>();
      final existing = await repo.getProfile(user.id);
      if (existing == null) {
        await repo.updateProfile(
          Profile(
            userId: user.id,
            username:
                user.displayName ?? user.email.split('@').first,
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
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider.value(
      value: _authBloc,
      child: MaterialApp.router(
        title: 'Wishlist',
        theme: AppTheme.light(),
        darkTheme: AppTheme.dark(),
        themeMode: _mode,
        locale: context.locale,
        supportedLocales: context.supportedLocales,
        localizationsDelegates: context.localizationDelegates,
        routerConfig: _router,
      ),
    );
  }
}
