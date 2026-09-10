import 'package:core/core.dart';

import '../models/user_model.dart';

/// Caches last user in Hive + keeps tokens in secure storage.
class AuthLocalDataSource {
  AuthLocalDataSource(this._cache, this._secure);
  final HiveCacheService _cache;
  final SecureStorageService _secure;

  static const _box = AppConstants.authCacheBox;
  static const _key = 'current_user';

  HiveCacheService get cacheBox => _cache;

  Future<void> cacheUser(UserModel user) =>
      HiveCacheService(_box).put(_key, user.toJson());

  Future<UserModel?> cachedUser() async {
    final json = await HiveCacheService(_box).get(_key);
    if (json == null) return null;
    return UserModel.fromJson(json);
  }

  Future<void> clear() async {
    await HiveCacheService(_box).delete(_key);
    await _secure.clear();
    // Per-user caches hold PII and must not survive sign-out (or account
    // deletion). Best-effort: sign-out itself must not fail over cache.
    for (final box in const [
      AppConstants.wishlistCacheBox,
      AppConstants.profileCacheBox,
    ]) {
      try {
        await HiveCacheService.clearBox(box);
      } catch (_) {
        // ignore cache wipe failures
      }
    }
  }

  static String get boxName => _box;
  static String get cacheKey => _key;
}
