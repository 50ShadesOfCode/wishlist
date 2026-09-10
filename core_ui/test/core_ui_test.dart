import 'package:flutter_test/flutter_test.dart';
import 'package:core_ui/core_ui.dart';
void main() {
  test(' exports theme', () {
    expect(AppColors.primary, isNotNull);
    expect(AppFonts.bodyMedium, isNotNull);
  });
}
