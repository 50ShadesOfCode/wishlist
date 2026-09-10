import 'package:core/core.dart';

import '../../domain/entities/profile.dart';
import '../../domain/repositories/profile_repository.dart';
import '../datasources/profile_remote_ds.dart';
import '../models/profile_model.dart';

class ProfileRepositoryImpl implements ProfileRepository {
  ProfileRepositoryImpl(this._remote, this._cache);

  final ProfileRemoteDataSource _remote;
  final HiveCacheService _cache;

  String _key(String userId) => 'profile_$userId';

  @override
  Future<Profile?> getProfile(String userId) async {
    try {
      final remote = await _remote.getProfile(userId);
      if (remote != null) {
        await _cache.put(_key(userId), remote.toJson());
        return remote;
      }
    } catch (_) {
      // fall through to cache
    }
    final cached = await _cache.get(_key(userId));
    if (cached == null) return null;
    return ProfileModel.fromJson(cached);
  }

  @override
  Future<Profile> updateProfile(Profile profile) async {
    final model = ProfileModel.fromEntity(profile);
    try {
      final saved = await _remote.upsertProfile(model);
      await _cache.put(_key(profile.userId), saved.toJson());
      return saved;
    } catch (_) {
      await _cache.put(_key(profile.userId), model.toJson());
      return model;
    }
  }

  @override
  Future<String> uploadAvatar(String userId, String filePath) =>
      _remote.uploadAvatar(userId, filePath);

  @override
  Future<void> deleteAccount(String userId) async {
    try {
      await _remote.deleteProfile(userId);
    } finally {
      await _cache.delete(_key(userId));
    }
  }

  @override
  Stream<Profile?> watchProfile(String userId) async* {
    yield await getProfile(userId);
  }
}
