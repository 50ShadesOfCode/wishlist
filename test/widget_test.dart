import 'package:core/core.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('validators work', () {
    expect(Validators.isValidEmail('a@b.com'), isTrue);
  });
}
