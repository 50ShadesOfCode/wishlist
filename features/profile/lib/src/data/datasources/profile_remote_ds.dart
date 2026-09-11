import 'package:core/core.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/profile_model.dart';

class ProfileRemoteDataSource {
  ProfileRemoteDataSource(this._client);
  final SupabaseClient _client;

  Future<ProfileModel?> getProfile(String userId) async {
    final row = await _client
        .from(AppConstants.profilesTable)
        .select()
        .eq('user_id', userId)
        .maybeSingle();
    if (row == null) return null;
    return ProfileModel.fromJson(row);
  }

  Future<ProfileModel> upsertProfile(ProfileModel profile) async {
    final row = await _client
        .from(AppConstants.profilesTable)
        .upsert(profile.toJson())
        .select()
        .single();
    return ProfileModel.fromJson(row);
  }

  Future<String> uploadAvatar(String userId, String filePath) =>
      uploadToBucket(
        _client,
        bucket: AppConstants.avatarsBucket,
        path: '$userId/avatar.${safeFileExtension(filePath)}',
        filePath: filePath,
      );

  /// Deletes the profile row, returning true when a row was actually
  /// removed (false = already gone or RLS-denied no-op).
  Future<bool> deleteProfile(String userId) async {
    final rows = await _client
        .from(AppConstants.profilesTable)
        .delete()
        .eq('user_id', userId)
        .select('user_id');
    return (rows as List).isNotEmpty;
  }

  /// True when another user already owns [username] (case-insensitive).
  /// A DB unique index on `lower(username)` (see migration
  /// `20260911000000_username_unique.sql`) is the final arbiter; this check
  /// is a fast-path for friendly form errors.
  Future<bool> isUsernameTaken(String username, String excludeUserId) async {
    final rows = await _client
        .from(AppConstants.profilesTable)
        .select('user_id')
        .ilike('username', username)
        .neq('user_id', excludeUserId)
        .limit(1);
    return (rows as List).isNotEmpty;
  }

  /// Best-effort removal of a single uploaded avatar by public URL.
  Future<void> deleteAvatarByUrl(String avatarUrl) => removeByUrls(
    _client,
    bucket: AppConstants.avatarsBucket,
    imageUrls: [avatarUrl],
  );

  /// Removes all avatar objects for the user (`$userId/avatar.*`).
  Future<void> deleteAvatar(String userId) async {
    final objects = await _client.storage
        .from(AppConstants.avatarsBucket)
        .list(path: userId);
    final paths = [
      for (final o in objects)
        if (o.name.isNotEmpty) '$userId/${o.name}',
    ];
    if (paths.isNotEmpty) {
      await _client.storage.from(AppConstants.avatarsBucket).remove(paths);
    }
  }
}
