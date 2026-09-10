import 'package:auth/auth.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

/// Notifies go_router to re-evaluate [authRedirect] on auth changes.
class AuthListenable extends ChangeNotifier {
  AuthListenable(this._bloc) {
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

/// Sends guests to sign-in and signed-in users away from auth pages.
String? authRedirect(AuthBloc authBloc, GoRouterState state) {
  final auth = authBloc.state;
  final isAuth = auth.status == AuthStatus.authenticated;
  final loc = state.matchedLocation;
  final isAuthRoute = loc == '/signin' || loc == '/signup' || loc == '/reset';
  if (!isAuth && !isAuthRoute) return '/signin';
  if (isAuth && isAuthRoute) return '/wishlist';
  return null;
}
