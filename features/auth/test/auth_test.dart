import 'package:flutter_test/flutter_test.dart';
import 'package:auth/auth.dart';
void main() {
  test('AppUser equality', () {
    const a = AppUser(id: '1', email: 'a@b.com');
    const b = AppUser(id: '1', email: 'a@b.com');
    expect(a, b);
  });

  test('AuthState copyWith can clear user, preserves when omitted', () {
    const user = AppUser(id: '1', email: 'a@b.com');
    const s = AuthState(status: AuthStatus.authenticated, user: user);
    expect(s.copyWith().user, user);
    final cleared = s.copyWith(
      status: AuthStatus.unauthenticated,
      user: null,
    );
    expect(cleared.user, isNull);
    expect(cleared.status, AuthStatus.unauthenticated);
  });
}
