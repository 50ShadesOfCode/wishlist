import 'package:auth/auth.dart';
import 'package:chat/chat.dart';
import 'package:core/core.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:material_ui/material_ui.dart';
import 'package:go_router/go_router.dart';
import 'package:profile/profile.dart';
import 'package:wishlist/wishlist.dart';

import '../di/injection.dart';
import '../services/sync_service.dart';

final _rootNavigatorKey = GlobalKey<NavigatorState>();

/// Opens the secret chat for [item], creating the thread on first use.
/// Shared by the wishlist edit page and the following feed.
Future<void> _openItemChat(
  BuildContext context,
  AuthBloc authBloc,
  WishlistItem item,
) async {
  final me = authBloc.state.user?.id;
  if (me == null) return;
  try {
    final thread = await sl<ChatRepository>().getOrCreateThread(
      wishlistItemId: item.id,
      wishlistItemName: item.name,
      ownerId: item.ownerId,
      participantId: me,
    );
    if (context.mounted) {
      context.push('/chats/${thread.id}');
    }
  } catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('${'chat_open_failed'.tr()}: $e')));
    }
  }
}

GoRouter createRouter(AuthBloc authBloc) {
  return GoRouter(
    navigatorKey: _rootNavigatorKey,
    initialLocation: '/signin',
    refreshListenable: _AuthListenable(authBloc),
    redirect: (context, state) {
      final auth = authBloc.state;
      final isAuth = auth.status == AuthStatus.authenticated;
      final loc = state.matchedLocation;
      final isAuthRoute =
          loc == '/signin' || loc == '/signup' || loc == '/reset';
      if (!isAuth && !isAuthRoute) return '/signin';
      if (isAuth && isAuthRoute) return '/wishlist';
      return null;
    },
    routes: [
      GoRoute(
        path: '/signin',
        builder: (context, _) => SignInPage(
          onGoSignUp: () => context.go('/signup'),
          onGoReset: () => context.go('/reset'),
          onSuccess: () => context.go('/wishlist'),
        ),
      ),
      GoRoute(
        path: '/signup',
        builder: (context, _) => SignUpPage(
          onGoSignIn: () => context.go('/signin'),
          onSuccess: () => context.go('/wishlist'),
        ),
      ),
      GoRoute(path: '/reset', builder: (_, _) => const ResetPasswordPage()),
      StatefulShellRoute.indexedStack(
        builder: (context, _, shell) => HomeShell(shell: shell),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/wishlist',
                builder: (context, _) {
                  final userId = authBloc.state.user?.id ?? 'local-user';
                  // Pages provide the shared singleton blocs themselves;
                  // the router only reads state for lookups. The initial
                  // load is dispatched once in WishlistListView initState.
                  final bloc = sl<WishlistBloc>();
                  return WishlistListPage(
                    ownerId: userId,
                    outbox: sl<OutboxService>(),
                    onSyncNow: () => sl<SyncService>().syncNow(),
                    onAdd: () => context.push('/wishlist/edit'),
                    onOpenItem: (itemId) {
                      WishlistItem? item;
                      for (final e in bloc.state.items) {
                        if (e.id == itemId) item = e;
                      }
                      context.push('/wishlist/edit', extra: item);
                    },
                  );
                },
                routes: [
                  GoRoute(
                    path: 'edit',
                    builder: (context, state) => WishlistEditPage(
                      ownerId: authBloc.state.user?.id ?? 'local-user',
                      existing: state.extra as WishlistItem?,
                      onDiscuss: (item) =>
                          _openItemChat(context, authBloc, item),
                    ),
                  ),
                ],
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/chats',
                builder: (context, _) {
                  final userId = authBloc.state.user?.id ?? 'local-user';
                  // Watch is dispatched once in ChatListView initState; do
                  // not add it here or rebuilds duplicate subscriptions.
                  return ChatListPage(
                    userId: userId,
                    onOpenThread: (id) => context.push('/chats/$id'),
                  );
                },
                routes: [
                  GoRoute(
                    path: ':id',
                    builder: (_, state) {
                      final id = state.pathParameters['id']!;
                      return ChatThreadPage(
                        chatId: id,
                        currentUserId: authBloc.state.user?.id ?? 'local-user',
                      );
                    },
                  ),
                ],
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/following',
                builder: (context, _) {
                  final userId = authBloc.state.user?.id ?? 'local-user';
                  return SubscriptionsPage(
                    userId: userId,
                    onLoadSubscriptions: () =>
                        sl<WishlistRepository>().mySubscriptions(userId),
                    onLoadItems: (targetId) =>
                        sl<WishlistRepository>().getVisibleItems(targetId),
                    onSubscribe: (targetId) =>
                        sl<WishlistRepository>().subscribe(userId, targetId),
                    onUnsubscribe: (targetId) =>
                        sl<WishlistRepository>().unsubscribe(userId, targetId),
                    resolveName: (id) async {
                      try {
                        final p = await sl<ProfileRepository>().getProfile(id);
                        final name = p?.username.trim();
                        return (name == null || name.isEmpty) ? id : name;
                      } catch (_) {
                        return id;
                      }
                    },
                    onDiscuss: (item) => _openItemChat(context, authBloc, item),
                  );
                },
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/profile',
                builder: (context, _) => ProfilePage(
                  userId: authBloc.state.user?.id ?? 'local-user',
                  isDark: sl<ThemeController>().isDark,
                  onChangeTheme: (dark) => sl<ThemeController>().setDark(dark),
                  initialLocale: context.locale,
                  supportedLocales: context.supportedLocales,
                  onChangeLocale: (locale) async {
                    await context.setLocale(locale);
                    await sl<PrefsService>().setLocale(locale.languageCode);
                  },
                  onLogout: () => authBloc.add(const SignOutRequested()),
                  onDeleteAccount: () async {
                    // Order matters: the Supabase profile row must go first
                    // (RLS needs the bridged session), then the Firebase
                    // user via the bloc (loading/error states included).
                    // If the profile delete fails, abort and keep the user
                    // signed in; if the Firebase delete needs a recent
                    // login, the session is preserved for a retry and the
                    // missing profile row is recreated on next sign-in.
                    final userId = authBloc.state.user?.id;
                    if (userId == null) return;
                    try {
                      await sl<ProfileRepository>().deleteAccount(userId);
                    } catch (e) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Delete failed: $e')),
                        );
                      }
                      return;
                    }
                    authBloc.add(const DeleteAccountRequested());
                  },
                  onChangePassword: () => context.push('/profile/password'),
                ),
                routes: [
                  GoRoute(
                    path: 'password',
                    builder: (_, _) => ChangePasswordPage(
                      onChange: (cur, next) =>
                          sl<AuthRepository>().changePassword(
                            currentPassword: cur,
                            newPassword: next,
                          ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    ],
  );
}

class HomeShell extends StatelessWidget {
  const HomeShell({super.key, required this.shell});
  final StatefulNavigationShell shell;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: shell,
      bottomNavigationBar: NavigationBar(
        selectedIndex: shell.currentIndex,
        onDestinationSelected: shell.goBranch,
        destinations: [
          NavigationDestination(
            icon: const Icon(Icons.card_giftcard),
            label: 'wishlist'.tr(),
          ),
          NavigationDestination(
            icon: const Icon(Icons.chat_bubble),
            label: 'chats'.tr(),
          ),
          NavigationDestination(
            icon: const Icon(Icons.people_outline),
            label: 'following'.tr(),
          ),
          NavigationDestination(
            icon: const Icon(Icons.person),
            label: 'profile'.tr(),
          ),
        ],
      ),
    );
  }
}

class _AuthListenable extends ChangeNotifier {
  _AuthListenable(this._bloc) {
    _sub = _bloc.stream.listen((_) => notifyListeners());
  }
  final AuthBloc _bloc;
  late final dynamic _sub;

  @override
  void dispose() {
    _sub.cancel();
    super.dispose();
  }
}
