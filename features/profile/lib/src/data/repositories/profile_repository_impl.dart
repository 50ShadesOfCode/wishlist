import 'package:core/core.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../domain/entities/profile.dart';
import '../../domain/repositories/profile_repository.dart';
import '../datasources/profile_remote_ds.dart';
import '../models/profile_model.dart';

class ProfileRepositoryImpl implements ProfileRepository {
  ProfileRepositoryImpl(this._remote, this._cache, this._network, this._outbox);

  final ProfileRemoteDataSource _remote;
  final HiveCacheService _cache;
  final NetworkInfo _network;
  final OutboxService _outbox;

  String _key(String userId) => 'profile_$userId';

  Never _asFailure(Object e) {
    if (e is Failure) throw e;
    if (e is PostgrestException) throw ServerFailure(e.message);
    if (e is StorageException) throw ServerFailure(e.message);
    throw ServerFailure(e.toString());
  }

  @override
  Future<Profile?> getProfile(String userId) async {
    try {
      final remote = await _remote.getProfile(userId);
      if (remote != null) {
        await _cache.put(_key(userId), remote.toJson());
        return remote;
      }
    } catch (e) {
      // Offline → Hive fallback. Online → surface the failure instead of
      // silently serving stale cache (which hid RLS/schema bugs).
      if (await _network.isConnected) _asFailure(e);
    }
    final cached = await _cache.get(_key(userId));
    if (cached == null) return null;
    return ProfileModel.fromJson(cached);
  }

  @override
  Future<Profile> updateProfile(Profile profile) async {
    final model = ProfileModel.fromEntity(profile);
    if (!await _network.isConnected) {
      // Offline: persist to cache now, queue the upsert for sync.
      await _cache.put(_key(profile.userId), model.toJson());
      await _outbox.enqueue('profile_update', model.toJson());
      return model;
    }
    try {
      final saved = await _remote.upsertProfile(model);
      await _cache.put(_key(profile.userId), saved.toJson());
      return saved;
    } catch (e) {
      _asFailure(e);
    }
  }

  @override
  Future<String> uploadAvatar(String userId, String filePath) async {
    if (!await _network.isConnected) throw const NetworkFailure();
    try {
      return await _remote.uploadAvatar(userId, filePath);
    } catch (e) {
      _asFailure(e);
    }
  }

  @override
  Future<Profile> removeAvatar(String userId) async {
    if (!await _network.isConnected) throw const NetworkFailure();
    try {
      await _remote.deleteAvatar(userId);
      final current = await getProfile(userId);
      final cleared = (current ?? Profile(userId: userId, username: 'user'))
          .clearAvatar();
      return await updateProfile(cleared);
    } catch (e) {
      _asFailure(e);
    }
  }

  @override
  Future<bool> isUsernameTaken(String username, String excludeUserId) async {
    if (!await _network.isConnected) return false;
    try {
      return await _remote.isUsernameTaken(username, excludeUserId);
    } catch (e) {
      _asFailure(e);
    }
  }

  @override
  Future<void> deleteAccount(String userId) async {
    if (!await _network.isConnected) throw const NetworkFailure();
    try {
      await _remote.deleteProfile(userId);
    } catch (e) {
      _asFailure(e);
    } finally {
      await _cache.delete(_key(userId));
    }
  }

  @override
  Stream<Profile?> watchProfile(String userId) => _remote.watchProfile(userId);
}
