import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Key-value secrets storage.
///
/// Session tokens are intentionally NOT kept here: the Firebase and Supabase
/// SDKs persist their own sessions. This service only holds explicit secrets
/// and wipes them on sign-out for hygiene.
class SecureStorageService {
  SecureStorageService([FlutterSecureStorage? storage])
    : _storage = storage ?? const FlutterSecureStorage();

  final FlutterSecureStorage _storage;

  Future<void> clear() async {
    await _storage.deleteAll();
  }
}
