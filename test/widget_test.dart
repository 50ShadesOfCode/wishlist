import 'package:core/core.dart';
import 'package:core_ui/core_ui.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('shared validators accept valid input, reject invalid', () {
    expect(AppValidators.email('a@b.com'), isNull);
    expect(AppValidators.email('bad'), isNotNull);
    expect(AppValidators.password('123456'), isNull);
    expect(AppValidators.password('123'), isNotNull);
    expect(AppValidators.username('bob'), isNull);
    expect(AppValidators.username('ab'), isNotNull);
    expect(safeFileExtension('a.jpg'), 'jpg');
  });
}
