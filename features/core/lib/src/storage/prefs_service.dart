import 'package:shared_preferences/shared_preferences.dart';

class PrefsService {
  PrefsService(this._prefs);
  final SharedPreferences _prefs;

  static const themeKey = 'theme_mode';
  static const localeKey = 'locale';
  static const onboardingKey = 'onboarding_done';
  static const userIdKey = 'user_id_non_secret';

  Future<bool> setThemeMode(String mode) =>
      _prefs.setString(themeKey, mode);
  String? get themeMode => _prefs.getString(themeKey);

  Future<bool> setLocale(String locale) =>
      _prefs.setString(localeKey, locale);
  String? get locale => _prefs.getString(localeKey);

  Future<bool> setOnboardingDone(bool done) =>
      _prefs.setBool(onboardingKey, done);
  bool get onboardingDone => _prefs.getBool(onboardingKey) ?? false;

  Future<bool> setString(String key, String value) =>
      _prefs.setString(key, value);
  String? getString(String key) => _prefs.getString(key);
  Future<bool> setBool(String key, bool value) =>
      _prefs.setBool(key, value);
  bool? getBool(String key) => _prefs.getBool(key);
  Future<bool> remove(String key) => _prefs.remove(key);
  Future<bool> clear() => _prefs.clear();
}
