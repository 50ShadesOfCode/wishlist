import 'dart:async';

import 'package:auth/auth.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

/// Notifies go_router to re-evaluate [authRedirect] on auth changes.
class AuthListenable extends ChangeNotifier {
  AuthListenable(this._bloc) {
    _sub = _bloc.stream.listen((_) => notifyListeners());
  }
  final AuthBloc _bloc;
  late final StreamSubscription<AuthState> _sub;

  @override
  void dispose() {
    _sub.cancel();
    super.dispose();
  }
}

/// Deep link captured while a guest was bounced to sign-in. Consumed once
/// after authentication so post-login navigation restores it instead of
/// always landing on `/wishlist`.
String? _pendingRedirect;

/// Sends guests to sign-in and signed-in users away from auth pages.
/// While the initial [AuthChecked] is pending (`unknown`) no redirect fires:
/// callers render a loading screen and the in-flight location is preserved.
String? authRedirect(AuthBloc authBloc, GoRouterState state) {
  final auth = authBloc.state;
  if (auth.status == AuthStatus.unknown) return null;
  final isAuth = auth.status == AuthStatus.authenticated;
  final loc = state.matchedLocation;
  final isAuthRoute = loc == '/signin' || loc == '/signup' || loc == '/reset';
  if (!isAuth && !isAuthRoute) {
    // Remember the full deep link (path + query) for post-login restore.
    _pendingRedirect = state.uri.toString();
    return '/signin';
  }
  if (isAuth && isAuthRoute) {
    final next = _pendingRedirect;
    _pendingRedirect = null;
    if (next != null && !_isAuthRoute(next)) return next;
    return '/wishlist';
  }
  return null;
}

bool _isAuthRoute(String location) {
  final path = Uri.tryParse(location)?.path ?? location;
  return path == '/signin' || path == '/signup' || path == '/reset';
}
