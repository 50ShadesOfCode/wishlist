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

  Future<void> deleteProfile(String userId) async {
    await _client
        .from(AppConstants.profilesTable)
        .delete()
        .eq('user_id', userId);
  }

  /// True when another user already owns [username] (case-sensitive match).
  Future<bool> isUsernameTaken(String username, String excludeUserId) async {
    final rows = await _client
        .from(AppConstants.profilesTable)
        .select('user_id')
        .eq('username', username)
        .neq('user_id', excludeUserId)
        .limit(1);
    return (rows as List).isNotEmpty;
  }

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
