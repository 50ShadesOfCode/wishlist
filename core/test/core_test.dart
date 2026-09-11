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

  test('fnv1a32 is deterministic and 8-hex', () {
    expect(fnv1a32('a'), fnv1a32('a'));
    expect(fnv1a32('a'), isNot(fnv1a32('b')));
    expect(fnv1a32('chat:x'), matches(RegExp(r'^[0-9a-f]{8}$')));
  });

  test('stableStorageFileName is seed-stable, seed-sensitive', () {
    expect(
      stableStorageFileName('op1', '/tmp/pic.jpg'),
      stableStorageFileName('op1', '/tmp/pic.jpg'),
    );
    expect(
      stableStorageFileName('op1', '/tmp/pic.jpg'),
      isNot(stableStorageFileName('op2', '/tmp/pic.jpg')),
    );
    expect(stableStorageFileName('op1', '/tmp/pic'), endsWith('.jpg'));
  });

  test('OutboxOperation round-trips new fields with legacy defaults', () {
    final op = OutboxOperation.fromJson({
      'key': 'op_x',
      'kind': 'wishlist_add',
      'payload': {'id': 'i1'},
    });
    expect(op.seqno, 0);
    expect(op.retryCount, 0);
    expect(op.userId, isNull);
    final full = OutboxOperation.fromJson(
      const OutboxOperation(
        key: 'op_y',
        kind: 'wishlist_delete',
        payload: {'id': 'i1'},
        seqno: 7,
        retryCount: 2,
        userId: 'u1',
      ).toJson(),
    );
    expect(full.seqno, 7);
    expect(full.retryCount, 2);
    expect(full.userId, 'u1');
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
