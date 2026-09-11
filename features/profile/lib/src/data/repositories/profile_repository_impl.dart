import 'package:core/core.dart';

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

  Future<Profile?> _getCached(String userId) async {
    final cached = await _cache.get(_key(userId));
    if (cached == null) return null;
    return ProfileModel.fromJson(cached);
  }

  @override
  Future<Profile?> getProfile(String userId) => cachedRead(
    network: _network,
    remote: () async {
      final remote = await _remote.getProfile(userId);
      if (remote != null) {
        await _cache.put(_key(userId), remote.toJson());
        return remote;
      }
      // Online-confirmed absence (deleted elsewhere): evict the stale cache
      // entry instead of resurrecting a deleted profile.
      await _cache.delete(_key(userId));
      return null;
    },
    fallback: () => _getCached(userId),
  );

  @override
  Future<Profile> updateProfile(Profile profile) async {
    final model = ProfileModel.fromEntity(profile);
    // Offline: persist to cache now, queue the upsert for sync.
    if (await enqueueOfflineWrite(
      network: _network,
      outbox: _outbox,
      kind: OutboxKind.profileUpdate,
      payload: model.toJson(),
      userId: profile.userId,
      writeCache: () => _cache.put(_key(profile.userId), model.toJson()),
    )) {
      return model;
    }
    try {
      final saved = await _remote.upsertProfile(model);
      await _cache.put(_key(profile.userId), saved.toJson());
      return saved;
    } catch (e) {
      mapDataError(e);
    }
  }

  @override
  Future<String> uploadAvatar(String userId, String filePath) async {
    if (!await _network.isConnected) throw const NetworkFailure();
    try {
      return await _remote.uploadAvatar(userId, filePath);
    } catch (e) {
      mapDataError(e);
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
      mapDataError(e);
    }
  }

  @override
  Future<bool> isUsernameTaken(String username, String excludeUserId) async {
    // Deliberate exception to the throw-offline rule: returning false lets
    // the edit proceed to updateProfile, which queues it in the outbox.
    // A real collision surfaces on the next online save instead of blocking
    // offline edits entirely.
    if (!await _network.isConnected) return false;
    try {
      return await _remote.isUsernameTaken(username, excludeUserId);
    } catch (e) {
      mapDataError(e);
    }
  }

  @override
  Future<void> deleteAccount(String userId) async {
    if (!await _network.isConnected) throw const NetworkFailure();
    try {
      final deleted = await _remote.deleteProfile(userId);
      if (!deleted) {
        // RLS-denied no-op: don't wipe the cache while the row survives.
        throw const ServerFailure('Profile could not be deleted');
      }
    } catch (e) {
      mapDataError(e);
    }
    await _cache.delete(_key(userId));
    // Remove all three avatar path patterns (avatar.*, legacy names).
    try {
      await _remote.deleteAvatar(userId);
    } catch (_) {
      // Storage cleanup is best-effort.
    }
  }

  @override
  Future<void> deleteUploadedAvatar(String avatarUrl) async {
    try {
      await _remote.deleteAvatarByUrl(avatarUrl);
    } catch (_) {
      // Rollback cleanup is best-effort.
    }
  }
}
