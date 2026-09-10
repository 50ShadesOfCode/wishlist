import 'package:flutter_test/flutter_test.dart';
import 'package:profile/profile.dart';

void main() {
  test('Profile copyWith', () {
    const p = Profile(userId: 'u1', username: 'bob');
    expect(p.copyWith(username: 'alice').username, 'alice');
  });

  test('ProfileState copyWith can clear profile, preserves when omitted', () {
    const p = Profile(userId: 'u1', username: 'bob');
    const s = ProfileState(profile: p);
    expect(s.copyWith().profile, p);
    expect(s.copyWith(profile: null).profile, isNull);
  });

  test('Profile clear methods', () {
    final p = Profile(
      userId: 'u1',
      username: 'bob',
      avatarUrl: 'https://x/a.jpg',
      city: 'Tashkent',
      dateOfBirth: DateTime.utc(2000, 1, 1),
    );
    expect(p.clearAvatar().avatarUrl, isNull);
    expect(p.clearAvatar().city, 'Tashkent');
    expect(p.clearCity().city, isNull);
    expect(p.clearDateOfBirth().dateOfBirth, isNull);
  });
}
