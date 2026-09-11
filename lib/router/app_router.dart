import 'package:auth/auth.dart';
import 'package:chat/chat.dart';
import 'package:core/core.dart';
import 'package:core_ui/core_ui.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:material_ui/material_ui.dart';
import 'package:go_router/go_router.dart';
import 'package:profile/profile.dart';
import 'package:wishlist/wishlist.dart';

import '../di/injection.dart';
import '../services/sync_service.dart';
import 'auth_guard.dart';
import 'chat_navigation.dart';
import 'home_shell.dart';

final _rootNavigatorKey = GlobalKey<NavigatorState>();

GoRouter createRouter(AuthBloc authBloc) {
  return GoRouter(
    navigatorKey: _rootNavigatorKey,
    initialLocation: '/signin',
    refreshListenable: AuthListenable(authBloc),
    redirect: (context, state) => authRedirect(authBloc, state),
    routes: [
      GoRoute(
        path: '/signin',
        builder: (context, _) =>
            SignInPage(onGoSignUp: () => context.go('/signup'), onGoReset: () => context.go('/reset')),
      ),
      GoRoute(
        path: '/signup',
        builder: (context, _) =>
            SignUpPage(onGoSignIn: () => context.go('/signin')),
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
                  // No guest fallback: the auth guard only lets authenticated
                  // users reach this branch. While the initial AuthChecked is
                  // pending (unknown) the user is null, so hold a loading
                  // screen; the guard re-fires once auth resolves.
                  final userId = authBloc.state.user?.id;
                  if (userId == null) return const AuthPendingScreen();
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
                    builder: (context, state) {
                      final userId = authBloc.state.user?.id;
                      if (userId == null) return const AuthPendingScreen();
                      return WishlistEditPage(
                        ownerId: userId,
                        existing: state.extra as WishlistItem?,
                        onDiscuss: (item) =>
                            openItemChat(context, authBloc, item),
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
                path: '/chats',
                builder: (context, _) {
                  final userId = authBloc.state.user?.id;
                  if (userId == null) return const AuthPendingScreen();
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
                      final userId = authBloc.state.user?.id;
                      if (userId == null) return const AuthPendingScreen();
                      return ChatThreadPage(
                        chatId: id,
                        currentUserId: userId,
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
                  final userId = authBloc.state.user?.id;
                  if (userId == null) return const AuthPendingScreen();
                  return SubscriptionsPage(
                    userId: userId,
                    onLoadSubscriptions: () =>
                        sl<GetSubscriptionsUseCase>().call(userId),
                    onLoadItems: (targetId) =>
                        sl<GetVisibleItemsUseCase>().call(targetId),
                    onSubscribe: (targetId) => sl<SubscribeUseCase>().call(
                      SubscriptionParams(
                        subscriberId: userId,
                        targetUserId: targetId,
                      ),
                    ),
                    onUnsubscribe: (targetId) =>
                        sl<UnsubscribeUseCase>().call(
                          SubscriptionParams(
                            subscriberId: userId,
                            targetUserId: targetId,
                          ),
                        ),
                    resolveName: (id) async {
                      try {
                        final p = await sl<GetProfileUseCase>().call(id);
                        final name = p?.username.trim();
                        return (name == null || name.isEmpty) ? id : name;
                      } catch (_) {
                        return id;
                      }
                    },
                    onDiscuss: (item) => openItemChat(context, authBloc, item),
                  );
                },
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/profile',
                builder: (context, _) {
                  final userId = authBloc.state.user?.id;
                  if (userId == null) return const AuthPendingScreen();
                  return ProfilePage(
                    userId: userId,
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
                    // Full cascade (all through use-cases, never repos):
                    // 1. wishlist rows via DeleteItemUseCase (each deletes
                    //    its row + images + Firestore chats via the hook),
                    // 2. subscriptions on both sides,
                    // 3. remaining Firestore threads,
                    // 4. the Supabase profile row (+ avatars) via
                    //    DeleteProfileUseCase (RLS needs the live session,
                    //    so this runs before the Firebase user delete),
                    // 5. the Firebase user via the bloc.
                    // Any backend step failing aborts and keeps the user
                    // signed in. A `requires-recent-login` Firebase error
                    // leaves a partial state (data already deleted); the
                    // message tells the user to re-authenticate and retry.
                      final userId = authBloc.state.user?.id;
                      if (userId == null) return;
                      Future<void> cascade() async {
                        List<WishlistItem> items = const [];
                        try {
                          items = await sl<GetMyItemsUseCase>().call(userId);
                        } catch (_) {
                          items = const [];
                        }
                        for (final item in items) {
                          await sl<DeleteItemUseCase>().call(item.id);
                        }
                        await sl<DeleteAllSubscriptionsForUserUseCase>().call(
                          userId,
                        );
                        try {
                          await sl<DeleteThreadsForUserUseCase>().call(userId);
                        } catch (_) {
                          // Threads for deleted items are already gone via
                          // the per-item hook; best-effort remainder.
                        }
                        await sl<DeleteProfileUseCase>().call(userId);
                      }
                      try {
                        await cascade();
                      } catch (e) {
                        if (context.mounted) {
                          showAppSnack(context, 'Delete failed: $e');
                        }
                        return;
                      }
                      try {
                        authBloc.add(const DeleteAccountRequested());
                      } catch (e) {
                        if (context.mounted) {
                          showAppSnack(
                            context,
                            _reauthMessage(e),
                          );
                        }
                      }
                  },
                  onChangePassword: () => context.push('/profile/password'),
                  );
                },
                routes: [
                  GoRoute(
                    path: 'password',
                    builder: (_, _) => ChangePasswordPage(
                      onChange: (cur, next) =>
                          sl<ChangePasswordUseCase>().call(
                            ChangePasswordParams(
                              currentPassword: cur,
                              newPassword: next,
                            ),
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

/// Firebase demands a fresh credential for account deletion; when the
/// session is stale the delete throws `requires-recent-login` while data
/// may already be partially removed. Surface a re-auth prompt instead of a
/// raw exception string.
String _reauthMessage(Object e) {
  final text = e.toString().toLowerCase();
  if (text.contains('recent-login') || text.contains('recent login')) {
    return 'delete_reauth'.tr();
  }
  return 'Delete failed: $e';
}

/// Splash held while the initial [AuthChecked] is pending (`unknown`) or the
/// auth state resolves. The guard re-fires once auth settles, so this never
/// strands the user; it only preserves the in-flight location instead of
/// clobbering it to `/signin`.
class AuthPendingScreen extends StatelessWidget {
  const AuthPendingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(body: Center(child: CircularProgressIndicator()));
  }
}
