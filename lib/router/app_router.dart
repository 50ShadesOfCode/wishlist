import 'package:auth/auth.dart';
import 'package:chat/chat.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:profile/profile.dart';
import 'package:wishlist/wishlist.dart';

import '../di/injection.dart';

final _rootNavigatorKey = GlobalKey<NavigatorState>();

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
        builder: (context, _) => BlocProvider.value(
          value: authBloc,
          child: SignInPage(
            onGoSignUp: () => context.go('/signup'),
            onGoReset: () => context.go('/reset'),
            onSuccess: () => context.go('/wishlist'),
          ),
        ),
      ),
      GoRoute(
        path: '/signup',
        builder: (context, _) => BlocProvider.value(
          value: authBloc,
          child: SignUpPage(
            onGoSignIn: () => context.go('/signin'),
            onSuccess: () => context.go('/wishlist'),
          ),
        ),
      ),
      GoRoute(
        path: '/reset',
        builder: (_, _) => const ResetPasswordPage(),
      ),
      StatefulShellRoute.indexedStack(
        builder: (context, _, shell) => HomeShell(shell: shell),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/wishlist',
                builder: (context, _) {
                  final userId =
                      authBloc.state.user?.id ?? 'local-user';
                  // Singleton bloc shared with the edit sub-route below.
                  final bloc = sl<WishlistBloc>()
                    ..add(WishlistLoad(userId));
                  return BlocProvider.value(
                    value: bloc,
                    child: WishlistListPage(
                      ownerId: userId,
                      onAdd: () => context.push('/wishlist/edit'),
                      onOpenItem: (itemId) {
                        WishlistItem? item;
                        for (final e in bloc.state.items) {
                          if (e.id == itemId) item = e;
                        }
                        context.push('/wishlist/edit', extra: item);
                      },
                    ),
                  );
                },
                routes: [
                  GoRoute(
                    path: 'edit',
                    builder: (_, state) => BlocProvider.value(
                      value: sl<WishlistBloc>(),
                      child: WishlistEditPage(
                        ownerId: authBloc.state.user?.id ?? 'local-user',
                        existing: state.extra as WishlistItem?,
                      ),
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
                  final userId =
                      authBloc.state.user?.id ?? 'local-user';
                  // Watch is dispatched once in ChatListPage.initState; do
                  // not add it here or rebuilds duplicate subscriptions.
                  return BlocProvider.value(
                    value: sl<ChatBloc>(),
                    child: ChatListPage(
                      userId: userId,
                      onOpenThread: (id) => context.push('/chats/$id'),
                    ),
                  );
                },
                routes: [
                  GoRoute(
                    path: ':id',
                    builder: (_, state) {
                      final id = state.pathParameters['id']!;
                      return BlocProvider.value(
                        value: sl<ChatBloc>(),
                        child: ChatThreadPage(
                          chatId: id,
                          currentUserId:
                              authBloc.state.user?.id ?? 'local-user',
                        ),
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
                path: '/profile',
                builder: (context, _) => BlocProvider.value(
                  value: sl<ProfileBloc>(),
                  child: ProfilePage(
                    userId: authBloc.state.user?.id ?? 'local-user',
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
                            SnackBar(
                              content: Text('Delete failed: $e'),
                            ),
                          );
                        }
                        return;
                      }
                      authBloc.add(const DeleteAccountRequested());
                    },
                    onChangePassword: () => context.push('/profile/password'),
                  ),
                ),
                routes: [
                  GoRoute(
                    path: 'password',
                    builder: (_, _) => ChangePasswordPage(
                      onChange: (cur, next) => sl<AuthRepository>()
                          .changePassword(
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
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.card_giftcard),
            label: 'Wishlist',
          ),
          NavigationDestination(icon: Icon(Icons.chat_bubble), label: 'Chats'),
          NavigationDestination(icon: Icon(Icons.person), label: 'Profile'),
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
