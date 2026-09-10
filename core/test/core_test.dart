import 'package:flutter_test/flutter_test.dart';
import 'package:core/core.dart';
void main() {
  test('mapDataError maps backend errors to failures', () {
    // Auth-domain exceptions are mapAuthError's job; here they surface as
    // generic server failures rather than crashing on unknown types.
    expect(
      () => mapDataError(const AuthException('nope')),
      throwsA(isA<ServerFailure>()),
    );
    expect(() => mapDataError(Exception('x')), throwsA(isA<ServerFailure>()));
    expect(
      () => mapDataError(const ServerFailure('kept')),
      throwsA(
        isA<ServerFailure>().having((f) => f.message, 'message', 'kept'),
      ),
    );
  });

  test('mapAuthError passes cancellation through', () {
    expect(
      () => mapAuthError(const AuthCancelledException()),
      throwsA(isA<AuthCancelledException>()),
    );
    expect(
      () => mapAuthError(const AuthException('nope')),
      throwsA(isA<AuthFailure>()),
    );
  });

  test('OutboxKind parses known values', () {
    expect(OutboxKind.fromValue('wishlist_add'), OutboxKind.wishlistAdd);
    expect(
      OutboxKind.fromValue('wishlist_add')?.scope,
      OutboxScope.wishlist,
    );
    expect(
      OutboxKind.fromValue('profile_update')?.scope,
      OutboxScope.profile,
    );
    expect(OutboxKind.fromValue('nope'), isNull);
  });
}
