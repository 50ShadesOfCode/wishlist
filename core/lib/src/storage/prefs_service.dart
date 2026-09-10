import 'package:shared_preferences/shared_preferences.dart';

class PrefsService {
  PrefsService(this._prefs);
  final SharedPreferences _prefs;

  static const themeKey = 'theme_mode';
  static const localeKey = 'locale';

  Future<bool> setThemeMode(String mode) =>
      _prefs.setString(themeKey, mode);
  String? get themeMode => _prefs.getString(themeKey);

  Future<bool> setLocale(String locale) =>
      _prefs.setString(localeKey, locale);
  String? get localeCode => _prefs.getString(localeKey);
}
