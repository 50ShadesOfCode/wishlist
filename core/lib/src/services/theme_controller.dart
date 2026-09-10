import 'package:material_ui/material_ui.dart';

import '../storage/prefs_service.dart';

/// App-level theme state, persisted via [PrefsService].
///
/// The profile settings switch writes here (through the router's
/// `onChangeTheme`); the app widget listens and rebuilds `MaterialApp.router`
/// with the selected [mode]. Defaults to system on first launch.
class ThemeController extends ChangeNotifier {
  ThemeController(this._prefs);

  final PrefsService _prefs;
  ThemeMode _mode = ThemeMode.system;

  ThemeMode get mode => _mode;
  bool get isDark => _mode == ThemeMode.dark;

  Future<void> load() async {
    _mode = switch (_prefs.themeMode) {
      'light' => ThemeMode.light,
      'dark' => ThemeMode.dark,
      _ => ThemeMode.system,
    };
    notifyListeners();
  }

  Future<void> setDark(bool dark) async {
    _mode = dark ? ThemeMode.dark : ThemeMode.light;
    await _prefs.setThemeMode(dark ? 'dark' : 'light');
    notifyListeners();
  }
}
