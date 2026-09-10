import 'package:flutter_test/flutter_test.dart';
import 'package:core/core.dart';
void main() {
  test('validators work', () {
    expect(Validators.isValidEmail('a@b.com'), isTrue);
    expect(Validators.isValidEmail('bad'), isFalse);
    expect(Validators.isValidPassword('123456'), isTrue);
  });

  test('storage path helpers', () {
    expect(safeFileExtension('/a/photo.JPG'), 'jpg');
    expect(safeFileExtension('/a/noext'), 'jpg');
    expect(safeFileExtension('/a/.hidden'), 'jpg');
    expect(safeFileExtension('/a/x.toolongext'), 'jpg');
    expect(safeFileExtension('/a/pic.png'), 'png');
    expect(isRemoteUrl('https://x/y.jpg'), isTrue);
    expect(isRemoteUrl('http://x/y.jpg'), isTrue);
    expect(isRemoteUrl('/data/user/0/img.jpg'), isFalse);
  });
}
